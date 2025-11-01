import Foundation
import TurnkeyTypes
import TurnkeyHttp

extension TurnkeyContext {

    @MainActor
    internal func setRuntimeConfig(_ config: TurnkeyRuntimeConfig) {
        self.runtimeConfig = config
    }

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

    internal func buildRuntimeConfig(
        walletKitConfig: ProxyGetWalletKitConfigResponse?
    ) -> TurnkeyRuntimeConfig {
        // we sanitize the auth proxy URL
        let trimmedAuthProxyUrl = authProxyUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedAuthProxyUrl = trimmedAuthProxyUrl.isEmpty ? nil : authProxyUrl

        // we resolve the OTP enablement flags
        // TODO: we don't currently have UI, so these are never used
        let emailEnabled = userConfig.auth?.otp?.email
            ?? walletKitConfig?.enabledProviders.contains("email")
            ?? false
        let smsEnabled = userConfig.auth?.otp?.sms
            ?? walletKitConfig?.enabledProviders.contains("sms")
            ?? false

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

        // warnings for auth-proxy controlled overrides when the auth proxy is active
        if authProxyConfigId != nil {
            if userConfig.auth?.sessionExpirationSeconds != nil {
                // TODO: this is partly true, but sessions created client-side (e.g. passkeys) will use this! Lets make that clearer
                print("Turnkey SDK warning: sessionExpirationSeconds is proxy-controlled and will be ignored when using an auth proxy.")
            }
            if userConfig.auth?.otp?.alphanumeric != nil {
                // TODO: so if this does nothing then why even expose it as an option?
                print("Turnkey SDK warning: otp.alphanumeric is proxy-controlled and will be ignored when using an auth proxy.")
            }
            if userConfig.auth?.otp?.length != nil {
                // TODO: so if this does nothing then why even expose it as an option?
                print("Turnkey SDK warning: otp.length is proxy-controlled and will be ignored when using an auth proxy.")
            }
        }

        // Proxy-controlled settings
        // TODO: this will be affected from comment above ^
        let sessionTTL = walletKitConfig?.sessionExpirationSeconds
            ?? Constants.Session.defaultExpirationSeconds
        let otpAlphanumeric = walletKitConfig?.otpAlphanumeric ?? true
        let otpLength = walletKitConfig?.otpLength ?? "6"


        // we resolve create suborg defaults
        // TODO: in other sdks this is normally per auth method and not universal, should we do the same here to be consistent? 
        let createDefaults: TurnkeyRuntimeConfig.Auth.CreateSuborgDefaults? = {
            if let d = userConfig.auth?.createSuborgDefaults {
                return TurnkeyRuntimeConfig.Auth.CreateSuborgDefaults(
                    emailOtpAuth: d.emailOtpAuth,
                    smsOtpAuth: d.smsOtpAuth,
                    passkeyAuth: d.passkeyAuth,
                    oauth: d.oauth
                )
            }
            return nil
        }()

        let auth = TurnkeyRuntimeConfig.Auth(
            sessionExpirationSeconds: sessionTTL,
            otp: .init(
                email: emailEnabled,
                sms: smsEnabled,
                alphanumeric: otpAlphanumeric,
                length: otpLength
            ),
            oauth: .init(
                redirectBaseUrl: redirectBaseUrl,
                appScheme: appScheme,
                providers: resolvedProviders
            ),
            autoRefreshSession: userConfig.auth?.autoRefreshSession ?? true,
            passkey: passkey,
            createSuborgDefaults: createDefaults
        )

        let runtime = TurnkeyRuntimeConfig(
            authProxyUrl: sanitizedAuthProxyUrl,
            auth: auth,
            autoRefreshManagedState: userConfig.autoRefreshManagedState ?? true
        )

        return runtime
    }
}


