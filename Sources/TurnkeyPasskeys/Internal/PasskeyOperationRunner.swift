import AuthenticationServices
import TurnkeyEncoding

final class PasskeyOperationRunner: NSObject {
    private let service: PasskeyRequestBuilder
    private var regCont: CheckedContinuation<PasskeyRegistrationResult, Error>?
    private var assertCont: CheckedContinuation<AssertionResult, Error>?
    
    init(service: PasskeyRequestBuilder) {
        self.service = service
    }
    
    /// Starts a passkey registration flow.
    ///
    /// - Parameters:
    ///   - user: User information for the new credential.
    ///   - exclude: Existing credential IDs to exclude during registration.
    ///   - authenticator: The preferred authenticator type (.platformKey or .securityKey).
    /// - Returns: A successful registration result containing credential and attestation info.
    /// - Throws: `PasskeyError` if registration fails or the user ID is invalid.
    func register(
        user: PasskeyUser,
        exclude: [Data],
        authenticator: AuthenticatorType
    ) async throws -> PasskeyRegistrationResult {
        guard let userId = user.id.data(using: .utf8) else {
            throw PasskeyError.invalidUserId
        }
        
        let challenge = Data.random(count: 32)
        
        let request = service.makeRegistrationRequest(
            userId: userId,
            userName: user.name,
            challenge: challenge,
            excludeCredentials: exclude,
            authenticatorType: authenticator
        )
        
        return try await withCheckedThrowingContinuation { cont in
            Swift.assert(
                regCont == nil && assertCont == nil,
                "Only one continuation should be active at a time"
            )
            
            self.regCont = cont
            self.run(request)
        }
    }
    
    /// Starts a passkey assertion (authentication) flow.
    ///
    /// - Parameters:
    ///   - challenge: Server-provided challenge to sign.
    ///   - allowed: List of credential IDs allowed to assert.
    ///   - authenticator: The preferred authenticator type (.platformKey or .securityKey).
    /// - Returns: A successful assertion result containing the signed challenge.
    /// - Throws: `PasskeyError` if assertion fails.
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
            Swift.assert(
                regCont == nil && assertCont == nil,
                "Only one continuation should be active at a time"
            )
            
            self.assertCont = cont
            self.run(request)
        }
    }
    
    /// Runs an `ASAuthorizationController` with the given request.
    ///
    /// - Parameter request: The authorization request to execute.
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
    /// Handles the result of a successful authorization.
    ///
    /// - Parameters:
    ///   - controller: The authorization controller that completed.
    ///   - auth: The authorization result returned by the system.
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization auth: ASAuthorization
    ) {
        switch auth.credential {
        case let reg as ASAuthorizationPlatformPublicKeyCredentialRegistration:
            if let regCont = regCont {
                do {
                    let result = try service.handleRegistrationResult(reg)
                    regCont.resume(returning: result)
                } catch {
                    regCont.resume(throwing: error)
                }
                self.regCont = nil
            }
            
        case let ass as ASAuthorizationPlatformPublicKeyCredentialAssertion:
            if let assertCont = assertCont {
                do {
                    let result = try service.handleAssertionResult(ass)
                    assertCont.resume(returning: result)
                } catch {
                    assertCont.resume(throwing: error)
                }
                self.assertCont = nil
            }
            
        default:
            let err = PasskeyError.unsupportedOperation
            
            if let regCont = regCont {
                regCont.resume(throwing: err)
                self.regCont = nil
            }
            
            if let assertCont = assertCont {
                assertCont.resume(throwing: err)
                self.assertCont = nil
            }
        }
    }
    
    /// Handles errors that occur during the authorization flow.
    ///
    /// - Parameters:
    ///   - controller: The authorization controller that failed.
    ///   - error: The error that occurred.
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if let regCont = regCont {
            regCont.resume(throwing: PasskeyError.registrationFailed(error))
            self.regCont = nil
        }
        
        if let assertCont = assertCont {
            assertCont.resume(throwing: PasskeyError.assertionFailed(error))
            self.assertCont = nil
        }
    }
    
    /// Provides the presentation anchor for the passkey UI.
    ///
    /// - Parameter controller: The authorization controller requesting a UI anchor.
    /// - Returns: A `UIWindow` or `NSWindow` anchor for displaying the authorization sheet.
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        service.anchor
    }
}
