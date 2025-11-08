# TurnkeyStamper

This Swift package provides a unified interface for signing payloads using API keys, on-device keys (Secure Enclave or Keychain), or WebAuthn passkeys. It abstracts over the differences between various signing methods and provides a simple `stamp()` method to produce verifiable cryptographic stamps.

It is designed to work seamlessly with Turnkey's backend APIs that expect either `X-Stamp` or `X-Stamp-WebAuthn` headers.

## Features

- **API Key Signing**: Sign with raw P-256 keypairs
- **On-Device Key Signing**: Sign with keys stored in Secure Enclave or Keychain
  - Automatic backend selection (prefers Secure Enclave when available)
  - Manual backend selection for specific requirements
- **Passkey Signing**: WebAuthn-compliant passkey authentication
- **Unified Interface**: Single `stamp()` method returns the correct header name and value
- **Key Management**: Create, list, and delete on-device key pairs

---

## Usage

### 1. API Key Signing

Sign with a raw P-256 key pair (both public and private key provided):

```swift
import TurnkeyStamper

let stamper = Stamper(apiPublicKey: "<public-key-hex>", apiPrivateKey: "<private-key-hex>")
let (headerName, headerValue) = try await stamper.stamp(payload: jsonPayload)
// headerName: "X-Stamp"
```

### 2. On-Device Key Signing

Sign with a key stored in Secure Enclave or Keychain (only public key needed):

```swift
import TurnkeyStamper

// Create a new on-device key pair
let publicKey = try Stamper.createOnDeviceKeyPair()

// Sign with automatic backend selection (prefers Secure Enclave)
let stamper = try Stamper(apiPublicKey: publicKey)
let (headerName, headerValue) = try await stamper.stamp(payload: jsonPayload)
// headerName: "X-Stamp"
```

#### Manual Backend Selection

You can explicitly choose which backend to use:

```swift
// Force Secure Enclave
let stamper = try Stamper(apiPublicKey: publicKey, onDevicePreference: .secureEnclave)

// Force Secure Storage (Keychain)
let stamper = try Stamper(apiPublicKey: publicKey, onDevicePreference: .secureStorage)

// Auto (default) - prefers Secure Enclave when available
let stamper = try Stamper(apiPublicKey: publicKey, onDevicePreference: .auto)
```

#### Key Management

```swift
// Create a new key pair (prefers Secure Enclave when available)
let publicKey = try Stamper.createOnDeviceKeyPair()

// Check existence
let exists = try Stamper.existsOnDeviceKeyPair(publicKeyHex: publicKey)

// Delete a key pair
try Stamper.deleteOnDeviceKeyPair(publicKeyHex: publicKey)
```

#### Advanced: Secure Enclave with Biometric Protection

For Secure Enclave, you can set an authentication policy at key creation time. The policy is embedded in the key and enforced by the hardware:

```swift
import TurnkeyStamper

// Create a stamper that generates a Secure Enclave key with biometric requirement
let config = SecureEnclaveStamperConfig(authPolicy: .biometryAny)
let stamper = try Stamper(config: config)
let (headerName, headerValue) = try await stamper.stamp(payload: jsonPayload)
// User is prompted for biometric authentication when signing
```

**Note**: Unlike Secure Storage, Secure Enclave config is only used at key creation. Subsequent operations (list, stamp, delete) don't need the config because the auth policy is permanently embedded in the key by the hardware.

#### Advanced: Secure Storage with Custom Configuration

For Secure Storage (Keychain), you can customize storage attributes like access groups, iCloud sync, or biometric protection:

```swift
import TurnkeyStamper

// Create custom configuration
let config = SecureStorageStamperConfig(
  accessibility: .afterFirstUnlockThisDeviceOnly,
  accessControlPolicy: .biometryAny,  // Require biometric authentication
  authPrompt: "Authenticate to sign",
  biometryReuseWindowSeconds: 30,
  synchronizable: false,              // Don't sync to iCloud
  accessGroup: "com.example.shared"   // Share keys between apps
)

// Create stamper and sign. The stamper remembers the config and uses it when needed.
let stamper = try Stamper(config: config)
let (headerName, headerValue) = try await stamper.stamp(payload: jsonPayload)
```

**Note**: Keychain queries must match how items were stored. If you create a key with custom config attributes (especially `accessGroup`, `synchronizable`, or `accessControlPolicy`), you must pass that same config to all subsequent operations (`listKeyPairs`, `stamp`, `deleteKeyPair`). If you use default settings, the no-config methods work fine.

### 3. Passkey Signing

Sign with WebAuthn passkeys:

```swift
import TurnkeyStamper

let stamper = Stamper(rpId: "your.site.com", presentationAnchor: window)
let (headerName, headerValue) = try await stamper.stamp(payload: jsonPayload)
// headerName: "X-Stamp-WebAuthn"
```

---

### Config-driven initializers

You can initialize a `Stamper` directly from configuration objects for clean ergonomics:

```swift
// API Key
let api = ApiKeyStamperConfig(apiPublicKey: "<pub>", apiPrivateKey: "<priv>")
let withApi = Stamper(config: api)

// Passkey
let passkey = PasskeyStamperConfig(rpId: "your.site.com", presentationAnchor: window)
let withPasskey = Stamper(config: passkey)

// Secure Enclave (creates a new key)
let enclave = SecureEnclaveStamperConfig(authPolicy: .userPresence)
let withEnclave = try Stamper(config: enclave)

// Secure Storage (creates a new key)
let storage = SecureStorageStamperConfig(accessControlPolicy: .biometryAny, authPrompt: "Authenticate to sign")
let withStorage = try Stamper(config: storage)

// On-device with automatic selection (creates a new key)
let auto = try Stamper(onDevicePreference: .auto)
```

---

## Architecture

### Secure Enclave Stamper

The **Secure Enclave** is Apple's dedicated secure coprocessor:

- Private keys are generated and stored inside the Secure Enclave
- Keys never leave the secure enclave - signing happens inside
- Available on iPhone 5s and later, iPad Air and later, Macs with Apple Silicon or T2 chip
- Metadata stored in iCloud Keychain for persistence

### Secure Storage Stamper

The **Secure Storage** stamper uses the device's Keychain:

- Private keys stored in local Keychain
- Available after first device unlock (no biometric protection by default)
- Used as fallback when Secure Enclave is unavailable
- Works on all Apple devices

### Automatic Selection

When using `.auto` preference (default), the stamper:

1. Checks if Secure Enclave is available
2. Uses Secure Enclave if supported, otherwise falls back to Secure Storage

---

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 5.9+

---
