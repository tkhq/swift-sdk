# TurnkeyStamper

This Swift package provides a unified interface for signing payloads using either API keys or WebAuthn passkeys. It abstracts over the differences between raw keypair signing and passkey-based assertion, and provides a simple method to produce verifiable cryptographic stamps.

It is designed to work seamlessly with Turnkey’s backend APIs that expect either `X-Stamp` or `X-Stamp-WebAuthn` headers.

## Features

* Supports both API key-based and WebAuthn passkey-based stamping.
* Unified `stamp()` method returns the correct header name and value.
* Uses P-256 ECDSA signatures (DER for API keys, WebAuthn-compliant for passkeys).

---

## Requirements

* iOS 16.0+ / macOS 13.0+
* Swift 5.7+

---

## Usage

### API Key Signing

```swift
import TurnkeyStamper

let stamper = Stamper(apiPublicKey: "<public-key>", apiPrivateKey: "<private-key>")
```

### Passkey Signing

```swift
import TurnkeyStamper

let stamper = Stamper(rpId: "your.site.com", presentationAnchor: anchor)
```

The resulting header can be attached to any HTTP request for authenticated interaction with Turnkey services.

---

