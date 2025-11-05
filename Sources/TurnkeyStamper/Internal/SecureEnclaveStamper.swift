import CryptoKit
import Foundation
import CoreFoundation
import Security
import TurnkeyEncoding
import TurnkeyCrypto


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
    return isSecureEnclaveAvailable()
  }

  static func listKeyPairs() throws -> [String] {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
      kSecAttrLabel as String: label,
      kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
      kSecReturnRef as String: true,
      kSecMatchLimit as String: kSecMatchLimitAll,
    ]

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
      return []
    }
    guard status == errSecSuccess else {
      throw SecureEnclaveStamperError.keychainError(status)
    }

    var keys: [SecKey] = []
    if let array = result as? [SecKey] {
      keys = array
    } else if let r = result, CFGetTypeID(r) == SecKeyGetTypeID() {
      keys = [r as! SecKey]
    }

    var publicKeys: [String] = []
    publicKeys.reserveCapacity(keys.count)
    for priv in keys {
      if let hex = try? TurnkeyCrypto.getPublicKey(fromPrivateKey: priv) {
        publicKeys.append(hex)
      }
    }
    return publicKeys
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
    guard isSecureEnclaveAvailable() else {
      throw SecureEnclaveStamperError.secureEnclaveUnavailable
    }
    let accessControlFlags = accessControlFlags(for: config.authPolicy)
    var acError: Unmanaged<CFError>?
    guard let access = SecAccessControlCreateWithFlags(
      kCFAllocatorDefault,
      kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
      accessControlFlags,
      &acError
    ) else {
      throw SecureEnclaveStamperError.keyGenerationFailed(acError?.takeRetainedValue())
    }

    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256,
      kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
      kSecAttrLabel as String: label,
      kSecAttrIsPermanent as String: true,
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrAccessControl as String: access,
      ],
    ]

    var error: Unmanaged<CFError>?
    guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
      throw SecureEnclaveStamperError.keyGenerationFailed(error?.takeRetainedValue())
    }

    // Derive compressed public key hex for return and indexing.
    let publicKeyHex = try TurnkeyCrypto.getPublicKey(fromPrivateKey: privateKey)

    // Best-effort: set applicationTag to the compressed public key hex for faster lookups later.
    if let tagData = publicKeyHex.data(using: .utf8) {
      let query: [String: Any] = [
        kSecClass as String: kSecClassKey,
        kSecValueRef as String: privateKey,
      ]
      let update: [String: Any] = [
        kSecAttrApplicationTag as String: tagData,
      ]
      let setTagStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
      if setTagStatus != errSecSuccess && setTagStatus != errSecItemNotFound {
        // Non-fatal; continue.
      }
    }

    return publicKeyHex
  }

  static func deleteKeyPair(publicKeyHex: String) throws {
    if let key = try findPrivateKey(publicKeyHex: publicKeyHex) {
      let query: [String: Any] = [
        kSecClass as String: kSecClassKey,
        kSecValueRef as String: key,
      ]
      let status = SecItemDelete(query as CFDictionary)
      if status == errSecItemNotFound || status == errSecSuccess {
        return
      }
      throw SecureEnclaveStamperError.keychainError(status)
    } else {
      // Treat as success if not found (parity with storage stamper behavior)
      return
    }
  }

  static func stamp(
    payload: String,
    publicKeyHex: String
  ) throws -> String {
    guard let payloadData = payload.data(using: .utf8) else {
      throw SecureEnclaveStamperError.payloadEncodingFailed
    }
    let digest = SHA256.hash(data: payloadData)

    guard let privateKey = try findPrivateKey(publicKeyHex: publicKeyHex) else {
      throw SecureEnclaveStamperError.keyNotFound(publicKeyHex: publicKeyHex)
    }

    let algorithm: SecKeyAlgorithm = .ecdsaSignatureDigestX962SHA256
    guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
      throw SecureEnclaveStamperError.unsupportedAlgorithm
    }

    var signError: Unmanaged<CFError>?
    let signature = SecKeyCreateSignature(
      privateKey,
      algorithm,
      Data(digest) as CFData,
      &signError
    )

    guard let sig = signature as Data? else {
      throw SecureEnclaveStamperError.keyGenerationFailed(signError?.takeRetainedValue())
    }

    let signatureHex = sig.toHexString()
    let stamp: [String: Any] = [
      "publicKey": publicKeyHex,
      "scheme": "SIGNATURE_SCHEME_TK_API_P256",
      "signature": signatureHex,
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: stamp, options: [])
    return jsonData.base64URLEncodedString()
  }

  // MARK: - Helpers

  private static func isSecureEnclaveAvailable() -> Bool {
    // Try generating and immediately deleting a no-prompt key.
    let flags = accessControlFlags(for: .none)
    var acError: Unmanaged<CFError>?
    guard let access = SecAccessControlCreateWithFlags(
      kCFAllocatorDefault,
      kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
      flags,
      &acError
    ) else {
      return false
    }

    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256,
      kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
      kSecAttrLabel as String: "TurnkeySESupportProbe",
      kSecAttrIsPermanent as String: true,
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrAccessControl as String: access,
      ],
    ]

    var err: Unmanaged<CFError>?
    guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &err) else {
      return false
    }
    // Cleanup: delete the probe key.
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecValueRef as String: key,
    ]
    _ = SecItemDelete(query as CFDictionary)
    return true
  }

  private static func accessControlFlags(for policy: SecureEnclaveConfig.AuthPolicy)
    -> SecAccessControlCreateFlags
  {
    switch policy {
    case .none:
      return [.privateKeyUsage]
    case .userPresence:
      return [.privateKeyUsage, .userPresence]
    case .biometryAny:
      return [.privateKeyUsage, .biometryAny]
    case .biometryCurrentSet:
      return [.privateKeyUsage, .biometryCurrentSet]
    }
  }

  

  private static func findPrivateKey(publicKeyHex: String) throws -> SecKey? {
    // First, try by application tag if we were able to set it.
    if let tag = publicKeyHex.data(using: .utf8) {
      let tagQuery: [String: Any] = [
        kSecClass as String: kSecClassKey,
        kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
        kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
        kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
        kSecAttrApplicationTag as String: tag,
        kSecReturnRef as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
      ]

      var tagResult: CFTypeRef?
      let tagStatus = SecItemCopyMatching(tagQuery as CFDictionary, &tagResult)
      if tagStatus == errSecSuccess, let r = tagResult, CFGetTypeID(r) == SecKeyGetTypeID() {
        // Safe: Type ID check confirms this is a SecKey
        return (r as! SecKey)
      }
    }

    // Fallback: scan keys with our label and match by derived compressed public key hex.
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
      kSecAttrLabel as String: label,
      kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
      kSecReturnRef as String: true,
      kSecMatchLimit as String: kSecMatchLimitAll,
    ]

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess else {
      throw SecureEnclaveStamperError.keychainError(status)
    }

    if let keys = result as? [SecKey] {
      for priv in keys {
        if let hex = try? TurnkeyCrypto.getPublicKey(fromPrivateKey: priv), hex == publicKeyHex {
          return priv
        }
      }
    } else if let r = result, CFGetTypeID(r) == SecKeyGetTypeID() {
      let single = r as! SecKey
      if let hex = try? TurnkeyCrypto.getPublicKey(fromPrivateKey: single), hex == publicKeyHex {
        return single
      }
    }
    return nil
  }
}


