import Foundation
import TurnkeyTypes

/// Decodes a verification token JWT into a structured VerificationToken object.
///
/// - Parameter verificationToken: The JWT string returned from OTP verification.
/// - Returns: A decoded VerificationToken containing the token's claims.
/// - Throws: StorageError.invalidJWT if the token cannot be decoded.
public func decodeVerificationToken(_ verificationToken: String) throws -> VerificationToken {
    return try JWTDecoder.decode(verificationToken, as: VerificationToken.self)
}

public enum ClientSignature {
    /// Creates a client signature payload for login
    ///
    /// - Parameters:
    ///   - verificationToken: The JWT verification token to decode
    ///   - sessionPublicKey: Optional public key to use instead of the one in the token
    /// - Returns: A tuple containing the JSON string to sign and the public key for client signature
    /// - Throws: `TurnkeySwiftError.invalidConfiguration` if no public key is available
    public static func forLogin(
        verificationToken: String,
        sessionPublicKey: String? = nil
    ) throws -> (message: String, clientSignaturePublicKey: String) {
        let decoded = try decodeVerificationToken(verificationToken)

        guard let verificationPublicKey = decoded.publicKey else {
            throw TurnkeySwiftError.invalidConfiguration(
                "Verification token is missing a public key"
            )
        }

        // if a session publicKey was passed in then we use that
        // otherwise we default to the publicKey that lives inside the verificationToken
        let resolvedSessionPublicKey = sessionPublicKey ?? verificationPublicKey

        let usage = v1LoginUsage(publicKey: resolvedSessionPublicKey )
        let payload = v1TokenUsage( login: usage, tokenId: decoded.id, type: .usage_type_login)

        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        guard let json = String(data: data, encoding: .utf8) else {
            throw TurnkeySwiftError.invalidConfiguration("Failed to encode client signature payload for login")
        }

        return (message: json, clientSignaturePublicKey: verificationPublicKey)
    }

    /// Creates a client signature payload for signup
    ///
    /// - Parameters:
    ///   - verificationToken: The JWT verification token to decode
    ///   - email: Optional email address
    ///   - phoneNumber: Optional phone number
    ///   - apiKeys: Optional array of API keys
    ///   - authenticators: Optional array of authenticators
    ///   - oauthProviders: Optional array of OAuth providers
    /// - Returns: A tuple containing the JSON string to sign and the public key for client signature
    /// - Throws: `TurnkeySwiftError.invalidConfiguration` if no public key is available in the token
    public static func forSignup(
        verificationToken: String,
        email: String? = nil,
        phoneNumber: String? = nil,
        apiKeys: [v1ApiKeyParamsV2]? = nil,
        authenticators: [v1AuthenticatorParamsV2]? = nil,
        oauthProviders: [v1OauthProviderParams]? = nil
    ) throws -> (message: String, clientSignaturePublicKey: String) {
        let decoded: VerificationToken = try decodeVerificationToken(verificationToken)
        guard let verificationPublicKey = decoded.publicKey else {
            throw TurnkeySwiftError.invalidConfiguration(
                "Verification token is missing a public key"
            )
        }

        let usage = v1SignupUsage(
            apiKeys: apiKeys,
            authenticators: authenticators,
            email: email,
            oauthProviders: oauthProviders,
            phoneNumber: phoneNumber,
        )

        let payload = v1TokenUsage(signup: usage, tokenId: decoded.id, type: .usage_type_signup)

        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        guard let json = String(data: data, encoding: .utf8) else {
            throw TurnkeySwiftError.invalidConfiguration("Failed to encode client signature payload for signup")
        }

        return (message: json, clientSignaturePublicKey: verificationPublicKey)
    }
}
