import Foundation
import TurnkeyTypes
import TurnkeyHttp

extension TurnkeyContext {
    @MainActor
    internal func setRuntimeConfig(_ config: TurnkeyRuntimeConfig) {
        self.runtimeConfig = config
    }
    
    /// Initializes the runtime configuration.
    ///
    /// If an Auth Proxy configuration ID is available, this method fetches the Wallet Kit configuration
    /// from the Turnkey Auth Proxy. It then constructs the complete runtime configuration
    /// combining remote and local settings.
    ///
    /// - Note: This function runs asynchronously and updates `runtimeConfig` on the main thread.
    internal func initializeRuntimeConfig() async {
        // if an Auth Proxy config ID is available we fetch the Wallet Kit config
        var walletKitConfig: ProxyGetWalletKitConfigResponse?
        if let client, let _ = self.authProxyConfigId {
            do {
                let response = try await client.proxyGetWalletKitConfig(ProxyTGetWalletKitConfigBody())
                walletKitConfig = response
            } catch {
                walletKitConfig = nil
            }
        }
        
        // we always build the runtime configuration using the Wallet Kit config (if available)
        // and local defaults
        let config = buildRuntimeConfig(walletKitConfig: walletKitConfig)
        await MainActor.run {
            self.runtimeConfig = config
        }
    }
    
    /// Builds the complete runtime configuration object.
    ///
    /// Merges values from the fetched Wallet Kit configuration, user-provided configuration,
    /// and fallback defaults. Handles URL sanitization, OAuth provider overrides, and passkey options.
    ///
    /// - Parameter walletKitConfig: Optional configuration fetched from the Auth Proxy.
    /// - Returns: A fully constructed `TurnkeyRuntimeConfig` instance.
    internal func buildRuntimeConfig(
        walletKitConfig: ProxyGetWalletKitConfigResponse?
    ) -> TurnkeyRuntimeConfig {
        // we sanitize the auth proxy URL
        let trimmedAuthProxyUrl = authProxyUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedAuthProxyUrl = trimmedAuthProxyUrl.isEmpty ? nil : authProxyUrl
        
        // we resolve the OAuth redirect base URL and app scheme
        let redirectBaseUrl = userConfig.auth?.oauth?.redirectUri
        ?? walletKitConfig?.oauthRedirectUrl
        ?? Constants.Turnkey.oauthRedirectUrl
        let appScheme = userConfig.auth?.oauth?.appScheme
        
        // we resolve per-provider OAuth info
        var resolvedProviders: [String: TurnkeyRuntimeConfig.Auth.Oauth.Provider] = [:]
        let proxyClientIds = walletKitConfig?.oauthClientIds ?? [:]
        let providers = ["google", "apple", "x", "discord"]
        for provider in providers {
            let override: TurnkeyConfig.Auth.Oauth.ProviderOverride? = {
                switch provider {
                case "google": return userConfig.auth?.oauth?.providers?.google
                case "apple": return userConfig.auth?.oauth?.providers?.apple
                case "x": return userConfig.auth?.oauth?.providers?.x
                case "discord": return userConfig.auth?.oauth?.providers?.discord
                default: return nil
                }
            }()
            
            let clientId = override?.clientId ?? proxyClientIds[provider]
            
            // for X and Discord, if there is no explicit provider redirect and we have an appScheme
            // we default to scheme://
            let providerRedirect: String? = {
                if let explicit = override?.redirectUri {
                    return explicit
                }
                if (provider == "x" || provider == "discord"), let scheme = appScheme, !scheme.isEmpty {
                    return scheme.hasSuffix("://") ? scheme : "\(scheme)://"
                }
                return nil
            }()
            
            resolvedProviders[provider] = .init(clientId: clientId, redirectUri: providerRedirect)
        }
        
        // we resolve passkey options
        let passkey: TurnkeyRuntimeConfig.Auth.Passkey? = {
            if let p = userConfig.auth?.passkey {
                return TurnkeyRuntimeConfig.Auth.Passkey(
                    passkeyName: p.passkeyName,
                    rpId: p.rpId ?? userConfig.rpId,
                    rpName: p.rpName
                )
            } else if userConfig.rpId != nil {
                return TurnkeyRuntimeConfig.Auth.Passkey(
                    passkeyName: nil,
                    rpId: userConfig.rpId,
                    rpName: nil
                )
            } else {
                return nil
            }
        }()
        
        let auth = TurnkeyRuntimeConfig.Auth(
            sessionExpirationSeconds:  walletKitConfig?.sessionExpirationSeconds ?? Constants.Session.defaultExpirationSeconds,
            oauth: .init(
                redirectBaseUrl: redirectBaseUrl,
                appScheme: appScheme,
                providers: resolvedProviders
            ),
            autoRefreshSession: userConfig.auth?.autoRefreshSession ?? true,
            passkey: passkey,
            createSuborgParams: userConfig.auth?.createSuborgParams
        )
        
        let runtime = TurnkeyRuntimeConfig(
            authProxyUrl: sanitizedAuthProxyUrl,
            auth: auth,
            autoRefreshManagedState: userConfig.autoRefreshManagedState ?? true
        )
        
        return runtime
    }
    
    /// Builds a signup body for creating a new sub-organization.
    ///
    /// Constructs a `ProxyTSignupBody` payload for the Turnkey Auth Proxy based on the provided
    /// `CreateSubOrgParams`. Supports authenticators, API keys, OAuth providers, and user metadata.
    /// Default names are generated automatically when missing.
    ///
    /// - Parameter createSubOrgParams: Parameters describing the new sub-organization, credentials, and user details.
    /// - Returns: A fully populated `ProxyTSignupBody` object suitable for submission to the Auth Proxy.
    func buildSignUpBody(createSubOrgParams: CreateSubOrgParams) -> ProxyTSignupBody {
        // TODO: is there names have a uniqueness constraint per user?
        // if so then this will fail if we have to autofill multiple authenticators (e.g. two apiKeys)
        let now = Int(Date().timeIntervalSince1970)
        
        // authenticators to v1AuthenticatorParamsV2
        let authenticators: [v1AuthenticatorParamsV2]
        if let list = createSubOrgParams.authenticators, !list.isEmpty {
            authenticators = list.map { auth in
                v1AuthenticatorParamsV2(
                    attestation: auth.attestation,
                    authenticatorName: auth.authenticatorName ?? "passkey-\(now)",
                    challenge: auth.challenge
                )
            }
        } else {
            authenticators = []
        }
        
        // apiKeys to v1ApiKeyParamsV2
        let apiKeys: [v1ApiKeyParamsV2]
        if let list = createSubOrgParams.apiKeys, !list.isEmpty {
            apiKeys = list.map { apiKey in
                v1ApiKeyParamsV2(
                    apiKeyName: apiKey.apiKeyName ?? "api-key-\(now)",
                    curveType: apiKey.curveType,
                    expirationSeconds: apiKey.expirationSeconds,
                    publicKey: apiKey.publicKey
                )
            }
        } else {
            apiKeys = []
        }
        
        
        // oauthProviders to v1OauthProviderParams
        let oauthProviders: [v1OauthProviderParams]
        if let list = createSubOrgParams.oauthProviders, !list.isEmpty {
            oauthProviders = list.map { provider in
                v1OauthProviderParams(
                    oidcToken: provider.oidcToken,
                    providerName: provider.providerName
                )
            }
        } else {
            oauthProviders = []
        }
        
        // Construct ProxyTSignupBody
        return ProxyTSignupBody(
            apiKeys: apiKeys,
            authenticators: authenticators,
            oauthProviders: oauthProviders,
            organizationName: createSubOrgParams.subOrgName ?? "sub-org-\(now)",
            userEmail: createSubOrgParams.userEmail,
            userName: createSubOrgParams.userName
            ?? createSubOrgParams.userEmail
            ?? "user-\(now)",
            userPhoneNumber: createSubOrgParams.userPhoneNumber,
            userTag: createSubOrgParams.userTag,
            verificationToken: createSubOrgParams.verificationToken,
            wallet: createSubOrgParams.customWallet
        )
    }
    
    /// Creates an Auth Proxy client if a configuration ID is available.
    ///
    /// Generates a `TurnkeyClient` preconfigured for Auth Proxy requests using the stored
    /// proxy URL and configuration ID.
    ///
    /// - Returns: A configured `TurnkeyClient` if `authProxyConfigId` is set, otherwise `nil`.
    internal func makeAuthProxyClientIfNeeded() -> TurnkeyClient? {
        if let configId = self.authProxyConfigId {
            return TurnkeyClient(
                authProxyConfigId: configId,
                authProxyUrl: self.authProxyUrl
            )
        } else {
            return nil
        }
    }
    
    /// Creates a TurnkeyClient with stamper and optional auth proxy configuration.
    ///
    /// If auth proxy is configured, creates a client that can handle both authenticated
    /// requests (via stamper) and auth proxy requests. Otherwise, creates a client with
    /// only stamper configuration.
    ///
    /// - Parameter apiPublicKey: The hex-encoded API public key whose private key is stored on-device.
    /// - Returns: A configured TurnkeyClient.
    /// - Throws: An error if the private key corresponding to the public key is not found.
    internal func makeClientWithStamper(apiPublicKey: String) throws -> TurnkeyClient {
        if let authProxyConfigId = self.authProxyConfigId {
            return try TurnkeyClient(
                apiPublicKey: apiPublicKey,
                authProxyConfigId: authProxyConfigId,
                baseUrl: apiUrl,
                authProxyUrl: authProxyUrl
            )
        } else {
            return try TurnkeyClient(
                apiPublicKey: apiPublicKey,
                baseUrl: apiUrl
            )
        }
    }
    
    /// Resolves the session expiration duration in seconds.
    ///
    /// Determines the expiration time based on the provided value, runtime configuration,
    /// or the default constant if neither is set.
    ///
    /// - Parameter expirationSeconds: Optional explicit expiration duration in seconds.
    /// - Returns: The resolved expiration duration as a string.
    internal func resolvedSessionExpirationSeconds(expirationSeconds: String? = nil) -> String {
        return expirationSeconds ?? runtimeConfig?.auth.sessionExpirationSeconds ?? Constants.Session.defaultExpirationSeconds
    }
}


