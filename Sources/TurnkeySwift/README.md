# TurnkeySwift

The `TurnkeySwift` package simplifies integration of the Turnkey API into Swift applications. It provides secure session management, authentication, and cryptographic operations for iOS, macOS, and other Apple platforms.

---

## Quick Start

### Initialization

In your app entry point (typically in your `@main` App struct), create the shared context and inject it into the environment:

```swift
@main
struct DemoWalletApp: App {
    @StateObject private var turnkey: TurnkeyContext

    init() {
        let context = TurnkeyContext.shared
        _turnkey = StateObject(wrappedValue: context)
    }

    var body: some Scene {
        WindowGroup {
            AppView()
                .environmentObject(turnkey)
        }
    }
}
```

Then in your views, access it via:

```swift
@EnvironmentObject private var turnkey: TurnkeyContext
```

---

## Session Storage Keys

* `com.turnkey.sdk.session`: Default session key for JWT payloads
* `com.turnkey.sdk.sessionKeys`: Registry of stored sessions
* `com.turnkey.sdk.pendingList`: Pending ephemeral key list
* `com.turnkey.sdk.selectedSession`: Selected active session key
* `com.turnkey.sdk.autoRefresh`: Tracks which sessions have auto-refresh enabled and the associated refresh duration

---

## Features

### Session Management

* `createKeyPair() -> String`

  * Generates a new ephemeral key pair and saves the private key securely.

* `createSession(jwt:sessionKey:refreshedSessionTTLSeconds:)`

  * Creates and stores a session from a JWT.
  * Optionally sets up automatic refresh behavior if `refreshedSessionTTLSeconds` is provided. This value defines how long each refreshed session will last and must be at least 30 seconds.

* `setSelectedSession(sessionKey:) -> TurnkeyClient`

  * Selects a previously saved session and returns a usable client.

* `clearSession(for:)`

  * Clears the specified session and resets state.

* `refreshSession(expirationSeconds:sessionKey:invalidateExisting:)`

  * Manually refreshes the selected session. Useful when rotating credentials.

### User Management

* `refreshUser()`

  * Re-fetches the user data from the API.

* `updateUser(email:phone:)`

  * Updates the user contact details.

* `updateUserEmail(email:verificationToken:)`

  * Updates the user's email address. If a verification token is provided, the email is marked as verified. Passing an empty string will delete the user's email.

* `updateUserPhoneNumber(phone:verificationToken:)`

  * Updates the user's phone number. If a verification token is provided, the phone number is marked as verified. Passing an empty string will delete the user's phone number.

### Wallet Management

* `createWallet(walletName:accounts:mnemonicLength:)`

  * Creates a wallet with optional mnemonic generation.

* `importWallet(walletName:mnemonic:accounts:) -> Activity`

  * Imports an existing wallet using mnemonic phrase.

* `exportWallet(walletId:) -> String`

  * Exports the mnemonic phrase for the specified wallet.

### Signing

* `signRawPayload(signWith:payload:encoding:hashFunction:) -> SignRawPayloadResult`

  * Signs a raw payload using the current session.

### OAuth

* `startGoogleOAuthFlow(clientId:nonce:scheme:anchor:originUri:redirectUri:) -> String`

  * Launches the Google OAuth flow in a secure system browser window and returns an OIDC token.

---

## Supported Types

Common types used in the SDK are directly re-exported:

```swift
public typealias PayloadEncoding = Components.Schemas.PayloadEncoding
public typealias HashFunction = Components.Schemas.HashFunction
public typealias Curve = Components.Schemas.Curve
public typealias PathFormat = Components.Schemas.PathFormat
public typealias AddressFormat = Components.Schemas.AddressFormat
public typealias Timestamp = Components.Schemas.external_period_data_period_v1_period_Timestamp
```

---

## Session Expiry Handling

Each session schedules a timer to automatically clear itself 5 seconds before JWT expiry. If `refreshedSessionTTLSeconds` was provided when creating the session, the SDK will automatically refresh the session before it expires, as long as the app is active.

You can optionally observe session state via `@Published` properties on `TurnkeyContext`:

```swift
@Published public internal(set) var authState: AuthState
@Published public internal(set) var selectedSessionKey: String?
@Published public internal(set) var user: SessionUser?
@Published public internal(set) var client: TurnkeyClient?
```

---

## Demo App

A sample SwiftUI demo app is included in the repository to showcase usage.

---

## Requirements

* iOS 17+ / macOS 14.0+
* Swift 5.9+

---
