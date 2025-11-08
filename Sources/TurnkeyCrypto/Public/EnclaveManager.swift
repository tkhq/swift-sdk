import CryptoKit
import Foundation
import CoreFoundation
import Security

public final class EnclaveManager {

  public enum EnclaveManagerError: Error {
    case secureEnclaveUnavailable
    case keyGenerationFailed(Error?)
    case unsupportedAlgorithm
    case keyNotFound(String)
    case keychainError(OSStatus)
    case payloadEncodingFailed
  }

  public enum AuthPolicy {
    case none
    case userPresence
    case biometryAny
    case biometryCurrentSet
  }

  public struct KeyPair: Sendable {
    public let publicKeyHex: String
    public init(publicKeyHex: String) {
      self.publicKeyHex = publicKeyHex
    }
  }

  // MARK: - Constants

  public static let defaultLabel = "TurnkeyEnclaveManager"

  // MARK: - Instance

  public let keyPair: KeyPair
  private let privateKey: SecKey

  /// Creates and stores a new Secure Enclave P-256 keypair with the given auth policy.
  /// The compressed public key (hex) is exposed via `keyPair`.
  /// - Parameters:
  ///   - authPolicy: Access control policy for the keypair.
  ///   - label: Keychain label domain used to scope storage and queries. Defaults to `TurnkeyEnclaveManager`.
  public init(authPolicy: AuthPolicy = .none, label: String = EnclaveManager.defaultLabel) {
    // Best-effort non-throwing initializer per public API. Fatal if generation fails.
    do {
      let pair = try EnclaveManager.createKeyPair(authPolicy: authPolicy, label: label)
      self.keyPair = pair
      // Fetch the SecKey reference for the generated key by public key hex.
      guard let priv = try EnclaveManager.findPrivateKey(publicKeyHex: pair.publicKeyHex, label: label) else {
        fatalError("EnclaveManager: generated key not found immediately after creation.")
      }
      self.privateKey = priv
    } catch {
      fatalError("EnclaveManager init failed: \(error)")
    }
  }

  /// Binds to an existing keypair identified by its compressed public key hex.
  /// - Parameters:
  ///   - publicKeyHex: Compressed public key hex.
  ///   - label: Keychain label domain used to scope lookup fallback. Defaults to `TurnkeyEnclaveManager`.
  public init(publicKeyHex: String, label: String = EnclaveManager.defaultLabel) throws {
    guard let key = try EnclaveManager.findPrivateKey(publicKeyHex: publicKeyHex, label: label) else {
      throw EnclaveManagerError.keyNotFound(publicKeyHex)
    }
    self.privateKey = key
    self.keyPair = KeyPair(publicKeyHex: publicKeyHex)
  }

  /// Signs the provided message using the instance's Secure Enclave private key.
  ///
  /// - Parameters:
  ///   - message: Arbitrary message bytes.
  ///   - algorithm: The SecKeyAlgorithm to use. Defaults to `.ecdsaSignatureDigestX962SHA256`.
  ///                If `.ecdsaSignatureDigestX962SHA256`, the function hashes `message` with SHA-256 first.
  ///                If `.ecdsaSignatureMessageX962SHA256`, the raw message is provided to SecKey.
  /// - Returns: DER-encoded ECDSA signature as Data.
  public func sign(
    message: Data,
    algorithm: SecKeyAlgorithm = .ecdsaSignatureDigestX962SHA256
  ) throws -> Data {
    guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
      throw EnclaveManagerError.unsupportedAlgorithm
    }

    let inputData: Data
    switch algorithm {
    case .ecdsaSignatureDigestX962SHA256:
      inputData = Data(SHA256.hash(data: message))
    case .ecdsaSignatureMessageX962SHA256:
      inputData = message
    default:
      // Only the above algorithms are supported by this API surface today.
      throw EnclaveManagerError.unsupportedAlgorithm
    }

    var signError: Unmanaged<CFError>?
    guard
      let signature = SecKeyCreateSignature(
        privateKey,
        algorithm,
        inputData as CFData,
        &signError
      ) as Data?
    else {
      throw EnclaveManagerError.keyGenerationFailed(signError?.takeRetainedValue())
    }
    return signature
  }

  /// Deletes the instance's Secure Enclave keypair from the Keychain.
  public func deleteKeyPair() throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecValueRef as String: privateKey,
    ]
    let status = SecItemDelete(query as CFDictionary)
    if status == errSecItemNotFound || status == errSecSuccess {
      return
    }
    throw EnclaveManagerError.keychainError(status)
  }

  // MARK: - Static utilities

  /// Indicates whether Secure Enclave is available and usable on this device.
  public static func isSecureEnclaveAvailable() -> Bool {
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

  /// Generates and stores a new Secure Enclave keypair and returns its public key.
  /// - Parameters:
  ///   - authPolicy: Access control policy for the keypair.
  ///   - label: Keychain label domain used to scope storage and queries. Defaults to `TurnkeyEnclaveManager`.
  public static func createKeyPair(authPolicy: AuthPolicy = .none, label: String = EnclaveManager.defaultLabel) throws -> KeyPair {
    guard isSecureEnclaveAvailable() else {
      throw EnclaveManagerError.secureEnclaveUnavailable
    }

    let flags = accessControlFlags(for: authPolicy)
    var acError: Unmanaged<CFError>?
    guard let access = SecAccessControlCreateWithFlags(
      kCFAllocatorDefault,
      kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
      flags,
      &acError
    ) else {
      throw EnclaveManagerError.keyGenerationFailed(acError?.takeRetainedValue())
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
      throw EnclaveManagerError.keyGenerationFailed(error?.takeRetainedValue())
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

    return KeyPair(publicKeyHex: publicKeyHex)
  }

  /// Lists Secure Enclave keypairs for the specified label domain.
  /// - Parameter label: Keychain label domain used to scope query. Defaults to `TurnkeyEnclaveManager`.
  public static func listKeyPairs(label: String = EnclaveManager.defaultLabel) throws -> [KeyPair] {
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
      throw EnclaveManagerError.keychainError(status)
    }

    var keys: [SecKey] = []
    if let array = result as? [SecKey] {
      keys = array
    } else if let r = result, CFGetTypeID(r) == SecKeyGetTypeID() {
      keys = [r as! SecKey]
    }

    var pairs: [KeyPair] = []
    pairs.reserveCapacity(keys.count)
    for priv in keys {
      if let hex = try? TurnkeyCrypto.getPublicKey(fromPrivateKey: priv) {
        pairs.append(KeyPair(publicKeyHex: hex))
      }
    }
    return pairs
  }

  /// Deletes a specific Secure Enclave keypair (by compressed public key hex).
  /// - Parameters:
  ///   - publicKeyHex: Compressed public key hex.
  ///   - label: Keychain label domain used to scope lookup fallback. Defaults to `TurnkeyEnclaveManager`.
  public static func deleteKeyPair(publicKeyHex: String, label: String = EnclaveManager.defaultLabel) throws {
    if let key = try findPrivateKey(publicKeyHex: publicKeyHex, label: label) {
      let query: [String: Any] = [
        kSecClass as String: kSecClassKey,
        kSecValueRef as String: key,
      ]
      let status = SecItemDelete(query as CFDictionary)
      if status == errSecItemNotFound || status == errSecSuccess {
        return
      }
      throw EnclaveManagerError.keychainError(status)
    } else {
      // Treat as success if not found
      return
    }
  }

  // MARK: - Private helpers

  private static func accessControlFlags(for policy: AuthPolicy)
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

  private static func findPrivateKey(publicKeyHex: String, label: String) throws -> SecKey? {
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
      throw EnclaveManagerError.keychainError(status)
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


