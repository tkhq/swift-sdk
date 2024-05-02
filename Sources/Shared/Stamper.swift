import AuthenticationServices
import CryptoKit
import Foundation

public class Stamper {
  private let apiPublicKey: String?
  private let apiPrivateKey: String?
  private let presentationAnchor: ASPresentationAnchor?
  private let passkeyManager: PasskeyManager?
  private let authKeyManager: AuthKeyManager?
  private let keyIdentifier: String?

  // TODO: We will want to in the future create a Stamper super class
  // and then create subclasses AuthKeyStamper, APIKeyStamper, and PasskeyStamper
  // then we can have a method that takes a Stamper and then calls the appropriate
  // stamp method based on the type of the stamper.
  // This will reduce a lot of duplication in the code and the nil initializations
  public init(domain: String, keyIdentifier: String) throws {
    self.apiPublicKey = nil
    self.apiPrivateKey = nil
    self.presentationAnchor = nil
    self.passkeyManager = nil
    self.authKeyManager = try AuthKeyManager(domain: domain)
    self.keyIdentifier = keyIdentifier
  }

  public init(apiPublicKey: String, apiPrivateKey: String) {
    self.apiPublicKey = apiPublicKey
    self.apiPrivateKey = apiPrivateKey
    self.presentationAnchor = nil
    self.passkeyManager = nil
    self.authKeyManager = nil
    self.keyIdentifier = nil
  }

  public init(rpId: String, presentationAnchor: ASPresentationAnchor) {
    self.apiPublicKey = nil
    self.apiPrivateKey = nil
    self.presentationAnchor = presentationAnchor
    self.passkeyManager = PasskeyManager(rpId: rpId, presentationAnchor: presentationAnchor)
    self.authKeyManager = nil
    self.keyIdentifier = nil
  }

  public enum StampError: Error {
    case missingCredentials
    case assertionFailed
    case apiKeyStampError(APIKeyStampError)
    case unknownError(String)
    case passkeyManagerNotSet
    case invalidPayload
  }

  public func stamp(payload: String) async throws -> (
    stampHeaderName: String, stampHeaderValue: String
  ) {

    // Convert payload string to Data
    guard let payloadData = payload.data(using: .utf8) else {
      throw StampError.invalidPayload
    }

    let payloadHash = SHA256.hash(data: payloadData)

    if let apiPublicKey = apiPublicKey, let apiPrivateKey = apiPrivateKey {

      let stamp = try apiKeyStamp(
        payload: payloadHash, apiPublicKey: apiPublicKey, apiPrivateKey: apiPrivateKey)

      return ("X-Stamp", stamp)
    } else if let manager = passkeyManager {
      let stamp = try await passkeyStamp(payload: payloadHash)
      return ("X-Stamp-WebAuthn", stamp)
    } else {
      throw StampError.unknownError("Unable to stamp request")
    }
  }

  enum PasskeyStampError: Error {
    case assertionFailed
  }

  public func passkeyStamp(payload: SHA256Digest) async throws -> String {
    // Convert the completion-based method to async/await using a continuation
    return try await withCheckedThrowingContinuation { continuation in
      var observer: NSObjectProtocol?
      observer = NotificationCenter.default.addObserver(
        forName: .PasskeyAssertionCompleted, object: nil, queue: nil
      ) { notification in
        NotificationCenter.default.removeObserver(observer!)

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
              print(jsonString)
              // Alternatively, resume continuation directly with jsonString
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
    case mismatchedPublicKey(expected: String, actual: String)
    case invalidHexCharacter
    case signatureFailed
    case failedToSerializePayloadToJSON(Error)
  }

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
    print("here")
    return try apiKeyStamp(
      payload: payload, publicKey: privateKey.publicKey, privateKey: privateKey)
  }

  private func apiKeyStamp(
    payload: SHA256Digest, publicKey: P256.Signing.PublicKey, privateKey: P256.Signing.PrivateKey
  ) throws -> String {

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

  /// Generates an API key stamp using cryptographic keys persisted in the keychain.
  /// Typically these keys would be added during the email auth flow.
  ///
  /// This method retrieves a persisted key pair using `usePersistedKey` and then
  /// uses these keys to generate an API key stamp. It ensures that the private key
  /// is cleared from memory after its usage to maintain security.
  ///
  /// - Parameter payload: The SHA256 digest that needs to be stamped.
  /// - Returns: A string representing the base64 URL encoded JSON containing the public key, signature scheme, and signature.
  /// - Throws: Throws an error if the key retrieval or API key stamp generation fails.
  private func apiKeyStamp(payload: SHA256Digest) throws -> String {
    let keys = try usePersistedKey()
    defer {
      // Clear privateKey from memory in AuthKeyManager
      authKeyManager?.clearPrivateKey()
    }
    return try apiKeyStamp(payload: payload, publicKey: keys.publicKey, privateKey: keys.privateKey)
  }

  enum AuthKeyError: Error {
    case noKeyIdentifier
    case noPrivateKeyAvailable
  }

  /// Retrieves a persisted cryptographic key pair from the authentication key manager.
  ///
  /// This method attempts to fetch a stored private key using the `authKeyManager`. If successful,
  /// it also derives the corresponding public key from the private key.
  ///
  /// - Returns: A tuple containing the private key and its corresponding public key.
  /// - Throws: `AuthKeyError.noPrivateKeyAvailable` if no private key could be retrieved.
  ///
  private func usePersistedKey() throws -> (
    privateKey: P256.Signing.PrivateKey, publicKey: P256.Signing.PublicKey
  ) {
    guard let keyIdentifier = keyIdentifier else {
      throw AuthKeyError.noKeyIdentifier
    }
    guard let privateKey = try authKeyManager?.getPrivateKey(keyIdentifier: keyIdentifier) else {
      throw AuthKeyError.noPrivateKeyAvailable
    }
    let publicKey = privateKey.publicKey
    return (privateKey, publicKey)
  }

  public enum DecodingError: Error {
    case oddLengthString
    case invalidHexCharacter
  }

  private func decodeHex(_ hex: String) throws -> Data {
    guard hex.count % 2 == 0 else {
      throw DecodingError.oddLengthString
    }

    var data = Data()
    var bytePair = ""

    for char in hex {
      bytePair += String(char)
      if bytePair.count == 2 {
        guard let byte = UInt8(bytePair, radix: 16) else {
          throw DecodingError.invalidHexCharacter
        }
        data.append(byte)
        bytePair = ""
      }
    }

    return data
  }
}
