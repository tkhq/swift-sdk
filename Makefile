.PHONY: changeset version changelog prepare-release format format-check

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

# Format all Swift files
format:
	@echo "🎨 Formatting..."
	@swift-format -i -r Sources/ Tests/ 2>/dev/null

# Check formatting without modifying files (exits non-zero if formatting is needed)
format-check:
	@echo "🔍 Checking formatting..."
	@FAILED=0; \
	for file in $$(find Sources/ Tests/ -name '*.swift'); do \
		swift-format "$$file" 2>/dev/null | diff -q - "$$file" >/dev/null 2>&1 || { echo "❌ $$file needs formatting"; FAILED=1; }; \
	done; \
	if [ "$$FAILED" -eq 1 ]; then echo "Run 'make format' to fix."; exit 1; fi
	@echo "✅ Formatting looks good!"
