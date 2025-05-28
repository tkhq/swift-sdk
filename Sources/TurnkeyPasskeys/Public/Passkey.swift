import AuthenticationServices
import Foundation

public var isPasskeySupported: Bool {
  if #available(iOS 16.0, macOS 13.0, *) {
    return true
  }
  return false
}

@available(iOS 16.0, macOS 13.0, *)
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

  public init(rpId: String, presentationAnchor: ASPresentationAnchor) {
    let service = PasskeyRequestBuilder(rpId: rpId, anchor: presentationAnchor)
    self.session = PasskeyOperationRunner(service: service)
  }

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
