import AuthenticationServices
import TurnkeyEncoding
import TurnkeyTypes

private struct ClientData: Decodable {
  let challenge: String
  let origin: String
  let type: String
}

final class PasskeyRequestBuilder {
  let rpId: String
  let anchor: ASPresentationAnchor

  /// Initializes a new builder for passkey registration and assertion requests.
  ///
  /// - Parameters:
  ///   - rpId: The relying party identifier (domain).
  ///   - anchor: The presentation anchor for displaying the credential UI.
  init(rpId: String, anchor: ASPresentationAnchor) {
    self.rpId = rpId
    self.anchor = anchor
  }

  /// Constructs a credential registration request for passkeys or security keys.
  ///
  /// - Parameters:
  ///   - userId: The user's unique ID in raw byte form.
  ///   - userName: A human-readable name associated with the user.
  ///   - challenge: A 32-byte challenge from the server.
  ///   - excludeCredentials: A list of credential IDs to exclude.
  ///   - authenticatorType: The type of authenticator to use (platform or security key).
  /// - Returns: A configured `ASAuthorizationRequest`.
  func makeRegistrationRequest(
    userId: Data,
    userName: String,
    challenge: Data,
    excludeCredentials: [Data],
    authenticatorType: AuthenticatorType
  ) -> ASAuthorizationRequest {
    switch authenticatorType {
    case .platformKey:
      let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
        relyingPartyIdentifier: rpId
      )
      let request = provider.createCredentialRegistrationRequest(
        challenge: challenge,
        name: userName,
        userID: userId
      )
      if #available(iOS 17.4, *) {
        request.excludedCredentials = excludeCredentials.map {
          ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0)
        }
      }
      return request

    case .securityKey:
      let provider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(
        relyingPartyIdentifier: rpId
      )
      let request = provider.createCredentialRegistrationRequest(
        challenge: challenge,
        displayName: userName,
        name: userName,
        userID: userId
      )
      if #available(iOS 17.4, *) {
        request.excludedCredentials = excludeCredentials.map {
          ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor(credentialID: $0, transports: [])
        }
      }
      return request
    }
  }

  /// Constructs a credential assertion (authentication) request.
  ///
  /// - Parameters:
  ///   - challenge: A challenge from the server to sign.
  ///   - allowedCredentials: Optional list of credential IDs allowed for authentication.
  ///   - authenticatorType: The type of authenticator to use (platform or security key).
  /// - Returns: A configured `ASAuthorizationRequest`.
  func makeAssertionRequest(
    challenge: Data,
    allowedCredentials: [Data]?,
    authenticatorType: AuthenticatorType
  ) -> ASAuthorizationRequest {
    switch authenticatorType {
    case .platformKey:
      let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
        relyingPartyIdentifier: rpId
      )
      let request = provider.createCredentialAssertionRequest(challenge: challenge)
      if let allowed = allowedCredentials {
        request.allowedCredentials = allowed.map {
          ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0)
        }
      }
      return request

    case .securityKey:
      let provider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(
        relyingPartyIdentifier: rpId
      )
      let request = provider.createCredentialAssertionRequest(challenge: challenge)
      if let allowed = allowedCredentials {
        request.allowedCredentials = allowed.map {
          ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor(credentialID: $0, transports: [])
        }
      }
      return request
    }
  }

  /// Parses the registration result returned by the system.
  ///
  /// - Parameter credential: The credential returned from a successful registration.
  /// - Returns: A `PasskeyRegistrationResult` containing the attestation data.
  /// - Throws: `PasskeyError.missingAttestationObject` if attestation data is missing.
  func handleRegistrationResult(
    _ credential: ASAuthorizationPlatformPublicKeyCredentialRegistration
  ) throws -> PasskeyRegistrationResult {
    guard let attestation = credential.rawAttestationObject else {
      throw PasskeyError.missingAttestationObject
    }

    let clientData = try JSONDecoder().decode(ClientData.self, from: credential.rawClientDataJSON)

    return PasskeyRegistrationResult(
      challenge: clientData.challenge,
      attestation: v1Attestation(
        attestationObject: attestation.base64URLEncodedString(),
        clientDataJson: credential.rawClientDataJSON.base64URLEncodedString(),
        credentialId: credential.credentialID.base64URLEncodedString(),

        // TODO: Can we infer the transport from the registration result?
        // Defaulting to "hybrid" since that's commonly used for passkeys.
        transports: [v1AuthenticatorTransport.authenticator_transport_hybrid]
      )
    )
  }

  /// Parses the assertion result returned by the system.
  ///
  /// - Parameter assertion: The credential returned from a successful assertion.
  /// - Returns: A fully formed `AssertionResult`.
  /// - Throws: `PasskeyError.invalidUserId` if the user ID cannot be decoded.
  func handleAssertionResult(
    _ assertion: ASAuthorizationPlatformPublicKeyCredentialAssertion
  ) throws -> AssertionResult {
    guard let userId = String(data: assertion.userID, encoding: .utf8) else {
      throw PasskeyError.invalidUserId
    }

    return AssertionResult(
      credentialId: assertion.credentialID.base64URLEncodedString(),
      userId: userId,
      signature: assertion.signature,
      authenticatorData: assertion.rawAuthenticatorData,
      clientDataJSON: assertion.rawClientDataJSON.base64URLEncodedString()
    )
  }
}
