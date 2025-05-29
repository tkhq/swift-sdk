# TurnkeyPasskeys

This Swift package provides a high-level interface for passkey-based authentication using Apple's `AuthenticationServices` framework. It handles both registration and assertion flows, making it easy to integrate passkeys into your app.

It is designed to work with Turnkey’s backend services, specifically for generating and verifying passkey credentials.

## Features

* Simple `createPasskey()` function to register a new passkey.
* `PasskeyStamper` class to assert (authenticate) using an existing passkey.
* Support for platform authenticators (e.g., Face ID / Touch ID) and security keys (e.g., YubiKey).

## Requirements

* iOS 16.0+ / macOS 13.0+
* Swift 5.7+

---

## Usage

### Create a new passkey

```swift
import TurnkeyPasskeys

let registration = try await createPasskey(
    user: PasskeyUser(
        id: UUID().uuidString,
        name: "Anonymous User",
        displayName: "Anonymous User"
    ),
    rp: RelyingParty(
        id: Constants.App.rpId,
        name: Constants.App.appName
    ),
    presentationAnchor: anchor
)
```

This returns the attestation data and challenge needed to create a user or authenticator on the Turnkey platform.

### Authenticate with an existing passkey

```swift
import TurnkeyPasskeys

let stamper = PasskeyStamper(
    rpId: Constants.App.rpId,
    presentationAnchor: anchor
)
```

Use the result to sign payloads or authenticate a session.

---
