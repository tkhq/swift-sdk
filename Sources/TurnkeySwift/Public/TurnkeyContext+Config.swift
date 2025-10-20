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
                appScheme: appScheme
            ),
            autoRefreshSession: userConfig.auth?.autoRefreshSession ?? true
        )

        let runtime = TurnkeyRuntimeConfig(
            authProxyUrl: sanitizedAuthProxyUrl,
            auth: auth,
            autoRefreshManagedState: userConfig.autoRefreshManagedState ?? true
        )

        return runtime
    }
}


