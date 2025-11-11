Let me check the current branch, status, and the diff vs main to summarize the changes accurately for the PR description.

[2 tools called]

I checked the current branch and diff to main to ground the PR description.

- Current branch: taylor/swift-follow-ups
- Recent commits:
  - beeab45 Make init with stamper public
  - 1fb276d Add sign method
  - 3896f75 Adds more init methods and config options to stamper class
  - 0e9cf96 Create EnclaveManager, refactor SecureEnvlaveStamper, add KeyManager view for testing
- Working tree changes (not yet committed here): new `Stamper` config-driven initializers, Models, README updates, tests, and Makefile test targets

Proposed PR title
Stamper: config-driven initializers, auto on-device keypair creation, and config pass-through (docs + tests)

PR description

- Summary

  - Add public config models and convenience initializers to `Stamper` for API keys, passkeys, Secure Enclave, and Secure Storage.
  - Support automatic on-device keypair creation and store the generated public key on the `Stamper` instance.
  - Persist a single, type-erased configuration on `Stamper` and pass Secure Storage config at stamp time when available.
  - Refactor `.auto` selection to a small, clearer pattern without `fallthrough`.
  - Update docs with concise examples and add a test target with basic coverage.
  - Add a generic signing API: `Stamper.sign(payload:)` returns a DER-hex signature; passkey signing is intentionally unsupported and throws.

- What changed

  - New public config models (under `Sources/TurnkeyStamper/Models/`):
    - `ApiKeyStamperConfig`
    - `PasskeyStamperConfig`
    - `SecureEnclaveStamperConfig`
    - `SecureStorageStamperConfig`
    - `StamperConfiguration` (type-erased enum)
  - `Stamper` updates (`Sources/TurnkeyStamper/Public/Stamper.swift`):
    - Store a single `configuration: StamperConfiguration?`.
    - New convenience initializers:
      - `init(config: PasskeyStamperConfig)`
      - `init(config: ApiKeyStamperConfig)`
      - `init(config: SecureEnclaveStamperConfig) throws` (creates keypair, sets mode)
      - `init(config: SecureStorageStamperConfig) throws` (creates keypair, sets mode)
      - `init(onDevicePreference: OnDeviceStamperPreference = .auto) throws` (creates keypair; selects Enclave if supported)
    - Config mappers translate public configs into internal stamper configs.
    - When stamping with Secure Storage, pass the stored config to ensure correct Keychain scoping/auth prompts.
    - Small refactor: compute `selected` preference for `.auto` and switch on it (clearer than `fallthrough`).
    - New `sign(payload:)` that routes to the configured backend and returns only the signature (DER hex). Throws `signNotSupportedForPasskey` for passkeys. Existing `stamp(payload:)` behavior is unchanged and delegates signature creation to internal `sign(...)` helpers.
  - Docs:
    - `Sources/TurnkeyStamper/README.md`: add concise examples for all new initializers; clarify key-management snippets.
  - Tests:
    - Add `TurnkeyStamperTests` target in `Package.swift`.
    - `Tests/TurnkeyStamperTests/TurnkeyStamperConfigInitTests.swift`:
      - API key config initializes and stamps.
      - Passkey config initializer (no UI flow).
      - Secure Storage config initializer auto-creates key and stamps.
      - `.auto` initializer creates key and stamps (falls back to Keychain if Enclave unavailable).
    - `Tests/TurnkeyStamperTests/TurnkeyStamperSignTests.swift`: verifies signatures from `sign(payload:)` (API key and Secure Storage) using CryptoKit; asserts passkey mode throws.
  - Tooling:
    - `Scripts/Makefile`:
      - `test`: run all tests via SwiftPM.
      - `test-stamper`: run only `TurnkeyStamper` tests.
      - (You added `test-modern` alongside; leaving it intact.)

- Design decisions (from this discussion)

  - Use `convenience` initializers to delegate to existing designated inits, avoiding duplicated logic.
  - For Enclave/Storage config inits and the no-config on-device init, create the keypair automatically and store the resulting public key on the existing `apiPublicKey` slot; don’t introduce a new state variable.
  - Keep a single, type-erased `configuration` on `Stamper` and only pass it where needed (Secure Storage at stamp time). Secure Enclave config is used at key creation only (consistent with Apple’s model).
  - Prefer a small refactor of `.auto` selection to a precomputed `selected` enum value rather than `fallthrough` for clarity.
  - Expose configs publicly under `Models/` for good ergonomics and maintainability.

- API compatibility

  - Backwards compatible. Existing initializers and behavior remain unchanged.
  - New convenience initializers and models are additive.
  - Adds `Stamper.sign(payload:)` as an additive API; no breaking changes.

- Testing/CI notes

  - Secure Storage tests use default config (no prompts) and should run headless.
  - `.auto` initializer test gracefully falls back to Keychain if Secure Enclave isn’t available (e.g., simulator/CI).
  - Passkey initializer test only constructs the stamper; no WebAuthn UI flow.

- How to run tests
  - All tests: `make -C Scripts test`
  - Only Stamper tests: `make -C Scripts test-stamper`
  - Direct SwiftPM: `swift test --parallel` or `swift test --parallel --filter TurnkeyStamperTests`

If you want, I can also include a brief “Migration” note in the PR body to reassure consumers that this is additive and purely opt-in.
