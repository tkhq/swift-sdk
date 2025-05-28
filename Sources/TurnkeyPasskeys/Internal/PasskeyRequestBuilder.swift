import AuthenticationServices
import TurnkeyEncoding

final class PasskeyRequestBuilder {
  let rpId: String
  let anchor: ASPresentationAnchor

  init(rpId: String, anchor: ASPresentationAnchor) {
    self.rpId = rpId
    self.anchor = anchor
  }

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
        relyingPartyIdentifier: rpId)
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
        relyingPartyIdentifier: rpId)
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

  func makeAssertionRequest(
    challenge: Data,
    allowedCredentials: [Data]?,
    authenticatorType: AuthenticatorType
  ) -> ASAuthorizationRequest {
    switch authenticatorType {
    case .platformKey:
      let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
        relyingPartyIdentifier: rpId)
      let request = provider.createCredentialAssertionRequest(challenge: challenge)
      if let allowed = allowedCredentials {
        request.allowedCredentials = allowed.map {
          ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0)
        }
      }
      return request

    case .securityKey:
      let provider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(
        relyingPartyIdentifier: rpId)
      let request = provider.createCredentialAssertionRequest(challenge: challenge)
      if let allowed = allowedCredentials {
        request.allowedCredentials = allowed.map {
          ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor(credentialID: $0, transports: [])
        }
      }
      return request
    }
  }

  func handleRegistrationResult(
    _ credential: ASAuthorizationPlatformPublicKeyCredentialRegistration
  ) throws -> PasskeyRegistrationResult {
    guard let attestation = credential.rawAttestationObject else {
      throw PasskeyError.missingAttestationObject
    }
    let clientData = try JSONDecoder().decode(ClientData.self, from: credential.rawClientDataJSON)
    return PasskeyRegistrationResult(
      challenge: clientData.challenge,
      attestation: Attestation(
        credentialId: credential.credentialID.base64URLEncodedString(),
        clientDataJson: credential.rawClientDataJSON.base64URLEncodedString(),
        attestationObject: attestation.base64URLEncodedString(),

        // TODO: can we infer the transport from the registration result?
        // In all honesty this isn't critical so we default to "hybrid" because that's the transport used by passkeys.
        transports: [Transport.hybrid]
      )
    )
  }

  func handleAssertionResult(_ assertion: ASAuthorizationPlatformPublicKeyCredentialAssertion)
    -> AssertionResult
  {
    let userId = String(data: assertion.userID, encoding: .utf8) ?? ""
    return AssertionResult(
      credentialId: assertion.credentialID.base64URLEncodedString(),
      userId: userId,
      signature: assertion.signature,
      authenticatorData: assertion.rawAuthenticatorData,
      clientDataJSON: assertion.rawClientDataJSON.base64URLEncodedString()
    )
  }

  private struct ClientData: Decodable {
    let challenge: String
    let origin: String
    let type: String
  }
}
