import Foundation

struct OtpConfigResolved: Sendable {
    var email: Bool
    var sms: Bool
    var alphanumeric: Bool
    var length: String
}

public struct OauthProviderOverride: Sendable {
    public var clientId: String?
    public var redirectUri: String?
    public init(clientId: String? = nil, redirectUri: String? = nil) {
        self.clientId = clientId
        self.redirectUri = redirectUri
    }
}

public struct OauthProvidersPartial: Sendable {
    public var google: OauthProviderOverride?
    public var apple: OauthProviderOverride?
    public var x: OauthProviderOverride?
    public var discord: OauthProviderOverride?
    public init(google: OauthProviderOverride? = nil, apple: OauthProviderOverride? = nil, x: OauthProviderOverride? = nil, discord: OauthProviderOverride? = nil) {
        self.google = google
        self.apple = apple
        self.x = x
        self.discord = discord
    }
}

struct OauthProviderResolved: Sendable {
    var clientId: String?
    var redirectUri: String?
}

public struct OauthConfigPartial: Sendable {
    public var redirectUri: String?
    public var appScheme: String?
    public var providers: OauthProvidersPartial?
    public init(redirectUri: String? = nil, appScheme: String? = nil, providers: OauthProvidersPartial? = nil) {
        self.redirectUri = redirectUri
        self.appScheme = appScheme
        self.providers = providers
    }
}

struct OauthConfigResolved: Sendable {
    var redirectBaseUrl: String
    var appScheme: String?
    var providers: [String: OauthProviderResolved]
}

public struct PasskeyOptionsPartial: Sendable {
    public var passkeyName: String?
    public var rpId: String?
    public var rpName: String?
    public init(passkeyName: String? = nil, rpId: String? = nil, rpName: String? = nil) {
        self.passkeyName = passkeyName
        self.rpId = rpId
        self.rpName = rpName
    }
}

struct PasskeyOptionsResolved: Sendable {
    var passkeyName: String?
    var rpId: String?
    var rpName: String?
}

public struct CreateSuborgDefaultsPartial: Sendable {
    public var emailOtpAuth: CreateSubOrgParams?
    public var smsOtpAuth: CreateSubOrgParams?
    public var passkeyAuth: CreateSubOrgParams?
    public var oauth: CreateSubOrgParams?
    public init(emailOtpAuth: CreateSubOrgParams? = nil, smsOtpAuth: CreateSubOrgParams? = nil, passkeyAuth: CreateSubOrgParams? = nil, oauth: CreateSubOrgParams? = nil) {
        self.emailOtpAuth = emailOtpAuth
        self.smsOtpAuth = smsOtpAuth
        self.passkeyAuth = passkeyAuth
        self.oauth = oauth
    }
}

struct CreateSuborgDefaultsResolved: Sendable {
    var emailOtpAuth: CreateSubOrgParams?
    var smsOtpAuth: CreateSubOrgParams?
    var passkeyAuth: CreateSubOrgParams?
    var oauth: CreateSubOrgParams?
}

// MARK: Internal runtime config using resolved shapes
struct TurnkeyRuntimeConfig: Sendable {
    struct Auth: Sendable {
        struct Oauth: Sendable {
            typealias Provider = OauthProviderResolved
            var redirectBaseUrl: String
            var appScheme: String?
            var providers: [String: Provider]
        }

        var sessionExpirationSeconds: String
        var oauth: Oauth
        var autoRefreshSession: Bool
        
        typealias Passkey = PasskeyOptionsResolved
        var passkey: Passkey?

        typealias CreateSuborgParamsByAuthMethod = TurnkeyConfig.Auth.CreateSuborgParamsByAuthMethod
        var createSuborgParams: CreateSuborgParamsByAuthMethod?
    }

    var authProxyUrl: String?
    var auth: Auth
    var autoRefreshManagedState: Bool
}

public struct TurnkeyConfig: Sendable {
    public struct Auth: Sendable {
        
        public struct Oauth: Sendable {
            public typealias ProviderOverride = OauthProviderOverride
            public typealias Providers = OauthProvidersPartial
            public var redirectUri: String?
            public var appScheme: String?
            public var providers: Providers?
            public init(redirectUri: String? = nil, appScheme: String? = nil, providers: Providers? = nil) {
                self.redirectUri = redirectUri
                self.appScheme = appScheme
                self.providers = providers
            }
        }
        
        /// CreateSubOrg parameters for each authentication method.
        public struct CreateSuborgParamsByAuthMethod: Sendable {
            public var emailOtpAuth: CreateSubOrgParams?
            public var smsOtpAuth: CreateSubOrgParams?
            public var passkeyAuth: CreateSubOrgParams?
            public var walletAuth: CreateSubOrgParams?
            public var oauth: CreateSubOrgParams?
            
            public init(
                emailOtpAuth: CreateSubOrgParams? = nil,
                smsOtpAuth: CreateSubOrgParams? = nil,
                passkeyAuth: CreateSubOrgParams? = nil,
                walletAuth: CreateSubOrgParams? = nil,
                oauth: CreateSubOrgParams? = nil
            ) {
                self.emailOtpAuth = emailOtpAuth
                self.smsOtpAuth = smsOtpAuth
                self.passkeyAuth = passkeyAuth
                self.walletAuth = walletAuth
                self.oauth = oauth
            }
        }
        
        public var oauth: Oauth?
        public var autoRefreshSession: Bool?
        public typealias Passkey = PasskeyOptionsPartial
        public var passkey: Passkey?
        public var createSuborgParams: CreateSuborgParamsByAuthMethod?
        
        public init(
            oauth: Oauth? = nil,
            autoRefreshSession: Bool? = nil,
            passkey: Passkey? = nil,
            createSuborgParams: CreateSuborgParamsByAuthMethod? = nil
        ) {
            self.oauth = oauth
            self.autoRefreshSession = autoRefreshSession
            self.passkey = passkey
            self.createSuborgParams = createSuborgParams
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
