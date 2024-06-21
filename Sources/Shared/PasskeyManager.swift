import AuthenticationServices
import Foundation
import os

public struct Attestation {
  public let credentialId: String
  public let clientDataJson: String
  public let attestationObject: String
}

public struct PasskeyRegistrationResult {
  public let challenge: String
  public let attestation: Attestation
}

public enum PasskeyRegistrationError: Error {
  case missingRPID
  case unexpectedCredentialType
  case invalidClientDataJSON
  case registrationFailed(Error)
  case invalidAttestation
}

public enum PasskeyManagerError: Error {
  case unknownAuthorizationType
  case authorizationFailed(Error)
}

public class PasskeyManager: NSObject, ASAuthorizationControllerDelegate,
  ASAuthorizationControllerPresentationContextProviding
{
  private let rpId: String
  private var presentationAnchor: ASPresentationAnchor?
  private var registrationContinuation: CheckedContinuation<PasskeyRegistrationResult, Error>?
  private var assertionContinuation: CheckedContinuation<ASAuthorizationPlatformPublicKeyCredentialAssertion, Error>?

  /// Initializes a new instance of `PasskeyManager` with the specified relying party identifier and presentation anchor.
  /// - Parameters:
  ///   - rpId: The relying party identifier. Note: The `rpId` must correspond to a domain with `webcredentials` configured.
  ///   See Apple docs for more: https://developer.apple.com/documentation/authenticationservices/public-private_key_authentication/supporting_passkeys
  ///   - presentationAnchor: The presentation anchor for displaying authorization interfaces.
  public init(rpId: String, presentationAnchor: ASPresentationAnchor) {
    self.rpId = rpId
    self.presentationAnchor = presentationAnchor
  }

  /// Initiates the registration of a new passkey.
  /// - Parameter email: The email address associated with the new passkey.
  public func registerPasskey(email: String) async throws -> PasskeyRegistrationResult {
    return try await withCheckedThrowingContinuation { continuation in
      self.registrationContinuation = continuation
      let challenge = generateRandomBuffer()
      let userID = Data(UUID().uuidString.utf8)

      let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
      let registrationRequest = publicKeyCredentialProvider.createCredentialRegistrationRequest(
        challenge: challenge,
        name: email.components(separatedBy: "@").first ?? "",
        userID: userID
      )

      let authorizationController = ASAuthorizationController(authorizationRequests: [
        registrationRequest
      ])
      authorizationController.delegate = self
      authorizationController.presentationContextProvider = self
      authorizationController.performRequests()
    }
  }

  /// Initiates the assertion of a passkey using the specified challenge.
  /// - Parameter challenge: The challenge data used for passkey assertion.
  public func assertPasskey(challenge: Data) async throws -> ASAuthorizationPlatformPublicKeyCredentialAssertion {
    return try await withCheckedThrowingContinuation { continuation in
      self.assertionContinuation = continuation
      let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
      let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)
      let authController = ASAuthorizationController(authorizationRequests: [assertionRequest])
      authController.delegate = self
      authController.presentationContextProvider = self
      authController.performRequests()
    }
  }

  /// Generates a random buffer to be used as a challenge in passkey operations.
  /// - Returns: A `Data` object containing random bytes.
  private func generateRandomBuffer() -> Data {
    var bytes = [UInt8](repeating: 0, count: 32)
    _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    return Data(bytes)
  }

  private func base64URLEncode(_ data: Data) -> String {
    let base64 = data.base64EncodedString()
    return
      base64
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  // MARK: - ASAuthorizationControllerDelegate

  /// Handles the completion of an authorization request.
  /// - Parameters:
  ///   - controller: The authorization controller handling the request.
  ///   - authorization: The authorization provided by the system.
  public func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {

    let logger = Logger()
    switch authorization.credential {

    case let credentialRegistration as ASAuthorizationPlatformPublicKeyCredentialRegistration:

      guard let rawAttestationObject = credentialRegistration.rawAttestationObject else {
        registrationContinuation?.resume(throwing: PasskeyRegistrationError.invalidAttestation)
        return
      }

      guard
        let clientDataJSON = try? JSONDecoder().decode(
          ClientDataJSON.self, from: credentialRegistration.rawClientDataJSON)
      else {
        registrationContinuation?.resume(throwing: PasskeyRegistrationError.invalidClientDataJSON)
        return
      }

      let challenge = clientDataJSON.challenge

      let attestationObject = rawAttestationObject.base64URLEncodedString()
      let clientDataJson = credentialRegistration.rawClientDataJSON.base64URLEncodedString()
      let credentialId = credentialRegistration.credentialID.base64URLEncodedString()

      let attestation = Attestation(
        credentialId: credentialId, clientDataJson: clientDataJson,
        attestationObject: attestationObject)

      let registrationResult = PasskeyRegistrationResult(
        challenge: challenge, attestation: attestation)

      registrationContinuation?.resume(returning: registrationResult)
      return
    case let credentialAssertion as ASAuthorizationPlatformPublicKeyCredentialAssertion:
      logger.log("A passkey was used to sign in: \(credentialAssertion)")
      assertionContinuation?.resume(returning: credentialAssertion)
    default:
      assertionContinuation?.resume(throwing: PasskeyManagerError.unknownAuthorizationType)
      registrationContinuation?.resume(throwing: PasskeyManagerError.unknownAuthorizationType)
    }
  }

  /// Handles the completion of an authorization request that ended with an error.
  ///
  /// This method processes errors from an `ASAuthorizationController` and notifies relevant parties
  /// about the specific type of error that occurred, whether it's a cancellation or an unexpected error.
  ///
  /// - Parameters:
  ///   - controller: The `ASAuthorizationController` that managed the authorization request.
  ///   - error: The error that occurred during the authorization process.
  public func authorizationController(
    controller: ASAuthorizationController, didCompleteWithError error: Error
  ) {
    let logger = Logger()
    guard let authorizationError = error as? ASAuthorizationError else {
      logger.error("Unexpected authorization error: \(error.localizedDescription)")
      assertionContinuation?.resume(throwing: PasskeyManagerError.authorizationFailed(error))
      registrationContinuation?.resume(throwing: PasskeyManagerError.authorizationFailed(error))
      return
    }

    if authorizationError.code == .canceled {
      registrationContinuation?.resume(throwing: CancellationError())
      assertionContinuation?.resume(throwing: CancellationError())
    } else {
      logger.error("Error: \((error as NSError).userInfo)")
      assertionContinuation?.resume(throwing: PasskeyManagerError.authorizationFailed(error))
      registrationContinuation?.resume(throwing: PasskeyManagerError.authorizationFailed(error))
    }
  }

  struct ClientDataJSON: Codable {
    let challenge: String
  }

  // MARK: - ASAuthorizationControllerPresentationContextProviding

  public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor
  {
    return presentationAnchor!
  }
}
