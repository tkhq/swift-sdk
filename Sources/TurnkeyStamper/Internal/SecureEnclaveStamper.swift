import CryptoKit
import Foundation
import CoreFoundation
import Security
import TurnkeyEncoding
import TurnkeyCrypto
import TurnkeyKeyManager


/// A Secure Enclave–backed stamper for generating and using P-256 keys inside the device TEE.
///
/// Keys are generated and stored inside the device Secure Enclave (TEE). The
/// private key never leaves the enclave. Callers can control user-auth policy
/// (e.g., none, user presence, or biometry) at key creation time via
/// `SecureEnclaveConfig`.
///
/// Note: Secure Enclave does not support importing external keys. Keys must be
/// generated inside the enclave.
enum SecureEnclaveStamper: KeyPairStamper {
  typealias Config = SecureEnclaveConfig

  private static let label = "TurnkeyApiKeyPair"

  struct SecureEnclaveConfig: Sendable {
    enum AuthPolicy {
      case none
      case userPresence
      case biometryAny
      case biometryCurrentSet
    }

    let authPolicy: AuthPolicy
    init(authPolicy: AuthPolicy = .none) { self.authPolicy = authPolicy }
  }

  // MARK: - Public API

  /// Indicates whether Secure Enclave is available and usable on this device.
  ///
  /// Uses the same probing logic as key generation to determine support.
  static func isSupported() -> Bool {
    return EnclaveManager.isSecureEnclaveAvailable()
  }

  static func listKeyPairs() throws -> [String] {
    return try EnclaveManager.listKeyPairs(label: label).map { $0.publicKeyHex }
  }

  static func clearKeyPairs() throws {
    for publicKey in try listKeyPairs() {
      try deleteKeyPair(publicKeyHex: publicKey)
    }
  }

  static func createKeyPair() throws -> String {
    return try createKeyPair(config: SecureEnclaveConfig())
  }

  static func createKeyPair(config: SecureEnclaveConfig) throws -> String {
    let mappedPolicy: EnclaveManager.AuthPolicy
    switch config.authPolicy {
    case .none: mappedPolicy = .none
    case .userPresence: mappedPolicy = .userPresence
    case .biometryAny: mappedPolicy = .biometryAny
    case .biometryCurrentSet: mappedPolicy = .biometryCurrentSet
    }
    let pair = try EnclaveManager.createKeyPair(authPolicy: mappedPolicy, label: label)
    return pair.publicKeyHex
  }

  static func deleteKeyPair(publicKeyHex: String) throws {
    try EnclaveManager.deleteKeyPair(publicKeyHex: publicKeyHex, label: label)
  }

  /// Sign an arbitrary payload with the Secure Enclave private key associated with `publicKeyHex`.
  ///
  /// - Parameters:
  ///   - payload: Raw string payload to sign.
  ///   - publicKeyHex: Compressed public key hex identifying the Secure Enclave key.
  /// - Returns: DER-encoded ECDSA signature as a hex string.
  static func sign(
    payload: String,
    publicKeyHex: String
  ) throws -> String {
    guard let payloadData = payload.data(using: .utf8) else {
      throw SecureEnclaveStamperError.payloadEncodingFailed
    }
    let manager = try EnclaveManager(publicKeyHex: publicKeyHex, label: label)
    let signature = try manager.sign(message: payloadData, algorithm: .ecdsaSignatureDigestX962SHA256)
    return signature.toHexString()
  }

  static func stamp(
    payload: String,
    publicKeyHex: String
  ) throws -> String {
    let signatureHex = try sign(payload: payload, publicKeyHex: publicKeyHex)
    let stamp: [String: Any] = [
      "publicKey": publicKeyHex,
      "scheme": "SIGNATURE_SCHEME_TK_API_P256",
      "signature": signatureHex,
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: stamp, options: [])
    return jsonData.base64URLEncodedString()
  }
}


