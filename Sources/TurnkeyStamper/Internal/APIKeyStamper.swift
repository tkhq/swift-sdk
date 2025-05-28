import CryptoKit
import Foundation
import TurnkeyEncoding

enum APIKeyStamper {
  static func stamp(
    payload: SHA256Digest,
    publicKeyHex: String,
    privateKeyHex: String
  ) throws -> String {
    guard let privateKeyData = Data(hexString: privateKeyHex) else {
      throw APIKeyStampError.invalidHexCharacter
    }

    guard let privateKey = try? P256.Signing.PrivateKey(rawRepresentation: privateKeyData) else {
      throw APIKeyStampError.invalidPrivateKey
    }

    // Optionally verify pubkey matches expected
    let derivedPublicKey = privateKey.publicKey.compressedRepresentation.toHexString()
    // if derivedPublicKey != publicKeyHex {
    //   throw APIKeyStampError.mismatchedPublicKey(expected: publicKeyHex, actual: derivedPublicKey)
    // }

    guard let signature = try? privateKey.signature(for: payload) else {
      throw APIKeyStampError.signatureFailed
    }

    let signatureHex = signature.derRepresentation.toHexString()
    let stamp: [String: Any] = [
      "publicKey": publicKeyHex,
      "scheme": "SIGNATURE_SCHEME_TK_API_P256",
      "signature": signatureHex,
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: stamp, options: [])
    return jsonData.base64URLEncodedString()
  }
}
