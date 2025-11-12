import Foundation
import Security
import TurnkeyCrypto

extension EnclaveManager {
  // MARK: - Private helpers

  static func accessControlFlags(for policy: AuthPolicy)
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

  static func findPrivateKey(publicKeyHex: String, label: String) throws -> SecKey? {
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
      throw EnclaveManager.EnclaveManagerError.keychainError(status)
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


