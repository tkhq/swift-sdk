import CryptoKit
import Foundation
import TurnkeyPasskeys

enum PasskeyStampBuilder {

  /// Generates a base64url-encoded JSON WebAuthn stamp by asserting a passkey over the given payload.
  ///
  /// - Parameters:
  ///   - payload: The SHA-256 digest of the request payload to sign.
  ///   - passkeyManager: A configured `PasskeyStamper` instance used to perform the WebAuthn assertion.
  /// - Returns: A base64url-encoded JSON string containing authenticator data, client data, credential ID, and signature.
  /// - Throws: `StampError.assertionFailed` if the assertion or JSON encoding fails.
  static func stamp(
    payload: SHA256Digest,
    passkeyManager: PasskeyStamper
  ) async throws -> String {
    guard let challengeData = payload.hexEncoded.data(using: .utf8) else {
      throw PasskeyStampError.invalidChallenge
    }

    let assertion: AssertionResult
    do {
      assertion = try await passkeyManager.assert(challenge: challengeData)
    } catch {
      throw PasskeyStampError.assertionFailed(error)
    }

    let assertionInfo = [
      "authenticatorData": assertion.authenticatorData.base64URLEncodedString(),
      "clientDataJson": assertion.clientDataJSON,
      "credentialId": assertion.credentialId,
      "signature": assertion.signature.base64URLEncodedString(),
    ]

    let jsonData: Data
    do {
      jsonData = try JSONSerialization.data(withJSONObject: assertionInfo, options: [])
    } catch {
      throw PasskeyStampError.failedToEncodeStamp(error)
    }

    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
      throw PasskeyStampError.invalidJSONString
    }

    return jsonString
  }
}
