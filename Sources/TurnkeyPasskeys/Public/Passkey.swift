import AuthenticationServices
import Foundation
import TurnkeyTypes

public struct PasskeyUser {
  public let id: String
  public let name: String
  public let displayName: String

  public init(id: String, name: String, displayName: String) {
    self.id = id
    self.name = name
    self.displayName = displayName
  }
}

public struct RelyingParty {
  public let id: String
  public let name: String

  public init(id: String, name: String) {
    self.id = id
    self.name = name
  }
}

public struct PasskeyRegistrationResult: Codable {
  public let challenge: String
  public let attestation: v1Attestation
}

/// Indicates whether the current platform version supports passkeys.
///
/// - Returns: `true` if passkeys are supported on this OS version; otherwise `false`.
public var isPasskeySupported: Bool {
  if #available(iOS 16.0, macOS 13.0, *) {
    return true
  }
  return false
}

@available(iOS 16.0, macOS 13.0, *)
/// Creates and registers a new passkey for the given user and relying party.
///
/// - Parameters:
///   - user: Information about the user for whom the passkey is being created.
///   - rp: The relying party (RP) the credential is associated with.
///   - presentationAnchor: A UI anchor used to present the passkey prompt.
///   - excludeCredentials: Optional list of credentials to exclude from registration.
///   - authenticatorType: Preferred authenticator type (`.platformKey` or `.securityKey`).
///
/// - Returns: A `PasskeyRegistrationResult` containing the attestation and challenge.
///
/// - Throws: `PasskeyError` if the registration fails.
public func createPasskey(
  user: PasskeyUser,
  rp: RelyingParty,
  presentationAnchor: ASPresentationAnchor,
  excludeCredentials: [Data] = [],
  authenticatorType: AuthenticatorType = .platformKey
) async throws -> PasskeyRegistrationResult {
  let service = PasskeyRequestBuilder(rpId: rp.id, anchor: presentationAnchor)
  let session = PasskeyOperationRunner(service: service)
  return try await session.register(
    user: user,
    exclude: excludeCredentials,
    authenticator: authenticatorType
  )
}

@available(iOS 16.0, macOS 13.0, *)
public final class PasskeyStamper {
  private let session: PasskeyOperationRunner

  /// Initializes a new `PasskeyStamper` for the specified relying party and UI anchor.
  ///
  /// - Parameters:
  ///   - rpId: The relying party identifier.
  ///   - presentationAnchor: A UI anchor used to present the passkey prompt.
  public init(rpId: String, presentationAnchor: ASPresentationAnchor) {
    let service = PasskeyRequestBuilder(rpId: rpId, anchor: presentationAnchor)
    self.session = PasskeyOperationRunner(service: service)
  }

  /// Performs a passkey assertion against the provided challenge.
  ///
  /// - Parameters:
  ///   - challenge: The challenge to be signed and returned to the server.
  ///   - allowedCredentials: Optional list of credential IDs allowed for assertion.
  ///   - authenticatorType: Preferred authenticator type (`.platformKey` or `.securityKey`).
  ///
  /// - Returns: An `AssertionResult` containing signed assertion data.
  ///
  /// - Throws: `PasskeyError` if the assertion fails.
  public func assert(
    challenge: Data,
    allowedCredentials: [Data]? = nil,
    authenticatorType: AuthenticatorType = .platformKey
  ) async throws -> AssertionResult {
    try await session.assert(
      challenge: challenge,
      allowed: allowedCredentials,
      authenticator: authenticatorType
    )
  }
}
