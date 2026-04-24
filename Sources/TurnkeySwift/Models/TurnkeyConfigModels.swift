import Foundation

struct OtpConfigResolved: Sendable {
  var email: Bool
  var sms: Bool
  var alphanumeric: Bool
  var length: String
}

public struct GoogleOAuthPrimaryClientId: Sendable {
  public var webClientId: String?
  public init(webClientId: String? = nil) {
    self.webClientId = webClientId
  }
}

public struct GoogleOAuthProviderParams: Sendable {
  public var primaryClientId: GoogleOAuthPrimaryClientId?
  public var secondaryClientIds: [String]?
  public var redirectUri: String?
  public init(
    primaryClientId: GoogleOAuthPrimaryClientId? = nil,
    secondaryClientIds: [String]? = nil,
    redirectUri: String? = nil
  ) {
    self.primaryClientId = primaryClientId
    self.secondaryClientIds = secondaryClientIds
    self.redirectUri = redirectUri
  }
}

public struct AppleOAuthPrimaryClientId: Sendable {
  public var serviceId: String?
  public init(serviceId: String? = nil) {
    self.serviceId = serviceId
  }
}

public struct AppleOAuthProviderParams: Sendable {
  public var primaryClientId: AppleOAuthPrimaryClientId?
  public var secondaryClientIds: [String]?
  public var redirectUri: String?
  public init(
    primaryClientId: AppleOAuthPrimaryClientId? = nil,
    secondaryClientIds: [String]? = nil,
    redirectUri: String? = nil
  ) {
    self.primaryClientId = primaryClientId
    self.secondaryClientIds = secondaryClientIds
    self.redirectUri = redirectUri
  }
}

public struct XOAuthProviderParams: Sendable {
  public var primaryClientId: String?
  public var secondaryClientIds: [String]?
  public var redirectUri: String?
  public init(
    primaryClientId: String? = nil,
    secondaryClientIds: [String]? = nil,
    redirectUri: String? = nil
  ) {
    self.primaryClientId = primaryClientId
    self.secondaryClientIds = secondaryClientIds
    self.redirectUri = redirectUri
  }
}

public struct DiscordOAuthProviderParams: Sendable {
  public var primaryClientId: String?
  public var secondaryClientIds: [String]?
  public var redirectUri: String?
  public init(
    primaryClientId: String? = nil,
    secondaryClientIds: [String]? = nil,
    redirectUri: String? = nil
  ) {
    self.primaryClientId = primaryClientId
    self.secondaryClientIds = secondaryClientIds
    self.redirectUri = redirectUri
  }
}

public struct OAuthProviders: Sendable {
  public var google: GoogleOAuthProviderParams?
  public var apple: AppleOAuthProviderParams?
  public var x: XOAuthProviderParams?
  public var discord: DiscordOAuthProviderParams?
  public init(
    google: GoogleOAuthProviderParams? = nil, apple: AppleOAuthProviderParams? = nil,
    x: XOAuthProviderParams? = nil, discord: DiscordOAuthProviderParams? = nil
  ) {
    self.google = google
    self.apple = apple
    self.x = x
    self.discord = discord
  }
}

public struct OAuthConfig: Sendable {
  public var redirectUri: String?
  public var appScheme: String?
  public var providers: OAuthProviders?
  public init(
    redirectUri: String? = nil, appScheme: String? = nil, providers: OAuthProviders? = nil
  ) {
    self.redirectUri = redirectUri
    self.appScheme = appScheme
    self.providers = providers
  }
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
  public init(
    emailOtpAuth: CreateSubOrgParams? = nil, smsOtpAuth: CreateSubOrgParams? = nil,
    passkeyAuth: CreateSubOrgParams? = nil, oauth: CreateSubOrgParams? = nil
  ) {
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
      var redirectBaseUrl: String
      var appScheme: String?
      var google: GoogleOAuthProviderParams?
      var apple: AppleOAuthProviderParams?
      var x: XOAuthProviderParams?
      var discord: DiscordOAuthProviderParams?
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
      public typealias Providers = OAuthProviders
      public var redirectUri: String?
      public var appScheme: String?
      public var providers: Providers?
      public init(redirectUri: String? = nil, appScheme: String? = nil, providers: Providers? = nil)
      {
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
  public var organizationId: String

  public var auth: Auth?
  public var autoRefreshManagedState: Bool?

  public init(
    organizationId: String,
    apiUrl: String = Constants.Turnkey.defaultApiUrl,
    authProxyUrl: String = Constants.Turnkey.defaultAuthProxyUrl,
    authProxyConfigId: String? = nil,
    rpId: String? = nil,
    auth: Auth? = nil,
    autoRefreshManagedState: Bool? = nil
  ) {
    self.organizationId = organizationId
    self.apiUrl = apiUrl
    self.authProxyUrl = authProxyUrl
    self.authProxyConfigId = authProxyConfigId
    self.rpId = rpId
    self.auth = auth
    self.autoRefreshManagedState = autoRefreshManagedState
  }
}
