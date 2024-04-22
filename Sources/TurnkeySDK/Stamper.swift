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

class Stamper {
  private let apiPublicKey: String?
  private let apiPrivateKey: String?
  private let presentationAnchor: ASPresentationAnchor?
  private let passkeyManager: PasskeyManager?

  // Define a typealias for the completion handler
  typealias StampCompletion = (Result<(stampHeaderName: String, stampHeaderValue: String), Error>)
    -> Void

  init(apiPublicKey: String, apiPrivateKey: String) {
    self.apiPublicKey = apiPublicKey
    self.apiPrivateKey = apiPrivateKey
    self.presentationAnchor = nil
    self.passkeyManager = nil
  }

  init(rpId: String, presentationAnchor: ASPresentationAnchor) {
    self.apiPublicKey = nil
    self.apiPrivateKey = nil
    self.presentationAnchor = presentationAnchor
    self.passkeyManager = PasskeyManager(rpId: rpId)
  }

  func stamp(payload: String, completion: @escaping StampCompletion) {
    if let apiPublicKey = apiPublicKey, let apiPrivateKey = apiPrivateKey {
      Task {
        do {
          let result = try await apiKeyStamp(
            payload: payload, apiPublicKey: apiPublicKey, apiPrivateKey: apiPrivateKey)
          completion(.success(result))
        } catch let error as APIKeyStampError {
          completion(.failure(error))
        } catch {
          completion(.failure(StampError.unknownError))
        }
      }
    } else if let presentationAnchor = presentationAnchor {
      passkeyStamp(payload: payload, presentationAnchor: presentationAnchor, completion: completion)
    } else {
      completion(.failure(StampError.unknownError))
    }
  }
  private func passkeyStamp(
    payload: String, presentationAnchor: ASPresentationAnchor, completion: @escaping StampCompletion
  ) {

    // Set up listening before making the assertion
    var observer: NSObjectProtocol?
    observer = NotificationCenter.default.addObserver(
      forName: .PasskeyAssertionCompleted, object: nil, queue: nil
    ) { [weak observer] notification in
      if let obs = observer {
        NotificationCenter.default.removeObserver(obs)
      }

      if let assertionResult = notification.userInfo?["result"]
        as? ASAuthorizationPlatformPublicKeyCredentialAssertion
      {
        // Handle the successful assertion
        let assertionInfo = [
          "authenticatorData": assertionResult.rawAuthenticatorData.base64EncodedString(),
          "clientDataJson": String(data: assertionResult.rawClientDataJSON, encoding: .utf8) ?? "",
          "credentialId": assertionResult.credentialID.base64EncodedString(),
          "signature": assertionResult.signature.base64EncodedString(),
        ]

        do {
          let jsonData = try JSONSerialization.data(withJSONObject: assertionInfo, options: [])
          let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
          completion(.success(("X-Stamp", jsonString)))
        } catch {
          completion(.failure(error))
        }
      } else if let error = notification.userInfo?["error"] as? Error {
        // Handle any errors that occurred during the assertion
        completion(.failure(error))
      } else {
        // Handle the general failure case
        completion(.failure(StampError.assertionFailed))
      }
    }

      // Perform the assertion
    if let manager = self.passkeyManager {
        manager.assertPasskey(
            challenge: Data(payload.utf8), presentationAnchor: presentationAnchor)
    } else {
        // Handle the case where passkeyManager is nil
        completion(.failure(StampError.passkeyManagerNotSet))
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

  private func apiKeyStamp(payload: String, apiPublicKey: String, apiPrivateKey: String) async throws -> (
    stampHeaderName: String, stampHeaderValue: String
  ) {
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

        // Convert payload string to Data
    guard let payloadData = payload.data(using: .utf8) else {
        throw PasskeyStampError.invalidPayload
    }

    let dataHash = SHA256.hash(data: payloadData)
    let signature = try privateKey.signature(for: dataHash)
    let signatureHex = signature.derRepresentation.toHexString()

    let stamp: [String: Any] = [
      "publicKey": apiPublicKey,
      "scheme": "SIGNATURE_SCHEME_TK_API_P256",
      "signature": signatureHex,
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: stamp, options: [])
    let base64Stamp = jsonData.base64URLEncodedString()

    return ("X-Stamp", base64Stamp)
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
