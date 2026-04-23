.PHONY: build types clients codegen clean test test-modern test-stamper

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
generate: types clients
	@$(MAKE) -C .. format
	@echo "✨ Code generation complete!"

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