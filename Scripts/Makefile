.PHONY: build types clients codegen format format-check clean test test-modern test-stamper

# Build the codegen executables
build:
	@swift build -q 2>&1 | grep -v "found.*file(s) which are unhandled" || true

# Generate types only
types: build
	@echo "🔨 Generating types..."
	@cd .. && Scripts/.build/debug/typegen | grep -E "^(✅|❌)" || true

# Generate clients only
clients: build
	@echo "🔨 Generating clients..."
	@cd .. && Scripts/.build/debug/clientgen | grep -E "^(✅|❌)" || true

# Generate everything
generate: types clients format
	@echo "✨ Code generation complete!"

# Format all Swift files
format:
	@echo "🎨 Formatting..."
	@swift-format -i -r ../Sources/ ../Tests/ 2>/dev/null

# Check formatting without modifying files (exits non-zero if formatting is needed)
format-check:
	@echo "🔍 Checking formatting..."
	@FAILED=0; \
	for file in $$(find ../Sources/ ../Tests/ -name '*.swift'); do \
		swift-format "$$file" 2>/dev/null | diff -q - "$$file" >/dev/null 2>&1 || { echo "❌ $$file needs formatting"; FAILED=1; }; \
	done; \
	if [ "$$FAILED" -eq 1 ]; then echo "Run 'make format' to fix."; exit 1; fi
	@echo "✅ Formatting looks good!"

# Clean build artifacts
clean:
	@rm -rf .build 2>/dev/null || true

# Run all SwiftPM tests
test:
	@echo "🧪 Running all tests..."
	@cd .. && swift test --parallel

# Run only TurnkeyStamper tests
test-stamper:
	@echo "🧪 Running TurnkeyStamper tests..."
	@cd .. && swift test --parallel --filter TurnkeyStamperTests

.DEFAULT_GOAL := codegen