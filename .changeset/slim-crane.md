---
bump: major
---

## `TurnkeyCrypto`

Add `encryptOtpCodeToBundle()` helper that encrypts an OTP code and client public key to the enclave's target key using HPKE.

## `TurnkeyTypes`

### `CREATE_OAUTH_PROVIDERS`

`ACTIVITY_TYPE_CREATE_OAUTH_PROVIDERS` → `ACTIVITY_TYPE_CREATE_OAUTH_PROVIDERS_V2`

**What changed:** Added `oidcClaims` as a new option alongside `oidcToken`; you must provide exactly one. This updated type feeds into the `CREATE_SUB_ORGANIZATION` and `CREATE_USERS` changes below.

`v1OauthProviderParamsV2` is now generated as a struct with a `OneOf` enum:

```swift
// before — v1OauthProviderParams
v1OauthProviderParamsV2(
  providerName: "google",
  oidcToken: token
)

// after — v1OauthProviderParamsV2 (oneOf enum)
v1OauthProviderParamsV2(
  providerName: "google",
  oneOf: .oidcToken(token)
)

v1OauthProviderParamsV2(
  providerName: "google",
  oneOf: .oidcClaims(v1OidcClaims(aud: "...", iss: "...", sub: "..."))
)
```

### `CREATE_SUB_ORGANIZATION`

`ACTIVITY_TYPE_CREATE_SUB_ORGANIZATION_V7` → `ACTIVITY_TYPE_CREATE_SUB_ORGANIZATION_V8`

**What changed:** `rootUsers` items updated from `v1RootUserParamsV4` → `v1RootUserParamsV5`, which updates `oauthProviders` from `v1OauthProviderParams` → `v1OauthProviderParamsV2`.

### `CREATE_USERS`

`ACTIVITY_TYPE_CREATE_USERS_V3` → `ACTIVITY_TYPE_CREATE_USERS_V4`

**What changed:** `users` items updated from `v1UserParamsV3` → `v1UserParamsV4`, which updates `oauthProviders` from `v1OauthProviderParams` → `v1OauthProviderParamsV2`.

### `INIT_OTP`

`ACTIVITY_TYPE_INIT_OTP_V2` → `ACTIVITY_TYPE_INIT_OTP_V3`

**What changed:** Added required `otpEncryptionTargetBundle` to the result.

```swift
// before — v1InitOtpResult
otpId: String

// after — v1InitOtpResultV2
otpId: String
otpEncryptionTargetBundle: String // new
```

### `VERIFY_OTP`

`ACTIVITY_TYPE_VERIFY_OTP` → `ACTIVITY_TYPE_VERIFY_OTP_V2`

**What changed:** Replaced plaintext `otpCode` + `publicKey` with a single `encryptedOtpBundle`.

Instead of sending the OTP code in plaintext, you now HPKE-encrypt it (along with your public key) to Turnkey's enclave using the `otpEncryptionTargetBundle` returned by `initOtp`. This ensures the OTP code never leaves the client in plaintext.

Use `encryptOtpCodeToBundle` from `TurnkeyCrypto` to build the bundle:

```swift
import TurnkeyCrypto

let initResult = try await turnkey.initOtp(contact: "user@example.com", otpType: .email)

// After the user enters their OTP code:
let encryptedOtpBundle = try TurnkeyCrypto.encryptOtpCodeToBundle(
  otpCode: otpCode,
  otpEncryptionTargetBundle: initResult.otpEncryptionTargetBundle,
  publicKey: publicKey
)
```

```swift
// before — v1VerifyOtpIntent
otpId: String
otpCode: String           // removed
publicKey: String?        // removed

// after — v1VerifyOtpIntentV2
otpId: String
encryptedOtpBundle: String // new — replaces otpCode + publicKey
```

### `OTP_LOGIN`

`ACTIVITY_TYPE_OTP_LOGIN` → `ACTIVITY_TYPE_OTP_LOGIN_V2`

**What changed:** `clientSignature` promoted from optional to required.

```swift
// before — v1OtpLoginIntent
verificationToken: String
publicKey: String
clientSignature: v1ClientSignature? // optional

// after — v1OtpLoginIntentV2
verificationToken: String
publicKey: String
clientSignature: v1ClientSignature  // now required
```

## `TurnkeySwift`

### `initOtp`

**What changed:** Now calls the V2 proxy endpoint. Returns an `InitOtpResult` with the new `otpEncryptionTargetBundle` required for the V2 OTP verification flow.

```swift
// before
let result = try await turnkey.initOtp(contact: "user@example.com", otpType: .email)
// result.otpId

// after
let result = try await turnkey.initOtp(contact: "user@example.com", otpType: .email)
// result.otpId
// result.otpEncryptionTargetBundle
```

### `verifyOtp`

**What changed:** Added required `otpEncryptionTargetBundle` param. Internally encrypts the OTP code + public key via HPKE and calls `proxyVerifyOtpV2`.

```swift
// before
let result = try await turnkey.verifyOtp(otpId: otpId, otpCode: otpCode)

// after
let result = try await turnkey.verifyOtp(
  otpId: otpId,
  otpCode: otpCode,
  otpEncryptionTargetBundle: otpEncryptionTargetBundle // new — from initOtp
)
```

### `loginWithOtp`

**What changed:** Removed `publicKey` and `organizationId` required params. The key bound during `verifyOtp` is now automatically derived from the verification token and used to produce the required `clientSignature`. Calls `proxyOtpLoginV2`.

```swift
// before
try await turnkey.loginWithOtp(
  verificationToken: verificationToken,
  publicKey: publicKey,
  organizationId: organizationId,
  invalidateExisting: true,
  sessionKey: sessionKey
)

// after
try await turnkey.loginWithOtp(
  verificationToken: verificationToken,
  invalidateExisting: true,
  sessionKey: sessionKey
)
```

### `signUpWithOtp`

**What changed:** Now calls `proxySignupV2` with a `clientSignature`. The key is automatically derived from the verification token.

### `completeOtp`

**What changed:** Added required `otpEncryptionTargetBundle` param (passed through from `initOtp`).

```swift
// before
try await turnkey.completeOtp(
  otpId: otpId,
  otpCode: otpCode,
  contact: "user@example.com",
  otpType: .email
)

// after
try await turnkey.completeOtp(
  otpId: otpId,
  otpCode: otpCode,
  otpEncryptionTargetBundle: otpEncryptionTargetBundle, // new — from initOtp
  contact: "user@example.com",
  otpType: .email
)
```

### `signUpWithOAuth`

**What changed:** Now calls `proxySignupV2` instead of `proxySignup`.

### `signUpWithPasskey`

**What changed:** Now calls `proxySignupV2` instead of `proxySignup`.

### `CreateSubOrgParams.oauthProviders`

**What changed:** Type updated from `[v1OauthProviderParams]?` to `[v1OauthProviderParamsV2]?`. Use the `oneOf` enum when constructing providers:

```swift
// before
CreateSubOrgParams(
  oauthProviders: [
    v1OauthProviderParamsV2(providerName: "google", oidcToken: token)
  ]
)

// after
CreateSubOrgParams(
  oauthProviders: [
    v1OauthProviderParamsV2(providerName: "google", oneOf: .oidcToken(token))
  ]
)
```