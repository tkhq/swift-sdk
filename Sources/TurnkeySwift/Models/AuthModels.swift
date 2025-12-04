import Foundation
import TurnkeyHttp
import TurnkeyTypes

public enum OtpType: String, Codable {
    case email = "OTP_TYPE_EMAIL"
    case sms = "OTP_TYPE_SMS"
}

public enum OAuthCredentialType: String, Sendable {
    case oidcToken
    case authCode
}

public struct OAuthSuccess: Sendable {
    public let oidcToken: String
    public let providerName: String
    public let publicKey: String
}

public struct CreateSubOrgParams: Codable, Sendable {
    /// Name of the user
    public var userName: String?

    /// Name of the sub-organization
    public var subOrgName: String?

    /// Email of the user
    public var userEmail: String?

    /// Tag of the user
    public var userTag: String?

    /// List of authenticators
    public var authenticators: [Authenticator]?

    /// Phone number of the user
    public var userPhoneNumber: String?

    /// Verification token if email or phone number is provided
    public var verificationToken: String?

    /// List of API keys
    public var apiKeys: [ApiKey]?

    /// Custom wallet to create during sub-org creation time
    public var customWallet: v1WalletParams?

    /// List of OAuth providers
    public var oauthProviders: [Provider]?

    public struct Authenticator: Codable, Sendable {
        /// Name of the authenticator
        public var authenticatorName: String?

        /// Challenge string to use for passkey registration
        public var challenge: String

        /// Attestation object returned from the passkey creation process
        public var attestation: v1Attestation
    }

    public struct ApiKey: Codable, Sendable {
        /// Name of the API key
        public var apiKeyName: String?

        /// Public key in hex format
        public var publicKey: String

        /// Curve type
        public var curveType: v1ApiKeyCurve

        /// Expiration in seconds
        public var expirationSeconds: String?
    }

    public struct CustomWallet: Codable, Sendable {
        /// Name of the wallet created
        public var walletName: String

        /// List of wallet accounts to create
        public var walletAccounts: [v1WalletAccountParams]
    }

    public struct Provider: Codable, Sendable {
        /// Name of the OAuth provider
        public var providerName: String

        /// OIDC token
        public var oidcToken: String
    }
}


