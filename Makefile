.PHONY: changeset version changelog prepare-release

# Create a new changeset
changeset:
	@./changeset.sh add

# Bump version based on pending changesets
version:
	@./changeset.sh version

# Generate changelog and consume changesets
changelog:
	@./changeset.sh changelog

# Full release flow: bump version, then generate changelog
prepare-release: version changelog
