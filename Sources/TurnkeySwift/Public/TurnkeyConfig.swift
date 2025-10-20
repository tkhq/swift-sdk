import Foundation

public struct TurnkeyConfig: Sendable {
    public struct Auth: Sendable {
        public struct Otp: Sendable {
            public var email: Bool?
            public var sms: Bool?
            // Proxy-controlled: ignored when Auth Proxy is active
            public var alphanumeric: Bool?
            public var length: String?

            public init(
                email: Bool? = nil,
                sms: Bool? = nil,
                alphanumeric: Bool? = nil,
                length: String? = nil
            ) {
                self.email = email
                self.sms = sms
                self.alphanumeric = alphanumeric
                self.length = length
            }
        }

        public struct Oauth: Sendable {
            public var redirectUri: String?
            public var appScheme: String?

            public init(redirectUri: String? = nil, appScheme: String? = nil) {
                self.redirectUri = redirectUri
                self.appScheme = appScheme
            }
        }

        public var otp: Otp?
        public var oauth: Oauth?
        public var autoRefreshSession: Bool?
        // Proxy-controlled: ignored when Auth Proxy is active
        public var sessionExpirationSeconds: String?

        public init(
            otp: Otp? = nil,
            oauth: Oauth? = nil,
            autoRefreshSession: Bool? = nil,
            sessionExpirationSeconds: String? = nil
        ) {
            self.otp = otp
            self.oauth = oauth
            self.autoRefreshSession = autoRefreshSession
            self.sessionExpirationSeconds = sessionExpirationSeconds
        }
    }

    public var apiUrl: String
    public var authProxyUrl: String
    public var authProxyConfigId: String?
    public var rpId: String?
    public var organizationId: String?

    public var auth: Auth?
    public var autoRefreshManagedState: Bool?

    public init(
        apiUrl: String = Constants.Turnkey.defaultApiUrl,
        authProxyUrl: String = Constants.Turnkey.defaultAuthProxyUrl,
        authProxyConfigId: String? = nil,
        rpId: String? = nil,
        organizationId: String? = nil,
        auth: Auth? = nil,
        autoRefreshManagedState: Bool? = nil
    ) {
        self.apiUrl = apiUrl
        self.authProxyUrl = authProxyUrl
        self.authProxyConfigId = authProxyConfigId
        self.rpId = rpId
        self.organizationId = organizationId
        self.auth = auth
        self.autoRefreshManagedState = autoRefreshManagedState
    }
}


