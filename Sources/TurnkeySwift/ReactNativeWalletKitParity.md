### React Native Wallet Kit → TurnkeySwift Parity Notes

Updated: 2025-10-20

---

### Functions in React Native `TurnkeyProvider.tsx`

- createHttpClient
- createPasskey
- logout
- loginWithPasskey
- signUpWithPasskey
- initOtp
- verifyOtp
- loginWithOtp
- signUpWithOtp
- completeOtp
- loginWithOauth
- signUpWithOauth
- completeOauth
- fetchWallets
- fetchWalletAccounts
- fetchPrivateKeys
- refreshWallets
- signMessage
- signTransaction
- signAndSendTransaction
- fetchUser
- fetchOrCreateP256ApiKeyUser
- fetchOrCreatePolicies
- refreshUser
- updateUserEmail
- removeUserEmail
- updateUserPhoneNumber
- removeUserPhoneNumber
- updateUserName
- addOauthProvider
- removeOauthProviders
- addPasskey
- removePasskeys
- createWallet
- createWalletAccounts
- exportWallet
- exportPrivateKey
- exportWalletAccount
- importWallet
- importPrivateKey
- deleteSubOrganization
- storeSession
- clearSession
- clearAllSessions
- refreshSession
- getSession
- getAllSessions
- setActiveSession
- clearUnusedKeyPairs
- getActiveSessionKey
- createApiKeyPair
- getProxyAuthConfig
- handleGoogleOauth
- handleXOauth
- handleDiscordOauth
- handleAppleOauth
- handleFacebookOauth
- fetchBootProofForAppProof

---

### Public functions currently available in `@TurnkeySwift`

- TurnkeyContext.configure(apiUrl:authProxyUrl:authProxyConfigId:rpId:organizationId:)
- TurnkeyContext.shared
- createKeyPair()
- createSession(jwt:sessionKey:refreshedSessionTTLSeconds:)
- setSelectedSession(sessionKey:)
- clearSession(for:)
- refreshSession(expirationSeconds:sessionKey:invalidateExisting:)
- loginWithPasskey(anchor:organizationId:publicKey:sessionKey:)
- signUpWithPasskey(anchor:passkeyDisplayName:challenge:createSubOrgParams:sessionKey:organizationId:)
- initOtp(contact:otpType:)
- verifyOtp(otpId:otpCode:)
- loginWithOtp(verificationToken:organizationId:sessionKey:invalidateExisting:publicKey:)
- signUpWithOtp(verificationToken:contact:otpType:createSubOrgParams:invalidateExisting:sessionKey:)
- completeOtp(otpId:otpCode:contact:otpType:publicKey:invalidateExisting:sessionKey:createSubOrgParams:)
- startGoogleOAuthFlow(clientId:nonce:scheme:anchor:originUri:redirectUri:)
- signRawPayload(signWith:payload:encoding:hashFunction:)
- signMessage(signWith:addressFormat:message:encoding:hashFunction:addEthereumPrefix:)
- signMessage(signWith: WalletAccount, message:encoding:hashFunction:addEthereumPrefix:)
- refreshUser()
- updateUser(email:phone:)
- updateUserEmail(email:verificationToken:)
- updateUserPhoneNumber(phone:verificationToken:)
- createWallet(walletName:accounts:mnemonicLength:)
- exportWallet(walletId:)
- importWallet(walletName:mnemonic:accounts:)

---

### Parity checklist (React Native methods; checked = implemented in Swift)

- [ ] createHttpClient
- [x] createPasskey
- [x] logout (Swift: clearSession(for:))
- [x] loginWithPasskey
- [x] signUpWithPasskey
- [x] initOtp
- [x] verifyOtp
- [x] loginWithOtp
- [x] signUpWithOtp
- [x] completeOtp
- [ ] loginWithOauth
- [ ] signUpWithOauth
- [ ] completeOauth
- [ ] fetchWallets
- [ ] fetchWalletAccounts
- [ ] fetchPrivateKeys
- [ ] refreshWallets
- [x] signMessage
- [ ] signTransaction
- [ ] signAndSendTransaction
- [ ] fetchUser
- [ ] fetchOrCreateP256ApiKeyUser
- [ ] fetchOrCreatePolicies
- [x] refreshUser
- [x] updateUserEmail
- [ ] removeUserEmail (Swift: use updateUserEmail("") as workaround)
- [x] updateUserPhoneNumber
- [ ] removeUserPhoneNumber (Swift: use updateUserPhoneNumber("") as workaround)
- [ ] updateUserName
- [ ] addOauthProvider
- [ ] removeOauthProviders
- [ ] addPasskey
- [ ] removePasskeys
- [x] createWallet
- [ ] createWalletAccounts
- [x] exportWallet
- [ ] exportPrivateKey
- [ ] exportWalletAccount
- [x] importWallet
- [ ] importPrivateKey
- [ ] deleteSubOrganization
- [ ] storeSession (Swift: createSession(jwt:...) persists)
- [x] clearSession
- [ ] clearAllSessions
- [x] refreshSession
- [ ] getSession
- [ ] getAllSessions
- [x] setActiveSession (Swift: setSelectedSession)
- [ ] clearUnusedKeyPairs
- [x] getActiveSessionKey (Swift: via TurnkeyContext.selectedSessionKey)
- [x] createApiKeyPair (Swift: createKeyPair)
- [ ] getProxyAuthConfig
- [ ] handleGoogleOauth (Swift: startGoogleOAuthFlow returns OIDC token; no complete step)
- [ ] handleXOauth
- [ ] handleDiscordOauth
- [ ] handleAppleOauth
- [ ] handleFacebookOauth
- [ ] fetchBootProofForAppProof

---

### Detailed Parity Table

| Status | Function                    | Swift location                                                       | Notes                                                           |
| ------ | --------------------------- | -------------------------------------------------------------------- | --------------------------------------------------------------- |
| [ ]    | createHttpClient            | -                                                                    | Not implemented                                                 |
| [x]    | createPasskey               | swift-sdk/Sources/TurnkeyPasskeys/Public/Passkey.swift               | Provided by TurnkeyPasskeys; used by signUpWithPasskey          |
| [x]    | logout                      | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext+Session.swift   | Use `clearSession(for:)`                                        |
| [x]    | loginWithPasskey            | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext+AuthProxy.swift | -                                                               |
| [x]    | signUpWithPasskey           | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext+AuthProxy.swift | -                                                               |
| [x]    | initOtp                     | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext+AuthProxy.swift | -                                                               |
| [x]    | verifyOtp                   | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext+AuthProxy.swift | -                                                               |
| [x]    | loginWithOtp                | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext+AuthProxy.swift | -                                                               |
| [x]    | signUpWithOtp               | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext+AuthProxy.swift | -                                                               |
| [x]    | completeOtp                 | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext+AuthProxy.swift | -                                                               |
| [ ]    | loginWithOauth              | -                                                                    | Not implemented; use `startGoogleOAuthFlow` to get OIDC token   |
| [ ]    | signUpWithOauth             | -                                                                    | Not implemented                                                 |
| [ ]    | completeOauth               | -                                                                    | Not implemented                                                 |
| [ ]    | fetchWallets                | -                                                                    | Not implemented; use `refreshUser()` to populate `user.wallets` |
| [ ]    | fetchWalletAccounts         | -                                                                    | Not implemented; `refreshUser()` fetches accounts per wallet    |
| [ ]    | fetchPrivateKeys            | -                                                                    | Not implemented                                                 |
| [ ]    | refreshWallets              | -                                                                    | Not implemented; use `refreshUser()`                            |
| [x]    | signMessage                 | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext+Signing.swift   | Two overloads; Ethereum prefixing supported                     |
| [ ]    | signTransaction             | -                                                                    | Not implemented                                                 |
| [ ]    | signAndSendTransaction      | -                                                                    | Not implemented                                                 |
| [ ]    | fetchUser                   | -                                                                    | Not implemented; use `refreshUser()`                            |
| [ ]    | fetchOrCreateP256ApiKeyUser | -                                                                    | Not implemented                                                 |
| [ ]    | fetchOrCreatePolicies       | -                                                                    | Not implemented                                                 |
| [x]    | refreshUser                 | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext+User.swift      | Updates `user` and `wallets` state                              |
| [x]    | updateUserEmail             | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext+User.swift      | -                                                               |
| [ ]    | removeUserEmail             | -                                                                    | Not implemented; call `updateUserEmail("")` to remove           |
| [x]    | updateUserPhoneNumber       | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext+User.swift      | -                                                               |
| [ ]    | removeUserPhoneNumber       | -                                                                    | Not implemented; call `updateUserPhoneNumber("")` to remove     |
| [ ]    | updateUserName              | -                                                                    | Not implemented                                                 |
| [ ]    | addOauthProvider            | -                                                                    | Not implemented                                                 |
| [ ]    | removeOauthProviders        | -                                                                    | Not implemented                                                 |
| [ ]    | addPasskey                  | -                                                                    | Not implemented                                                 |
| [ ]    | removePasskeys              | -                                                                    | Not implemented                                                 |
| [x]    | createWallet                | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext+Wallet.swift    | -                                                               |
| [ ]    | createWalletAccounts        | -                                                                    | Not implemented                                                 |
| [x]    | exportWallet                | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext+Wallet.swift    | Returns mnemonic (decrypted)                                    |
| [ ]    | exportPrivateKey            | -                                                                    | Not implemented                                                 |
| [ ]    | exportWalletAccount         | -                                                                    | Not implemented                                                 |
| [x]    | importWallet                | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext+Wallet.swift    | -                                                               |
| [ ]    | importPrivateKey            | -                                                                    | Not implemented                                                 |
| [ ]    | deleteSubOrganization       | -                                                                    | Not implemented                                                 |
| [ ]    | storeSession                | -                                                                    | Not implemented; `createSession(jwt:...)` persists              |
| [x]    | clearSession                | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext+Session.swift   | -                                                               |
| [ ]    | clearAllSessions            | -                                                                    | Not implemented                                                 |
| [x]    | refreshSession              | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext+Session.swift   | -                                                               |
| [ ]    | getSession                  | -                                                                    | Not implemented as public API                                   |
| [ ]    | getAllSessions              | -                                                                    | Not implemented as public API                                   |
| [x]    | setActiveSession            | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext+Session.swift   | Use `setSelectedSession(sessionKey:)`                           |
| [ ]    | clearUnusedKeyPairs         | -                                                                    | Not implemented as public API                                   |
| [x]    | getActiveSessionKey         | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext.swift           | Use `TurnkeyContext.selectedSessionKey`                         |
| [x]    | createApiKeyPair            | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext+Session.swift   | Use `createKeyPair()`                                           |
| [ ]    | getProxyAuthConfig          | -                                                                    | Not implemented                                                 |
| [ ]    | handleGoogleOauth           | swift-sdk/Sources/TurnkeySwift/Public/TurnkeyContext+OAuth.swift     | Partial: `startGoogleOAuthFlow` returns OIDC token only         |
| [ ]    | handleXOauth                | -                                                                    | Not implemented                                                 |
| [ ]    | handleDiscordOauth          | -                                                                    | Not implemented                                                 |
| [ ]    | handleAppleOauth            | -                                                                    | Not implemented                                                 |
| [-]    | handleFacebookOauth         | -                                                                    | Might not go out in next release                                |
| [ ]    | fetchBootProofForAppProof   | -                                                                    | Not implemented                                                 |

---

### Notes

- Equivalents:
  - logout → clearSession(for:)
  - setActiveSession → setSelectedSession(sessionKey:)
  - createApiKeyPair → createKeyPair()
  - getActiveSessionKey → TurnkeyContext.selectedSessionKey (property)
- Wallets/accounts are refreshed via refreshUser(); no standalone fetchWallets/fetchWalletAccounts APIs yet.
- OAuth: startGoogleOAuthFlow exists (gets OIDC token) but end-to-end login/signup helpers and provider-specific handlers are not yet implemented in Swift.
