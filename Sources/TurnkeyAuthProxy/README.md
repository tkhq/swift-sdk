# AuthProxyClient

A fully-typed HTTP client for interacting with the Turnkey Authentication Proxy Service, written in Swift using `OpenAPIURLSession`.

> For high-level abstractions and wallet management, see [TurnkeySwift](../TurnkeySwift/). For direct Turnkey API access, see [TurnkeyHttp](../TurnkeyHttp/).

Official Turnkey Authentication Proxy Service: [https://authproxy.turnkey.com](https://authproxy.turnkey.com)

---

## Authentication Proxy Service

The Turnkey Authentication Proxy Service provides simplified authentication flows for web and mobile applications, supporting:

- **Account Management**: Look up organizations by email, phone, public key, or credential ID
- **OAuth2 Authentication**: Google, Apple, and other OAuth2 provider integration  
- **OTP (One-Time Password)**: SMS and email-based authentication flows
- **User Signup**: Create new organizations with API keys, authenticators, and wallets
- **Session Management**: Generate and manage user sessions
- **Wallet Kit Configuration**: Retrieve configuration for Turnkey's Wallet Kit

This package provides fully-typed HTTP fetchers auto-generated from the Authentication Proxy OpenAPI schema.

---

## Getting Started

### Initialize with Config ID

The `AuthProxyClient` requires a configuration ID that identifies your Turnkey application:

```swift
let configId = "your_auth_proxy_config_id"
let client = AuthProxyClient(configId: configId)
```

### Initialize with Custom Base URL

For development or custom deployments:

```swift
let client = AuthProxyClient(
    configId: "your_config_id", 
    baseUrl: "https://your-custom-authproxy.com"
)
```

---

## Usage Examples

### Account Lookup

Find an organization by email, phone number, public key, or other identifiers:

```swift
let response = try await client.getAccount(
    filterType: "EMAIL", 
    filterValue: "user@example.com"
)
print("Organization ID: \(response.body.json.organizationId)")
```

### OAuth2 Authentication Flow

Authenticate users with OAuth2 providers like Google or Apple:

```swift
// Step 1: Get auth code from OAuth2 provider (Google, Apple, etc.)
let oidcResponse = try await client.oAuth2Authenticate(
    provider: .google,
    authCode: "oauth_auth_code",
    redirectUri: "your://redirect-uri",
    codeVerifier: "pkce_code_verifier",
    nonce: "nonce_value",
    clientId: "your_oauth_client_id"
)

// Step 2: Login with OIDC token and create session
let sessionResponse = try await client.oAuthLogin(
    oidcToken: oidcResponse.body.json.oidcToken,
    publicKey: "your_ephemeral_public_key",
    invalidateExisting: false,
    organizationId: nil
)
print("Session JWT: \(sessionResponse.body.json.session)")
```

### OTP Authentication Flow

Authenticate users with SMS or email OTP:

```swift
// Step 1: Initialize OTP
let initResponse = try await client.initOtp(
    otpType: "OTP_TYPE_SMS", 
    contact: "+1234567890"
)

// Step 2: User enters OTP code, verify it
let verifyResponse = try await client.verifyOtp(
    otpId: initResponse.body.json.otpId,
    otpCode: "123456",
    publicKey: "your_ephemeral_public_key"
)

// Step 3: Login with verification token
let sessionResponse = try await client.otpLogin(
    verificationToken: verifyResponse.body.json.verificationToken,
    publicKey: "your_ephemeral_public_key",
    invalidateExisting: false,
    organizationId: nil,
    clientSignature: nil
)
print("Session JWT: \(sessionResponse.body.json.session)")
```

### User Signup

Create new organizations with wallets and authentication methods:

```swift
let apiKey = Components.Schemas.ApiKeyParamsV2(
    apiKeyName: "Default API Key",
    publicKey: "your_api_public_key", 
    curveType: .secp256k1,
    expirationSeconds: "31536000" // 1 year
)

let wallet = Components.Schemas.WalletParams(
    walletName: "Default Wallet",
    accounts: [
        Components.Schemas.WalletAccountParams(
            curve: .secp256k1,
            pathFormat: .bip32,
            path: "m/44'/60'/0'/0/0",
            addressFormat: .ethereum
        )
    ],
    mnemonicLength: 12
)

let response = try await client.signup(
    userEmail: "user@example.com",
    userPhoneNumber: nil,
    userTag: nil,
    userName: "John Doe",
    organizationName: "My Organization",
    verificationToken: "otp_verification_token",
    apiKeys: [apiKey],
    authenticators: [],
    oauthProviders: [],
    wallet: wallet
)

print("Organization ID: \(response.body.json.organizationId)")
print("Wallet ID: \(response.body.json.wallet?.walletId ?? "No wallet")")
```

### Wallet Kit Configuration

Retrieve configuration for Turnkey's Wallet Kit:

```swift
let config = try await client.getWalletKitConfig()
print("Enabled providers: \(config.body.json.enabledProviders)")
print("Session expiration: \(config.body.json.sessionExpirationSeconds) seconds")
```

---

## Code Generation

This project uses `swift-openapi-generator` and [Sourcery](https://github.com/krzysztofzablocki/Sourcery) with Stencil templates to generate code based on the Authentication Proxy OpenAPI schema.

With the provided `Makefile`, you can:

* Generate updated HTTP fetchers from the OpenAPI spec:

```bash
make authproxy_client_types
```

* Regenerate the `AuthProxyClient` using Sourcery templates:

```bash
make authproxy_client
```

* Run the full code generation flow (types + client + format):

```bash
make generate
```

* Format Swift code recursively:

```bash
make format
```

> Curious how our Stencil templates work? Check out [`Resources/Templates/AuthProxyClient.stencil`](Resources/Templates/AuthProxyClient.stencil) to see how we generate the Swift client methods from OpenAPI operations.

---

## Authentication Flow Integration

The `AuthProxyClient` is designed to work seamlessly with [TurnkeySwift](../TurnkeySwift/) for complete authentication and wallet management:

```swift
// 1. Authenticate with AuthProxy
let authProxyClient = AuthProxyClient(configId: "your_config_id")
let sessionResponse = try await authProxyClient.oAuthLogin(...)

// 2. Use session JWT with TurnkeySwift  
let context = TurnkeyContext(apiUrl: "https://api.turnkey.com")
try await context.createSession(jwt: sessionResponse.body.json.session)

// 3. Now use high-level TurnkeySwift APIs
let wallets = try await context.getWallets()
```

---

## Requirements

* iOS 17+ / macOS 14+
* Swift 5.9+
* OpenAPIURLSession
* OpenAPIRuntime

---

## Error Handling

The client uses type-safe error handling with structured responses:

```swift
do {
    let response = try await client.getAccount(filterType: "EMAIL", filterValue: "user@example.com")
    // Handle success
} catch let error as AuthProxyRequestError {
    switch error {
    case .apiError(let statusCode, let payload):
        print("API Error \(statusCode): \(String(data: payload ?? Data(), encoding: .utf8) ?? "Unknown")")
    case .invalidResponse:
        print("Invalid response format")
    }
} catch {
    print("Network or other error: \(error)")
}
```