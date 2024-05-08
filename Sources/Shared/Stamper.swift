import AuthenticationServices
import CryptoKit
import Foundation

public class Stamper {
  private let apiPublicKey: String?
  private let apiPrivateKey: String?
  private let presentationAnchor: ASPresentationAnchor?
  private let passkeyManager: PasskeyManager?
  private var observer: NSObjectProtocol?

  // TODO: We will want to in the future create a Stamper super class
  // and then create subclasses APIKeyStamper, and PasskeyStamper
  // then we can have a method that takes a Stamper and then calls the appropriate
  // stamp method based on the type of the stamper.
  // This will reduce a lot of duplication in the code and the nil initializations

  /// Initializes a Stamper instance for API key-based stamping.
  /// - Parameters:
  ///   - apiPublicKey: The public key used for API key stamping.
  ///   - apiPrivateKey: The private key used for API key stamping.
  public init(apiPublicKey: String, apiPrivateKey: String) {
    self.apiPublicKey = apiPublicKey
    self.apiPrivateKey = apiPrivateKey
    self.presentationAnchor = nil
    self.passkeyManager = nil
  }

  /// Initializes a Stamper instance for Passkey-based stamping.
  /// - Parameters:
  ///   - rpId: The relying party identifier for WebAuthn.
  ///   - presentationAnchor: The presentation anchor for the authentication session.
  public init(rpId: String, presentationAnchor: ASPresentationAnchor) {
    self.apiPublicKey = nil
    self.apiPrivateKey = nil
    self.presentationAnchor = presentationAnchor
    self.passkeyManager = PasskeyManager(rpId: rpId, presentationAnchor: presentationAnchor)
  }

  public enum StampError: Error {
    case missingCredentials
    case assertionFailed
    case apiKeyStampError(APIKeyStampError)
    case unknownError(String)
    case passkeyManagerNotSet
    case invalidPayload
  }

  /// Asynchronously stamps the given payload string.
  /// - Parameter payload: The string payload to stamp.
  /// - Returns: A tuple containing the header name and the header value for the stamped payload.
  /// - Throws: `StampError` if the payload cannot be processed or if appropriate credentials are missing.
  public func stamp(payload: String) async throws -> (
    stampHeaderName: String, stampHeaderValue: String
  ) {

    guard let payloadData = payload.data(using: .utf8) else {
      throw StampError.invalidPayload
    }

    let payloadHash = SHA256.hash(data: payloadData)

    if let apiPublicKey = apiPublicKey, let apiPrivateKey = apiPrivateKey {

      let stamp = try apiKeyStamp(
        payload: payloadHash, apiPublicKey: apiPublicKey, apiPrivateKey: apiPrivateKey)

      return ("X-Stamp", stamp)
    } else if passkeyManager != nil {
      let stamp = try await passkeyStamp(payload: payloadHash)
      return ("X-Stamp-WebAuthn", stamp)
    } else {
      throw StampError.unknownError("Unable to stamp request")
    }
  }

  enum PasskeyStampError: Error {
    case assertionFailed
  }

  /// Asynchronously performs a Passkey stamp operation using the given SHA256 digest of the payload.
  /// - Parameter payload: The SHA256 digest of the payload to stamp.
  /// - Returns: A JSON string representing the stamp.
  /// - Throws: `PasskeyStampError` on failure.
  public func passkeyStamp(payload: SHA256Digest) async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
      self.observer = NotificationCenter.default.addObserver(
        forName: .PasskeyAssertionCompleted, object: nil, queue: nil
      ) { [weak self] notification in
        guard let self = self else { return }
        NotificationCenter.default.removeObserver(self.observer!)
        self.observer = nil

        if let assertionResult = notification.userInfo?["result"]
          as? ASAuthorizationPlatformPublicKeyCredentialAssertion
        {
          // Construct the result from the assertion
          let assertionInfo = [
            "authenticatorData": assertionResult.rawAuthenticatorData.base64URLEncodedString(),
            "clientDataJson": assertionResult.rawClientDataJSON.base64URLEncodedString(),
            "credentialId": assertionResult.credentialID.base64URLEncodedString(),
            "signature": assertionResult.signature.base64URLEncodedString(),
          ]

          do {
            let jsonData = try JSONSerialization.data(withJSONObject: assertionInfo, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
              continuation.resume(returning: jsonString)
            }
          } catch {
            continuation.resume(throwing: error)
          }
        } else if let error = notification.userInfo?["error"] as? Error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(throwing: StampError.assertionFailed)
        }
      }

      self.passkeyManager?.assertPasskey(challenge: Data(payload))
    }
  }

  public enum APIKeyStampError: Error {
    case invalidPrivateKey
    case invalidPublicKey
    case mismatchedPublicKey(expected: String, actual: String)
    case invalidHexCharacter
    case signatureFailed
    case failedToSerializePayloadToJSON(Error)
  }

  /// Synchronously stamps the given SHA256 digest of the payload using API keys.
  /// - Parameters:
  ///   - payload: The SHA256 digest of the payload.
  ///   - apiPublicKey: The public key used for stamping.
  ///   - apiPrivateKey: The private key used for stamping.
  /// - Returns: A base64-encoded JSON string representing the stamp.
  /// - Throws: `APIKeyStampError` on failure.
  public func apiKeyStamp(payload: SHA256Digest, apiPublicKey: String, apiPrivateKey: String)
    throws -> String
  {
    // Convert the hex string to Data
    guard let privateKeyData = Data(hexString: apiPrivateKey) else {
      throw APIKeyStampError.invalidHexCharacter
    }

    guard let privateKey = try? P256.Signing.PrivateKey(rawRepresentation: privateKeyData) else {
      throw APIKeyStampError.invalidPrivateKey
    }

    let derivedPublicKey = privateKey.publicKey.compressedRepresentation.toHexString()

    if derivedPublicKey != apiPublicKey {
      throw APIKeyStampError.mismatchedPublicKey(expected: apiPublicKey, actual: derivedPublicKey)
    }
    return try apiKeyStamp(
      payload: payload, publicKey: privateKey.publicKey, privateKey: privateKey)
  }

  private func apiKeyStamp(
    payload: SHA256Digest, publicKey: P256.Signing.PublicKey, privateKey: P256.Signing.PrivateKey
  ) throws -> String {

    guard let apiPublicKey = apiPublicKey else {
      throw APIKeyStampError.invalidPublicKey  // Use an appropriate error
    }

    guard let signature = try? privateKey.signature(for: payload) else {
      throw APIKeyStampError.signatureFailed
    }
    let signatureHex = signature.derRepresentation.toHexString()

    let stamp: [String: Any] = [
      "publicKey": apiPublicKey,
      "scheme": "SIGNATURE_SCHEME_TK_API_P256",
      "signature": signatureHex,
    ]

    do {
      let jsonData = try JSONSerialization.data(withJSONObject: stamp, options: [])
      let base64Stamp = jsonData.base64URLEncodedString()
      return base64Stamp
    } catch {
      throw APIKeyStampError.failedToSerializePayloadToJSON(error)
    }
  }

}
