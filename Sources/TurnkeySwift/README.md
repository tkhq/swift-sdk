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

## Key Storage

Session keys are automatically stored securely based on device capabilities:

### 1. Secure Enclave (Default)

When available, private keys are generated and stored inside the **Secure Enclave** - Apple's dedicated secure coprocessor.

* **Private keys never leave the Secure Enclave**
* Hardware-isolated cryptographic operations
* Available on iPhone 5s and later, iPad Air and later, Macs with Apple Silicon or T2 chip

### 2. Secure Storage (Fallback)

If Secure Enclave is not available, keys are stored in the device's **Keychain** using Secure Storage.

* Private keys stored in local Keychain
* Protected by device passcode/biometrics

---

## Session Storage Keys

Session metadata is stored in **local storage** (UserDefaults) using the following keys:

* `com.turnkey.sdk.session`: Default session key for JWT payloads
* `com.turnkey.sdk.sessionKeys`: Registry of stored sessions
* `com.turnkey.sdk.pendingList`: Pending ephemeral key list
* `com.turnkey.sdk.selectedSession`: Selected active session key
* `com.turnkey.sdk.autoRefresh`: Tracks which sessions have auto-refresh enabled and the associated refresh duration

---

## Features

### Session Management

* `createKeyPair() throws -> String`
  * Generates a new ephemeral key pair and saves the private key securely.

* `storeSession(jwt:sessionKey:refreshedSessionTTLSeconds:)`
  * Creates and stores a session from a JWT.
  * Optionally sets up automatic refresh behavior if `refreshedSessionTTLSeconds` is provided. This value defines how long each refreshed session will last and must be at least 30 seconds.

* `setActiveSession(sessionKey:) async throws -> TurnkeyClient`
  * Activates a previously saved session and returns a usable client.

* `clearSession(for:)`
  * Clears the specified session and resets state.

* `refreshSession(expirationSeconds:sessionKey:invalidateExisting:) async throws`
  * Manually refreshes the selected session. Useful when rotating credentials.

### Authentication

#### Direct API (No Auth Proxy Required)

* `loginWithPasskey(sessionKey:expirationSeconds:invalidateExisting:) async throws -> BaseAuthResult`
  * Authenticates using a passkey and creates a new session.

* `handleGoogleOAuth(clientId:originUrl:redirectUrl:sessionKey:expirationSeconds:invalidateExisting:) async throws -> CompleteOAuthResult`
  * Authenticates using Google OAuth. Can work without auth proxy if `oauthSuccess` redirect is provided.

* `handleAppleOAuth(clientId:originUrl:redirectUrl:sessionKey:expirationSeconds:invalidateExisting:) async throws -> CompleteOAuthResult`
  * Authenticates using Apple OAuth. Can work without auth proxy if `oauthSuccess` redirect is provided.

#### Requires Auth Proxy

* `signUpWithPasskey(userName:passkeyName:email:phone:sessionKey:expirationSeconds:) async throws -> BaseAuthResult`
  * Creates a new user account with passkey authentication.

* `initOtp(contact:otpType:) async throws -> InitOtpResult`
  * Initiates an OTP flow by sending a code to the specified contact.

* `verifyOtp(otpId:otpCode:) async throws -> VerifyOtpResult`
  * Verifies an OTP code and returns a verification token.

* `loginWithOtp(verificationToken:publicKey:organizationId:invalidateExisting:sessionKey:) async throws -> BaseAuthResult`
  * Logs in using a verified OTP token.

* `signUpWithOtp(verificationToken:userName:publicKey:expirationSeconds:sessionKey:) async throws -> BaseAuthResult`
  * Creates a new user account using a verified OTP token.

* `completeOtp(otpId:otpCode:contact:otpType:publicKey:createSubOrgParams:invalidateExisting:sessionKey:) async throws -> CompleteOtpResult`
  * Complete flow that verifies OTP and either logs in or signs up automatically.

* `handleDiscordOAuth(clientId:originUrl:redirectUrl:sessionKey:expirationSeconds:invalidateExisting:) async throws -> CompleteOAuthResult`
  * Authenticates using Discord OAuth.

* `handleXOauth(clientId:originUrl:redirectUrl:sessionKey:expirationSeconds:invalidateExisting:) async throws -> CompleteOAuthResult`
  * Authenticates using X (Twitter) OAuth.

* `completeOAuth(oidcToken:publicKey:organizationId:invalidateExisting:sessionKey:expirationSeconds:) async throws -> CompleteOAuthResult`
  * Completes OAuth flow with an OIDC token.

### User Management

* `fetchUser() async throws -> v1User`
  * Fetches user data for the currently active session.

* `refreshUser() async throws`
  * Re-fetches and updates the current user data.

* `updateUserEmail(email:verificationToken:) async throws`
  * Updates the user's email address. If a verification token is provided, the email is marked as verified. Passing an empty string will delete the user's email.

* `updateUserPhoneNumber(phone:verificationToken:) async throws`
  * Updates the user's phone number. If a verification token is provided, the phone number is marked as verified. Passing an empty string will delete the user's phone number.

### Wallet Management

* `fetchWallets() async throws -> [Wallet]`
  * Fetches all wallets for the current user.

* `refreshWallets() async throws`
  * Re-fetches and updates the wallets list.

* `createWallet(walletName:accounts:mnemonicLength:) async throws`
  * Creates a new wallet with optional mnemonic generation.

* `importWallet(walletName:mnemonic:accounts:) async throws`
  * Imports an existing wallet using a mnemonic phrase.

* `exportWallet(walletId:dangerouslyOverrideSignerPublicKey:returnMnemonic:) async throws -> String`
  * Exports the mnemonic phrase for the specified wallet.

### Signing

* `signRawPayload(signWith:payload:encoding:hashFunction:) async throws -> SignRawPayloadResult`
  * Signs a raw payload using the current session.

* `signMessage(walletAddress:message:) async throws -> String`
  * Signs a message with a specific wallet address.

* `signMessage(account:message:) async throws -> String`
  * Signs a message with a specific account.

---

## State Management

The `TurnkeyContext` publishes several properties that automatically update throughout the application lifecycle. You can observe these in SwiftUI views or using Combine:

```swift
@Published public internal(set) var authState: AuthState
```
* Current authentication state: `.loading`, `.unauthenticated`, or `.authenticated`
* Automatically updates when sessions are created, selected, or cleared

```swift
@Published public internal(set) var selectedSessionKey: String?
```
* The key of the currently active session
* `nil` when no session is selected

```swift
@Published public internal(set) var session: Session?
```
* Current session metadata including expiration, public key, user ID, and organization ID
* Automatically updates when sessions change

```swift
@Published public internal(set) var user: v1User?
```
* Current user data including email, phone, and associated wallets
* Automatically refreshed after authentication and user updates
* Access via `turnkey.user?.userEmail`, `turnkey.user?.userPhoneNumber`, etc.

```swift
@Published public internal(set) var wallets: [Wallet]
```
* Array of all wallets for the current user
* Automatically refreshed after authentication and wallet operations
* Each wallet includes accounts, addresses, and metadata

```swift
@Published public internal(set) var client: TurnkeyClient?
```
* Configured API client for making authenticated requests
* Automatically created when a session is selected

### Example Usage

```swift
struct MyView: View {
    @EnvironmentObject private var turnkey: TurnkeyContext
    
    var body: some View {
        VStack {
            if turnkey.authState == .authenticated {
                Text("Welcome, \(turnkey.user?.userEmail ?? "User")")
                
                ForEach(turnkey.wallets) { wallet in
                    Text(wallet.walletName)
                }
            }
        }
    }
}
```

---

## Session Expiry Handling

Each session schedules a timer to automatically clear itself 5 seconds before JWT expiry. If `refreshedSessionTTLSeconds` was provided when creating the session, the SDK will automatically refresh the session before it expires, as long as the app is active.

---

## Demo App

A sample SwiftUI demo app is included in the repository to showcase usage.

---

## Requirements

* iOS 17+ / macOS 14.0+
* Swift 5.9+

---
