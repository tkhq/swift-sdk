import Foundation

public struct TurnkeyRuntimeConfig: Sendable {
    public struct Auth: Sendable {
        public struct Otp: Sendable {
            public var email: Bool
            public var sms: Bool
            public var alphanumeric: Bool
            public var length: String

            public init(email: Bool, sms: Bool, alphanumeric: Bool, length: String) {
                self.email = email
                self.sms = sms
                self.alphanumeric = alphanumeric
                self.length = length
            }
        }

        public struct Oauth: Sendable {
            public var redirectBaseUrl: String
            public var appScheme: String?

            public init(redirectBaseUrl: String, appScheme: String? = nil) {
                self.redirectBaseUrl = redirectBaseUrl
                self.appScheme = appScheme
            }
        }

        public var sessionExpirationSeconds: String
        public var otp: Otp
        public var oauth: Oauth
        public var autoRefreshSession: Bool

        public init(
            sessionExpirationSeconds: String,
            otp: Otp,
            oauth: Oauth,
            autoRefreshSession: Bool
        ) {
            self.sessionExpirationSeconds = sessionExpirationSeconds
            self.otp = otp
            self.oauth = oauth
            self.autoRefreshSession = autoRefreshSession
        }
    }

    public var authProxyUrl: String?
    public var auth: Auth
    public var autoRefreshManagedState: Bool

    public init(
        authProxyUrl: String?,
        auth: Auth,
        autoRefreshManagedState: Bool
    ) {
        self.authProxyUrl = authProxyUrl
        self.auth = auth
        self.autoRefreshManagedState = autoRefreshManagedState
    }
}


