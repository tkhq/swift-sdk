#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHANGESET_DIR="$SCRIPT_DIR/.changeset"
VERSION_FILE="$SCRIPT_DIR/VERSION"
VERSION_SWIFT="$SCRIPT_DIR/Sources/TurnkeyHttp/Internal/Version.swift"
CHANGELOG_FILE="$SCRIPT_DIR/CHANGELOG.md"

# --- Word lists for filename generation ---

ADJECTIVES=(
    brave bright calm clever cool crisp
    daring deep eager fair fast fierce
    fluffy gentle giant golden grand green
    happy humble icy jolly keen kind
    light lively lucky magic mighty misty
    noble proud quick rapid red regal
    sharp silent silver sleek slim smooth
    soft solid spicy spring steady still
    strong super sweet swift tall thick
    tiny tough vivid warm wet wild
)

NOUNS=(
    badger bear bird breeze brook canyon
    cloud coral crane creek dawn deer
    dolphin dove dragon dusk eagle ember
    falcon flame forest fox frost galaxy
    garden glacier grove harbor hawk hill
    island jade lake leaf lion maple
    meadow moon oak ocean orchid otter
    panda pearl pine planet pond puma
    quartz rain raven ridge river rose
    sage seal shadow shore sky sparrow
    stone storm summit sun tiger trail
    valley wave willow wind wolf yarn
)

# --- Helpers ---

generate_filename() {
    local adj="${ADJECTIVES[$((RANDOM % ${#ADJECTIVES[@]}))]}"
    local noun="${NOUNS[$((RANDOM % ${#NOUNS[@]}))]}"
    local name="$adj-$noun"

    if [[ -f "$CHANGESET_DIR/$name.md" ]]; then
        name="$name-$((RANDOM % 1000))"
    fi

    echo "$name"
}

parse_bump() {
    local file="$1"
    awk '/^---$/{n++; next} n==1 && /^bump:/{print $2; exit}' "$file"
}

parse_description() {
    local file="$1"
    awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$file" | \
        sed '/^[[:space:]]*$/d' | \
        head -1
}

collect_changesets() {
    local changesets=()
    if [[ -d "$CHANGESET_DIR" ]]; then
        while IFS= read -r -d '' f; do
            changesets+=("$f")
        done < <(find "$CHANGESET_DIR" -name '*.md' -print0 2>/dev/null)
    fi
    printf '%s\0' "${changesets[@]}"
}

# --- Commands ---

cmd_add() {
    mkdir -p "$CHANGESET_DIR"

    echo ""
    echo "What kind of change is this?"
    echo ""
    PS3="Select bump type (1-3): "
    select BUMP_TYPE in patch minor major; do
        [[ -n "$BUMP_TYPE" ]] && break
        echo "Invalid selection. Please choose 1, 2, or 3."
    done

    echo ""
    read -r -p "Describe the change: " DESCRIPTION
    if [[ -z "$DESCRIPTION" ]]; then
        echo "Error: description cannot be empty."
        exit 1
    fi

    local filename
    filename=$(generate_filename)
    local filepath="$CHANGESET_DIR/$filename.md"

    cat > "$filepath" <<EOF
---
bump: $BUMP_TYPE
---

$DESCRIPTION
EOF

    echo ""
    echo "Created changeset: .changeset/$filename.md"
}

cmd_version() {
    if [[ ! -f "$VERSION_FILE" ]]; then
        echo "Error: VERSION file not found at $VERSION_FILE"
        exit 1
    fi
    if [[ ! -f "$VERSION_SWIFT" ]]; then
        echo "Error: Version.swift not found at $VERSION_SWIFT"
        exit 1
    fi

    local changesets=()
    if [[ -d "$CHANGESET_DIR" ]]; then
        while IFS= read -r -d '' f; do
            changesets+=("$f")
        done < <(find "$CHANGESET_DIR" -name '*.md' -print0 2>/dev/null)
    fi

    if [[ ${#changesets[@]} -eq 0 ]]; then
        echo "No pending changesets found. Nothing to bump."
        exit 0
    fi

    local highest="patch"
    for cs in "${changesets[@]}"; do
        local bump
        bump=$(parse_bump "$cs")
        case "$bump" in
            major) highest="major" ;;
            minor) [[ "$highest" != "major" ]] && highest="minor" ;;
            patch) ;;
            *)
                echo "Warning: invalid bump type '$bump' in $(basename "$cs"), skipping."
                ;;
        esac
    done

    local current_version
    current_version=$(tr -d '[:space:]' < "$VERSION_FILE")

    local major minor patch
    IFS='.' read -r major minor patch <<< "$current_version"

    case "$highest" in
        major) major=$((major + 1)); minor=0; patch=0 ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        patch) patch=$((patch + 1)) ;;
    esac
    local new_version="$major.$minor.$patch"

    echo "$new_version" > "$VERSION_FILE"

    sed -i '' "s/let sdkVersion = \".*\"/let sdkVersion = \"$new_version\"/" "$VERSION_SWIFT"

    echo "Bumped version: $current_version -> $new_version ($highest)"
}

cmd_changelog() {
    local changesets=()
    if [[ -d "$CHANGESET_DIR" ]]; then
        while IFS= read -r -d '' f; do
            changesets+=("$f")
        done < <(find "$CHANGESET_DIR" -name '*.md' -print0 2>/dev/null)
    fi

    if [[ ${#changesets[@]} -eq 0 ]]; then
        echo "No pending changesets found. Nothing to generate."
        exit 0
    fi

    local version
    version=$(tr -d '[:space:]' < "$VERSION_FILE")
    local date
    date=$(date +%Y-%m-%d)

    local major_changes=() minor_changes=() patch_changes=()
    for cs in "${changesets[@]}"; do
        local bump description
        bump=$(parse_bump "$cs")
        description=$(parse_description "$cs")

        case "$bump" in
            major) major_changes+=("$description") ;;
            minor) minor_changes+=("$description") ;;
            *)     patch_changes+=("$description") ;;
        esac
    done

    local section=""
    section+="## $version - $date"$'\n\n'

    if [[ ${#major_changes[@]} -gt 0 ]]; then
        section+="### Major Changes"$'\n\n'
        for entry in "${major_changes[@]}"; do
            section+="- $entry"$'\n'
        done
        section+=$'\n'
    fi

    if [[ ${#minor_changes[@]} -gt 0 ]]; then
        section+="### Minor Changes"$'\n\n'
        for entry in "${minor_changes[@]}"; do
            section+="- $entry"$'\n'
        done
        section+=$'\n'
    fi

    if [[ ${#patch_changes[@]} -gt 0 ]]; then
        section+="### Patch Changes"$'\n\n'
        for entry in "${patch_changes[@]}"; do
            section+="- $entry"$'\n'
        done
        section+=$'\n'
    fi

    if [[ -f "$CHANGELOG_FILE" ]]; then
        local header body
        # Split on the first blank line after the header
        header=$(head -1 "$CHANGELOG_FILE")
        body=$(tail -n +3 "$CHANGELOG_FILE")
        printf '%s\n\n%s%s\n' "$header" "$section" "$body" > "$CHANGELOG_FILE"
    else
        printf '# Changelog\n\n%s' "$section" > "$CHANGELOG_FILE"
    fi

    for cs in "${changesets[@]}"; do
        rm "$cs"
    done

    echo "Generated changelog for version $version"
    echo "Deleted ${#changesets[@]} changeset file(s)"
}

usage() {
    echo "Usage: changeset.sh <command>"
    echo ""
    echo "Commands:"
    echo "  add         Create a new changeset"
    echo "  version     Bump package version based on pending changesets"
    echo "  changelog   Generate changelog from pending changesets"
    echo ""
    exit 1
}

# --- Main ---

case "${1:-}" in
    add)       cmd_add ;;
    version)   cmd_version ;;
    changelog) cmd_changelog ;;
    *)         usage ;;
esac
