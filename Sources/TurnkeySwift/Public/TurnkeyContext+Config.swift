import Foundation
import TurnkeyHttp

extension TurnkeyContext {

    @MainActor
    internal func setRuntimeConfig(_ config: TurnkeyRuntimeConfig) {
        self.runtimeConfig = config
    }

    internal func initializeRuntimeConfig() async {
        // Build with proxy if available; fetch once on init
        var proxy: ProxyGetWalletKitConfigResponse?
        if let client, let _ = self.authProxyConfigId {
            do {
                let response = try await client.proxyGetWalletKitConfig()
                proxy = try response.body.json
            } catch {
                proxy = nil
            }
        }

        let config = buildRuntimeConfig(proxy: proxy)
        await MainActor.run {
            self.runtimeConfig = config
        }
    }

    internal func buildRuntimeConfig(
        proxy: ProxyGetWalletKitConfigResponse?
    ) -> TurnkeyRuntimeConfig {
        // Sanitize auth proxy URL: empty string -> nil
        let trimmedAuthProxyUrl = authProxyUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedAuthProxyUrl = trimmedAuthProxyUrl.isEmpty ? nil : authProxyUrl

        // Resolve OTP enablement flags
        let emailEnabled = userConfig.auth?.otp?.email
            ?? proxy?.enabledProviders.contains("email")
            ?? false
        let smsEnabled = userConfig.auth?.otp?.sms
            ?? proxy?.enabledProviders.contains("sms")
            ?? false

        // Resolve OAuth redirect base URL and app scheme
        let redirectBaseUrl = userConfig.auth?.oauth?.redirectUri
            ?? proxy?.oauthRedirectUrl
            ?? Constants.Turnkey.oauthRedirectUrl
        let appScheme = userConfig.auth?.oauth?.appScheme

        // Resolve per-provider OAuth overrides (exclude facebook)
        var resolvedProviders: [String: TurnkeyRuntimeConfig.Auth.Oauth.Provider] = [:]
        let proxyClientIds = proxy?.oauthClientIds?.additionalProperties ?? [:]
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
            // For X and Discord, if no explicit provider redirect and we have an appScheme, default to scheme://
            let providerRedirect: String? = {
                if let explicit = override?.redirectUri { return explicit }
                if (provider == "x" || provider == "discord"), let scheme = appScheme, !scheme.isEmpty {
                    return "\(scheme)://"
                }
                return nil
            }()

            resolvedProviders[provider] = .init(clientId: clientId, redirectUri: providerRedirect)
        }

        // Warnings for proxy-controlled overrides when proxy is active
        if authProxyConfigId != nil {
            if userConfig.auth?.sessionExpirationSeconds != nil {
                print("Turnkey SDK warning: sessionExpirationSeconds is proxy-controlled and will be ignored when using an auth proxy.")
            }
            if userConfig.auth?.otp?.alphanumeric != nil {
                print("Turnkey SDK warning: otp.alphanumeric is proxy-controlled and will be ignored when using an auth proxy.")
            }
            if userConfig.auth?.otp?.length != nil {
                print("Turnkey SDK warning: otp.length is proxy-controlled and will be ignored when using an auth proxy.")
            }
        }

        // Proxy-controlled settings
        let sessionTTL = proxy?.sessionExpirationSeconds
            ?? Constants.Session.defaultExpirationSeconds
        let otpAlphanumeric = proxy?.otpAlphanumeric ?? true
        let otpLength = proxy?.otpLength ?? "6"

        // Resolve passkey options
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

        // Resolve create suborg defaults
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


