### TurnkeySwift ↔ React Native Wallet Kit Parity — Handoff

Updated: 2025-10-24

#### Project context

Goal: bring `TurnkeySwift` to functional parity with React Native Wallet Kit (RNWK) for auth (passkey, OTP, OAuth), session, signing, user updates, and core wallet ops. This handoff summarizes what changed on this branch vs `origin/main`, current status, and what remains.

#### Branch and commit range

- Branch: `taylor/swift-sdk-auth-proxy`
- Range: `origin/main..HEAD`
- Notable commits (newest first):
  - 0bd1071 implement appleoauth
  - bde39ab Implement GoogleOauth
  - 34656bd implement robust config handling
  - 224f072 Adds config builder parity with react native wallet kit
  - 6b250ba implements login/signup with passkey + message signing via authproxy
  - 62676db Adds rpId to config
  - ec9d513 start on passkey abstractions
  - f56cd4a add auth proxy supper, sync client, start on auth abstractions

#### High-level changes vs main (by domain)

- Auth Proxy client (new, generated + adapters)
  - Adds proxy endpoints: `proxyOAuthLogin`, `proxySignup`, `proxyGetAccount`, `proxyInitOtp`, `proxyVerifyOtp`, `proxyOAuth2Authenticate`, `proxyGetWalletKitConfig`.

```10:35:Sources/TurnkeyHttp/Public/TurnkeyClient+AuthProxy.swift
  public func proxyOAuth2Authenticate(
    provider: Components.Schemas.ProxyOauth2Provider, authCode: String, redirectUri: String,
    codeVerifier: String, nonce: String?, clientId: String
  ) async throws -> Operations.OAuth2Authenticate.Output.Ok {
```

- TurnkeySwift public API surface (expanded)
  - OAuth orchestration: Google, Apple, Discord, X implemented end-to-end using Auth Proxy; legacy `startGoogleOAuthFlow` kept (deprecated) for parity.

```88:134:Sources/TurnkeySwift/Public/TurnkeyContext+OAuth.swift
    public func handleGoogleOAuth(
        anchor: ASPresentationAnchor,
        params: GoogleOAuthOptions = .init()
    ) async throws -> CompleteOAuthResult {
        // ... obtains OIDC token then completeOAuth(...)
    }
```

```136:182:Sources/TurnkeySwift/Public/TurnkeyContext+OAuth.swift
    public func handleAppleOAuth(
        anchor: ASPresentationAnchor,
        params: AppleOAuthOptions = .init()
    ) async throws -> CompleteOAuthResult {
        // ...
    }
```

```184:264:Sources/TurnkeySwift/Public/TurnkeyContext+OAuth.swift
    public func handleDiscordOAuth(
        anchor: ASPresentationAnchor,
        params: DiscordOAuthOptions = .init()
    ) async throws -> CompleteOAuthResult {
        // ... PKCE + proxyOAuth2Authenticate → completeOAuth
    }
```

```266:346:Sources/TurnkeySwift/Public/TurnkeyContext+OAuth.swift
    public func handleXOauth(
        anchor: ASPresentationAnchor,
        params: XOAuthOptions = .init()
    ) async throws -> CompleteOAuthResult {
        // ... PKCE + proxyOAuth2Authenticate → completeOAuth
    }
```

```365:383:Sources/TurnkeySwift/Public/TurnkeyContext+OAuth.swift
    @available(*, deprecated, message: "Use handleGoogleOAuth(anchor:params:) instead")
    public func startGoogleOAuthFlow(
        clientId: String,
        nonce: String,
        scheme: String,
        anchor: ASPresentationAnchor,
        originUri: String? = nil,
        redirectUri: String? = nil,
        additionalState: [String: String]? = nil
    ) async throws -> String
```

- OAuth completion funnel (lookup → login or signup) with `completeOAuth` and internal helpers.

```92:135:Sources/TurnkeySwift/Public/TurnkeyContext+AuthProxy.swift
    public func completeOAuth(
        oidcToken: String,
        publicKey: String,
        providerName: String = "google",
        sessionKey: String? = nil,
        invalidateExisting: Bool = false,
        createSubOrgParams: CreateSubOrgParams? = nil
    ) async throws -> CompleteOAuthResult {
        // proxyGetAccount → proxyOAuthLogin | proxySignup → login
    }
```

- OTP parity via Auth Proxy

```148:166:Sources/TurnkeySwift/Public/TurnkeyContext+AuthProxy.swift
    public func initOtp(contact: String, otpType: OtpType) async throws -> String
```

```196:241:Sources/TurnkeySwift/Public/TurnkeyContext+AuthProxy.swift
    public func loginWithOtp(verificationToken: String, organizationId: String, ... ) async throws -> String
```

```255:325:Sources/TurnkeySwift/Public/TurnkeyContext+AuthProxy.swift
    public func signUpWithOtp(verificationToken: String, contact: String, ... ) async throws -> String
```

```355:416:Sources/TurnkeySwift/Public/TurnkeyContext+AuthProxy.swift
    public func completeOtp(otpId: String, otpCode: String, contact: String, ... ) async throws -> CompleteOtpResult
```

- Config/runtime parity with RNWK
  - Introduces `TurnkeyConfig` builder inputs and derives `TurnkeyRuntimeConfig` at startup.
  - Pulls proxy wallet kit config via `proxyGetWalletKitConfig` and merges with app config.

```11:27:Sources/TurnkeySwift/Public/TurnkeyContext+Config.swift
    internal func initializeRuntimeConfig() async {
        // fetch proxy config if available → buildRuntimeConfig(...)
    }
```

```113:123:Sources/TurnkeySwift/Public/TurnkeyContext.swift
    internal func getOAuthProviderSettings(provider: String) throws -> (clientId: String, redirectUri: String, appScheme: String)
```

- Session management
  - Safer `createSession`, selected session restore, refresh, and cleanup.

```31:67:Sources/TurnkeySwift/Public/TurnkeyContext+Session.swift
    public func createSession(jwt: String, sessionKey: String = ..., refreshedSessionTTLSeconds: String? = nil) async throws
```

```75:106:Sources/TurnkeySwift/Public/TurnkeyContext+Session.swift
    @discardableResult public func setSelectedSession(sessionKey: String) async throws -> TurnkeyClient
```

```140:217:Sources/TurnkeySwift/Public/TurnkeyContext+Session.swift
    public func refreshSession(expirationSeconds: String = ..., sessionKey: String? = nil, invalidateExisting: Bool = false) async throws
```

- Signing
  - Message signing parity with Ethereum prefix logic and raw payload signing.

```91:144:Sources/TurnkeySwift/Public/TurnkeyContext+Signing.swift
    public func signMessage(signWith: String, addressFormat: AddressFormat, message: String, ... ) async throws -> SignRawPayloadResult
```

- User and wallet operations
  - `refreshUser`, `updateUser*`, `createWallet`, `exportWallet`, `importWallet`.

```11:32:Sources/TurnkeySwift/Public/TurnkeyContext+User.swift
    public func refreshUser() async { /* updates self.user */ }
```

```15:45:Sources/TurnkeySwift/Public/TurnkeyContext+Wallet.swift
    public func createWallet(walletName: String, accounts: [WalletAccountParams], mnemonicLength: Int32? = nil) async throws
```

#### Current parity status

- Implemented: loginWithPasskey, signUpWithPasskey signMessage
- Newly implemented OAuth orchestration: handleGoogleOAuth, handleAppleOAuth, handleDiscordOAuth, handleXOauth, plus `completeOAuth` flow.
- Not yet implemented: fetchWallets, fetchWalletAccounts, fetchPrivateKeys, refreshWallets, signTransaction, signAndSendTransaction, fetchUser, fetchOrCreateP256ApiKeyUser, fetchOrCreatePolicies, updateUserName, add/removeOauthProviders, add/removePasskeys, createWalletAccounts, exportPrivateKey, exportWalletAccount, importPrivateKey, deleteSubOrganization, clearAllSessions, getSession/getAllSessions (as public API), clearUnusedKeyPairs, getProxyAuthConfig, fetchBootProofForAppProof.

#### What remains (actionable tasks)

- Add public wrappers aligning RN names where applicable:
  - `loginWithOauth`, `signUpWithOauth`, `completeOauth` as thin wrappers around `completeOAuth` with provider parameter.
  - `getProxyAuthConfig` (fetch and return merged runtime config).
- Wallet/account fetchers: optional public `fetchWallets`/`fetchWalletAccounts` that call `refreshUser()` or expose `user` snapshot.
- Transactions: `signTransaction`, `signAndSendTransaction` parity (depends on target chains and RPC strategy; RNWK uses viem/ethers helpers).
- User management: `updateUserName`, remove email/phone convenience wrappers; add/remove OAuth providers; add/remove passkeys.
- Key/Session utilities: `clearAllSessions`, `getSession`, `getAllSessions`, `clearUnusedKeyPairs` (careful with persistence stores).
- Import/export: `exportPrivateKey`, `exportWalletAccount`, `importPrivateKey` (confirm policy/feature availability).
- Boot/app proof: `fetchBootProofForAppProof` if required.

#### Risks and assumptions

- Auth Proxy is required for OAuth and OTP paths; ensure `authProxyConfigId` and proxy URLs are configured.
- Provider client IDs and redirect settings must be present in proxy or user config; missing values cause runtime errors in OAuth flows.
- Transaction signing/send parity requires chain-specific encoding and RPC; scope to EVM first.

#### Test and repro steps

1. Configure context:
   - Ensure `TurnkeyContext.configure(...)` sets `authProxyUrl`, `authProxyConfigId`, `rpId`, `organizationId` as needed.
2. OAuth quick test:
   - Call `handleGoogleOAuth(anchor:params:)` in the example app. Expect OIDC → session created.
3. OTP quick test:
   - `initOtp` → `verifyOtp` → `completeOtp` and confirm session/user populated.
4. Passkey quick test:
   - `signUpWithPasskey` then `loginWithPasskey`. Verify session refresh and user data.
5. Signing:
   - `signMessage(signWith:addressFormat:message:...)` with an ETH account and confirm EIP-191 prefixing.

#### How to re-run the diff

```bash
cd /Users/taylordawson/code/src/github.com/tkhq/swift-sdk
git fetch origin --prune
git diff --stat origin/main...HEAD
git log --oneline --decorate --graph --no-merges origin/main..HEAD
git diff --name-status origin/main...HEAD
```

#### Appendix — diff --stat summary

```
46 files changed, 9119 insertions(+), 2734 deletions(-)
```
