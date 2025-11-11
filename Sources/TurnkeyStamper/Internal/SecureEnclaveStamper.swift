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
  ///   - format: Desired signature format. Defaults to `.der`.
  /// - Returns: ECDSA signature as a hex string in the requested format.
  static func sign(
    payload: String,
    publicKeyHex: String,
    format: Stamper.SignatureFormat = .der
  ) throws -> String {
    guard let payloadData = payload.data(using: .utf8) else {
      throw SecureEnclaveStamperError.payloadEncodingFailed
    }
    let manager = try EnclaveManager(publicKeyHex: publicKeyHex, label: label)
    let derSignature = try manager.sign(message: payloadData, algorithm: .ecdsaSignatureDigestX962SHA256)
    switch format {
    case .der:
      return derSignature.toHexString()
    case .raw:
      let raw = try derToRawRS(derSignature)
      return raw.toHexString()
    }
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

// MARK: - DER helpers
private extension SecureEnclaveStamper {
  /// Convert an ASN.1 DER-encoded ECDSA signature into raw 64-byte R||S.
  static func derToRawRS(_ der: Data) throws -> Data {
    // Basic ASN.1 parsing for: SEQUENCE { INTEGER r, INTEGER s }
    var idx = 0
    func readByte() throws -> UInt8 {
      guard idx < der.count else { throw SecureEnclaveStamperError.unsupportedAlgorithm }
      let b = der[idx]
      idx += 1
      return b
    }
    func readLength() throws -> Int {
      let first = try readByte()
      if first & 0x80 == 0 {
        return Int(first)
      }
      let count = Int(first & 0x7f)
      guard count > 0, idx + count <= der.count else { throw SecureEnclaveStamperError.unsupportedAlgorithm }
      var value = 0
      for _ in 0..<count {
        value = (value << 8) | Int(try readByte())
      }
      return value
    }
    func readBytes(_ len: Int) throws -> Data {
      guard len >= 0, idx + len <= der.count else { throw SecureEnclaveStamperError.unsupportedAlgorithm }
      let out = der.subdata(in: idx..<(idx + len))
      idx += len
      return out
    }
    func normalizeTo32(_ integer: Data) throws -> Data {
      var i = integer
      // Strip leading zero padding
      while i.count > 0 && i.first == 0x00 {
        i.removeFirst()
      }
      guard i.count <= 32 else { throw SecureEnclaveStamperError.unsupportedAlgorithm }
      if i.count < 32 {
        return Data(repeating: 0, count: 32 - i.count) + i
      }
      return i
    }
    // Sequence
    guard try readByte() == 0x30 else { throw SecureEnclaveStamperError.unsupportedAlgorithm }
    _ = try readLength()
    // R
    guard try readByte() == 0x02 else { throw SecureEnclaveStamperError.unsupportedAlgorithm }
    let rLen = try readLength()
    let r = try normalizeTo32(try readBytes(rLen))
    // S
    guard try readByte() == 0x02 else { throw SecureEnclaveStamperError.unsupportedAlgorithm }
    let sLen = try readLength()
    let s = try normalizeTo32(try readBytes(sLen))
    return r + s
  }
}
