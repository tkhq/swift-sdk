import AuthenticationServices
import CryptoKit
import Foundation

extension Data {
  init?(hexString: String) {
    let len = hexString.count / 2
    var data = Data(capacity: len)
    for i in 0..<len {
      let j = hexString.index(hexString.startIndex, offsetBy: i * 2)
      let k = hexString.index(j, offsetBy: 2)
      let bytes = hexString[j..<k]
      if var num = UInt8(bytes, radix: 16) {
        data.append(&num, count: 1)
      } else {
        return nil
      }
    }
    self = data
  }
  func toHexString() -> String {
    return map { String(format: "%02x", $0) }.joined()
  }
  func base64URLEncodedString() -> String {
    let base64String = self.base64EncodedString()
    let base64URLString =
      base64String
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    return base64URLString
  }
  /// Initializes `Data` by decoding a base64 URL encoded string.
  /// - Parameter base64URLEncoded: The base64 URL encoded string.
  /// - Returns: An optional `Data` instance if the string is valid and successfully decoded, otherwise `nil`.
  init?(base64URLEncoded: String) {
    let paddedBase64 =
      base64URLEncoded
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    // Adjust the string to ensure it's a multiple of 4 for valid base64 decoding
    let paddingLength = (4 - paddedBase64.count % 4) % 4
    let paddedBase64String = paddedBase64 + String(repeating: "=", count: paddingLength)
    guard let data = Data(base64Encoded: paddedBase64String) else {
      return nil
    }
    self = data
  }
}

extension String {
  var hex: some Sequence<UInt8> {
    self[...].hex
  }

  var hexData: Data {
    return Data(hex)
  }
}

extension Substring {
  var hex: some Sequence<UInt8> {
    sequence(
      state: self,
      next: { remainder in
        guard remainder.count > 2 else { return nil }
        let nextTwo = remainder.prefix(2)
        remainder.removeFirst(2)
        return UInt8(nextTwo, radix: 16)
      })
  }
}

public class Stamper {
  private let apiPublicKey: String?
  private let apiPrivateKey: String?
  private let presentationAnchor: ASPresentationAnchor?
  private let passkeyManager: PasskeyManager?

  // Define a typealias for the completion handler
  public typealias StampCompletion = (
    Result<(stampHeaderName: String, stampHeaderValue: String), Error>
  ) -> Void

  public init(apiPublicKey: String, apiPrivateKey: String) {
    self.apiPublicKey = apiPublicKey
    self.apiPrivateKey = apiPrivateKey
    self.presentationAnchor = nil
    self.passkeyManager = nil
  }

  public init(rpId: String, presentationAnchor: ASPresentationAnchor) {
    self.apiPublicKey = nil
    self.apiPrivateKey = nil
    self.presentationAnchor = presentationAnchor
    self.passkeyManager = PasskeyManager(rpId: rpId, presentationAnchor: presentationAnchor)
  }

  public func stamp(payload: String) async throws -> (
    stampHeaderName: String, stampHeaderValue: String
  ) {
    // Convert payload string to Data
    guard let payloadData = payload.data(using: .utf8) else {
      throw PasskeyStampError.invalidPayload
    }

    let payloadHash = SHA256.hash(data: payloadData)
    if let apiPublicKey = apiPublicKey, let apiPrivateKey = apiPrivateKey {
      let result = try apiKeyStamp(
        payload: payloadHash, apiPublicKey: apiPublicKey, apiPrivateKey: apiPrivateKey)
      return ("X-Stamp", result)
    } else if let manager = passkeyManager {
      let result = try await passkeyStamp(payload: payloadHash)
      return ("X-Stamp-WebAuthn", result)
    } else {
      throw StampError.unknownError
    }
  }

  private func passkeyStamp(payload: SHA256Digest) async throws -> String {
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
            "authenticatorData": assertionResult.rawAuthenticatorData.base64EncodedString(),
            "clientDataJson": assertionResult.rawClientDataJSON.base64EncodedString(),
            "credentialId": assertionResult.credentialID.base64EncodedString(),
            "signature": assertionResult.signature.base64EncodedString(),
          ]

          do {
            let jsonData = try JSONSerialization.data(withJSONObject: assertionInfo, options: [])
            let base64Stamp = jsonData.base64URLEncodedString()
            continuation.resume(returning: base64Stamp)
          } catch {
            continuation.resume(throwing: error)
          }
        } else if let error = notification.userInfo?["error"] as? Error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(throwing: StampError.assertionFailed)
        }
      }

      // Assuming there is some method to start the process that will lead to the notification being posted
      self.passkeyManager?.assertPasskey(challenge: Data(payload))
    }
  }

  // Define possible errors
  enum StampError: Error {
    case missingCredentials
    case assertionFailed
    case apiKeyStampError(APIKeyStampError)
    case unknownError
    case passkeyManagerNotSet
  }

  enum APIKeyStampError: Error {
    case invalidPrivateKey
    case mismatchedPublicKey(expected: String, actual: String)
    case invalidHexCharacter
  }

  enum PasskeyStampError: Error {
    case assertionFailed
    case invalidPayload
  }

  private func apiKeyStamp(payload: SHA256Digest, apiPublicKey: String, apiPrivateKey: String)
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
    _ = privateKey.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()

    if derivedPublicKey != apiPublicKey {
      throw APIKeyStampError.mismatchedPublicKey(expected: apiPublicKey, actual: derivedPublicKey)
    }

    let signature = try privateKey.signature(for: payload)
    let signatureHex = signature.derRepresentation.toHexString()

    let stamp: [String: Any] = [
      "publicKey": apiPublicKey,
      "scheme": "SIGNATURE_SCHEME_TK_API_P256",
      "signature": signatureHex,
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: stamp, options: [])
    let base64Stamp = jsonData.base64URLEncodedString()

    return base64Stamp
  }

  enum DecodingError: Error {
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
