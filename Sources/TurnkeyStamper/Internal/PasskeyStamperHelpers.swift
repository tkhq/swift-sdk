import CryptoKit
import Foundation
import TurnkeyPasskeys

enum PasskeyStamperHelpers {
  static func stamp(
    payload: SHA256Digest,
    passkeyManager: PasskeyStamper
  ) async throws -> String {
    guard let challengeData = payload.hexEncoded.data(using: .utf8) else {
      throw StampError.assertionFailed
    }

    let assertion = try await passkeyManager.assert(challenge: challengeData)
    let assertionInfo = [
      "authenticatorData": assertion.authenticatorData.base64URLEncodedString(),
      "clientDataJson": assertion.clientDataJSON,
      "credentialId": assertion.credentialId,
      "signature": assertion.signature.base64URLEncodedString(),
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: assertionInfo, options: [])
    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
      throw StampError.assertionFailed
    }

    return jsonString
  }
}
