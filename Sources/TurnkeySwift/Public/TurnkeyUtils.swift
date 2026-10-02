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

/// Used for building client signature payloads used in OTP authentication flows.
///
/// Client signatures provide two security guarantees:
/// 1. Only the owner of the public key in the verification token's claim can use the token
/// 2. The intent hasn't been tampered with and was directly approved by the key owner
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

    let usage = v1LoginUsage(publicKey: resolvedSessionPublicKey)
    let payload = v1TokenUsage(login: usage, tokenId: decoded.id, type: .usage_type_login)

    let encoder = JSONEncoder()
    let data = try encoder.encode(payload)
    guard let json = String(data: data, encoding: .utf8) else {
      throw TurnkeySwiftError.invalidConfiguration(
        "Failed to encode client signature payload for login")
    }

    return (message: json, clientSignaturePublicKey: verificationPublicKey)
  }

  /// Creates a strict client signature payload for an OTP v2 login.
  ///
  /// This binds every field in `v1LoginUsageV2` to the signature. Pass the exact final values
  /// that will be used for the login request.
  ///
  /// - Parameters:
  ///   - verificationToken: The JWT verification token to decode.
  ///   - organizationId: The organization ID for the login.
  ///   - sessionPublicKey: Optional public key to use instead of the one in the token.
  ///   - invalidateExisting: Whether to invalidate existing sessions.
  ///   - expirationSeconds: The requested session lifetime.
  ///   - sessionProfileId: The requested session profile.
  /// - Returns: A tuple containing the JSON string to sign and the public key for client signature.
  /// - Throws: `TurnkeySwiftError.invalidConfiguration` if no public key is available.
  public static func forLoginV2(
    verificationToken: String,
    organizationId: String,
    sessionPublicKey: String? = nil,
    invalidateExisting: Bool? = nil,
    expirationSeconds: String? = nil,
    sessionProfileId: String? = nil
  ) throws -> (message: String, clientSignaturePublicKey: String) {
    let decoded = try decodeVerificationToken(verificationToken)

    guard let verificationPublicKey = decoded.publicKey else {
      throw TurnkeySwiftError.invalidConfiguration(
        "Verification token is missing a public key"
      )
    }

    let usage = v1LoginUsageV2(
      expirationSeconds: expirationSeconds,
      invalidateExisting: invalidateExisting,
      organizationId: organizationId,
      publicKey: sessionPublicKey ?? verificationPublicKey,
      sessionProfileId: sessionProfileId
    )
    let payload = v1TokenUsage(loginV2: usage, tokenId: decoded.id, type: .usage_type_login)

    let encoder = JSONEncoder()
    let data = try encoder.encode(payload)
    guard let json = String(data: data, encoding: .utf8) else {
      throw TurnkeySwiftError.invalidConfiguration(
        "Failed to encode client signature payload for login")
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
    oauthProviders: [v1OauthProviderParamsV2]? = nil
  ) throws -> (message: String, clientSignaturePublicKey: String) {

    let decoded: VerificationToken = try decodeVerificationToken(verificationToken)

    guard let verificationPublicKey = decoded.publicKey else {
      throw TurnkeySwiftError.invalidConfiguration(
        "Verification token is missing a public key"
      )
    }

    let usage = v1SignupUsageV2(
      apiKeys: apiKeys,
      authenticators: authenticators,
      email: email,
      oauthProviders: oauthProviders,
      phoneNumber: phoneNumber
    )

    let payload = v1TokenUsage(signupV2: usage, tokenId: decoded.id, type: .usage_type_signup)

    let encoder = JSONEncoder()
    let data = try encoder.encode(payload)
    guard let json = String(data: data, encoding: .utf8) else {
      throw TurnkeySwiftError.invalidConfiguration(
        "Failed to encode client signature payload for signup")
    }

    return (message: json, clientSignaturePublicKey: verificationPublicKey)
  }

  /// Creates a strict client signature payload for an OTP signup that creates a sub-organization.
  ///
  /// This binds every field in `v1SignupUsageV3` to the signature. Required strings and arrays
  /// are encoded as provided, including empty values.
  ///
  /// - Parameters:
  ///   - verificationToken: The JWT verification token to decode.
  ///   - parentOrganizationId: The parent organization ID.
  ///   - subOrganizationName: The sub-organization name.
  ///   - rootUsers: The complete root-user configuration.
  ///   - rootQuorumThreshold: The root-user quorum threshold.
  ///   - wallet: The wallet configuration.
  ///   - disableEmailRecovery: Whether to disable email recovery.
  ///   - disableEmailAuth: Whether to disable email authentication.
  ///   - disableSmsAuth: Whether to disable SMS authentication.
  ///   - disableOtpEmailAuth: Whether to disable OTP email authentication.
  /// - Returns: A tuple containing the JSON string to sign and the public key for client signature.
  /// - Throws: `TurnkeySwiftError.invalidConfiguration` if no public key is available in the token.
  public static func forSignupV3(
    verificationToken: String,
    parentOrganizationId: String,
    subOrganizationName: String,
    rootUsers: [v1RootUserParamsV5],
    rootQuorumThreshold: Int,
    wallet: v1WalletParams? = nil,
    disableEmailRecovery: Bool? = nil,
    disableEmailAuth: Bool? = nil,
    disableSmsAuth: Bool? = nil,
    disableOtpEmailAuth: Bool? = nil
  ) throws -> (message: String, clientSignaturePublicKey: String) {
    let decoded = try decodeVerificationToken(verificationToken)

    guard let verificationPublicKey = decoded.publicKey else {
      throw TurnkeySwiftError.invalidConfiguration(
        "Verification token is missing a public key"
      )
    }

    let usage = v1SignupUsageV3(
      disableEmailAuth: disableEmailAuth,
      disableEmailRecovery: disableEmailRecovery,
      disableOtpEmailAuth: disableOtpEmailAuth,
      disableSmsAuth: disableSmsAuth,
      parentOrganizationId: parentOrganizationId,
      rootQuorumThreshold: rootQuorumThreshold,
      rootUsers: rootUsers,
      subOrganizationName: subOrganizationName,
      wallet: wallet
    )
    let payload = v1TokenUsage(signupV3: usage, tokenId: decoded.id, type: .usage_type_signup)

    let encoder = JSONEncoder()
    let data = try encoder.encode(payload)
    guard let json = String(data: data, encoding: .utf8) else {
      throw TurnkeySwiftError.invalidConfiguration(
        "Failed to encode client signature payload for signup")
    }

    return (message: json, clientSignaturePublicKey: verificationPublicKey)
  }
}
