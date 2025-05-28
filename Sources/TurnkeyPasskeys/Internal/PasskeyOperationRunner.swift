import AuthenticationServices

final class PasskeyOperationRunner: NSObject {
  private let service: PasskeyRequestBuilder
  private var regCont: CheckedContinuation<PasskeyRegistrationResult, Error>?
  private var assertCont: CheckedContinuation<AssertionResult, Error>?

  init(service: PasskeyRequestBuilder) {
    self.service = service
  }

  func register(
    user: PasskeyUser,
    exclude: [Data],
    authenticator: AuthenticatorType
  ) async throws -> PasskeyRegistrationResult {
    guard let userId = user.id.data(using: .utf8) else { throw PasskeyError.invalidUserId }
    let challenge = Data.random(count: 32)
    let request = service.makeRegistrationRequest(
      userId: userId,
      userName: user.name,
      challenge: challenge,
      excludeCredentials: exclude,
      authenticatorType: authenticator
    )
    return try await withCheckedThrowingContinuation { cont in
      self.regCont = cont
      self.run(request)
    }
  }

  func assert(
    challenge: Data,
    allowed: [Data]?,
    authenticator: AuthenticatorType
  ) async throws -> AssertionResult {
    let request = service.makeAssertionRequest(
      challenge: challenge,
      allowedCredentials: allowed,
      authenticatorType: authenticator
    )
    return try await withCheckedThrowingContinuation { cont in
      self.assertCont = cont
      self.run(request)
    }
  }

  private func run(_ request: ASAuthorizationRequest) {
    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = self
    controller.presentationContextProvider = self
    controller.performRequests()
  }
}

extension PasskeyOperationRunner: ASAuthorizationControllerDelegate,
  ASAuthorizationControllerPresentationContextProviding
{
  func authorizationController(
    controller: ASAuthorizationController, didCompleteWithAuthorization auth: ASAuthorization
  ) {
    switch auth.credential {
    case let reg as ASAuthorizationPlatformPublicKeyCredentialRegistration:
      do { regCont?.resume(returning: try service.handleRegistrationResult(reg)) } catch {
        regCont?.resume(throwing: error)
      }
      regCont = nil
    case let ass as ASAuthorizationPlatformPublicKeyCredentialAssertion:
      assertCont?.resume(returning: service.handleAssertionResult(ass))
      assertCont = nil
    default:
      let err = PasskeyError.unsupportedOperation
      regCont?.resume(throwing: err)
      assertCont?.resume(throwing: err)
      regCont = nil
      assertCont = nil
    }
  }

  func authorizationController(
    controller: ASAuthorizationController, didCompleteWithError error: Error
  ) {
    regCont?.resume(throwing: PasskeyError.registrationFailed(error))
    assertCont?.resume(throwing: PasskeyError.assertionFailed(error))
    regCont = nil
    assertCont = nil
  }

  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    service.anchor
  }
}
