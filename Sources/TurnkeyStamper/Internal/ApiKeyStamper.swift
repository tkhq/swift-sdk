import CryptoKit
import Foundation
import TurnkeyEncoding

enum ApiKeyStamper {

  /// Signs a SHA-256 digest using a P-256 private key and returns the DER-encoded signature as hex.
  ///
  /// - Parameters:
  ///   - payload: The SHA-256 digest of the request payload to sign.
  ///   - privateKeyHex: The private key in hex format used for signing.
  /// - Returns: DER-encoded ECDSA signature as a hex string.
  /// - Throws: `ApiKeyStampError` if the key data is invalid or signing fails.
  static func sign(
    payload: SHA256Digest,
    privateKeyHex: String
  ) throws -> String {
    guard let privateKeyData = Data(hexString: privateKeyHex) else {
      throw ApiKeyStampError.invalidHexCharacter
    }
    guard let privateKey = try? P256.Signing.PrivateKey(rawRepresentation: privateKeyData) else {
      throw ApiKeyStampError.invalidPrivateKey
    }
    guard let signature = try? privateKey.signature(for: payload) else {
      throw ApiKeyStampError.signatureFailed
    }
    return signature.derRepresentation.toHexString()
  }

  /// Signs a SHA-256 digest using a P-256 private key and returns a base64url-encoded JSON stamp.
  ///
  /// - Parameters:
  ///   - payload: The SHA-256 digest of the request payload to sign.
  ///   - publicKeyHex: The expected public key in hex format for verification.
  ///   - privateKeyHex: The private key in hex format used for signing.
  /// - Returns: A base64url-encoded JSON string containing the public key, signature scheme, and signature.
  /// - Throws: `ApiKeyStampError` if the key data is invalid, keys don't match, or signing fails.

  static func stamp(
    payload: SHA256Digest,
    publicKeyHex: String,
    privateKeyHex: String
  ) throws -> String {
    guard let privateKeyData = Data(hexString: privateKeyHex) else {
      throw ApiKeyStampError.invalidHexCharacter
    }
    guard let privateKey = try? P256.Signing.PrivateKey(rawRepresentation: privateKeyData) else {
      throw ApiKeyStampError.invalidPrivateKey
    }
    // we verify that the derived public key matches the expected one
    let derivedPublicKey = privateKey.publicKey.compressedRepresentation.toHexString()
    if derivedPublicKey != publicKeyHex {
      throw ApiKeyStampError.mismatchedPublicKey(expected: publicKeyHex, actual: derivedPublicKey)
    }

    let signatureHex = try sign(payload: payload, privateKeyHex: privateKeyHex)
    let stamp: [String: Any] = [
      "publicKey": publicKeyHex,
      "scheme": "SIGNATURE_SCHEME_TK_API_P256",
      "signature": signatureHex,
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: stamp, options: [])
    return jsonData.base64URLEncodedString()
  }
}
