import Foundation
import Security
import LocalAuthentication
import TurnkeyCrypto

/// A Keychain-backed manager that stores private keys in the iOS Keychain as Generic Password entries with:
/// - service = public key (hex, compressed)
/// - account = "TurnkeySecureStorageStamper"
/// - label = "TurnkeyApiKeyPair"
///
/// Note:
/// Keychain queries must match how items were stored (e.g., access group, iCloud synchronizable,
/// and whether access control requiring user presence/biometry was applied). If you store with
/// non-default attributes or an access control policy, use the config-based overloads of
/// APIs to ensure lookups and auth UI behave as intended.
public final class SecureStorageManager {
  private static let account = "TurnkeySecureStorageStamper"
  private static let label = "TurnkeyApiKeyPair"

  // MARK: - Listing

  public static func listKeyPairs() throws -> [String] {
    return try listKeyPairs(config: nil)
  }

  public static func listKeyPairs(config: Config?) throws -> [String] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrLabel as String: label,
      kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
      kSecReturnAttributes as String: true,
      kSecMatchLimit as String: kSecMatchLimitAll,
    ]
    if let group = config?.accessGroup {
      query[kSecAttrAccessGroup as String] = group
    }

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
      return []
    }
    guard status == errSecSuccess else {
      throw SecureStorageManagerError.keychainError(status)
    }

    guard let items = result as? [[String: Any]] else { return [] }

    var services: [String] = []
    services.reserveCapacity(items.count)
    for attributes in items {
      if let publicKey = attributes[kSecAttrService as String] as? String {
        services.append(publicKey)
      }
    }
    return services
  }

  // MARK: - Create / Import / Delete

  public static func createKeyPair() throws -> String {
    return try createKeyPair(config: Config())
  }

  public static func createKeyPair(config: Config) throws -> String {
    let keyPair = TurnkeyCrypto.generateP256KeyPair()
    let privateKeyHex = keyPair.privateKey
    let publicKeyHex = keyPair.publicKeyCompressed
    try savePrivateKey(privateKeyHex, for: publicKeyHex, config: config)
    return publicKeyHex
  }

  public static func importKeyPair(
    externalKeyPair: (publicKey: String, privateKey: String)
  ) throws -> String {
    try savePrivateKey(externalKeyPair.privateKey, for: externalKeyPair.publicKey, config: Config())
    return externalKeyPair.publicKey
  }

  public static func importKeyPair(
    externalKeyPair: (publicKey: String, privateKey: String),
    config: Config
  ) throws -> String {
    try savePrivateKey(externalKeyPair.privateKey, for: externalKeyPair.publicKey, config: config)
    return externalKeyPair.publicKey
  }

  public static func deleteKeyPair(publicKeyHex: String) throws {
    try deleteKeyPair(publicKeyHex: publicKeyHex, config: nil)
  }

  public static func deleteKeyPair(publicKeyHex: String, config: Config?) throws {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: publicKeyHex,
      kSecAttrAccount as String: account,
    ]
    if let group = config?.accessGroup {
      query[kSecAttrAccessGroup as String] = group
    }

    let status = SecItemDelete(query as CFDictionary)
    if status == errSecItemNotFound || status == errSecSuccess {
      return
    }
    throw SecureStorageManagerError.keychainError(status)
  }

  // MARK: - Access

  public static func getPrivateKey(publicKeyHex: String) throws -> String? {
    return try getPrivateKey(publicKeyHex: publicKeyHex, config: nil)
  }

  public static func getPrivateKey(publicKeyHex: String, config: Config?) throws -> String? {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: publicKeyHex,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    // Include both local and iCloud items unless the store requires strict match
    query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
    if let cfg = config, let group = cfg.accessGroup {
      query[kSecAttrAccessGroup as String] = group
    }

    if let cfg = config {
      let c = LAContext()
      if #available(iOS 13.0, *) {
        let maxAllowed = Int(LATouchIDAuthenticationMaximumAllowableReuseDuration)
        let seconds = max(0, min(maxAllowed, cfg.biometryReuseWindowSeconds))
        c.touchIDAuthenticationAllowableReuseDuration = TimeInterval(seconds)
      }
      if let prompt = cfg.authPrompt { c.localizedReason = prompt }
      query[kSecUseAuthenticationContext as String] = c
    }

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess else {
      throw SecureStorageManagerError.keychainError(status)
    }
    guard let data = result as? Data, let privateKeyHex = String(data: data, encoding: .utf8) else {
      throw SecureStorageManagerError.stringEncodingFailed
    }
    return privateKeyHex
  }

  // MARK: - Internals

  private static func savePrivateKey(
    _ privateKeyHex: String,
    for publicKeyHex: String,
    config: Config
  ) throws {
    guard let valueData = privateKeyHex.data(using: .utf8) else {
      throw SecureStorageManagerError.stringEncodingFailed
    }

    // Try add
    var attributes: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: publicKeyHex,
      kSecAttrAccount as String: account,
      kSecAttrLabel as String: label,
      kSecValueData as String: valueData,
    ]

    // Set protection policy
    if let access = makeAccessControl(from: config) {
      attributes[kSecAttrAccessControl as String] = access
    } else {
      attributes[kSecAttrAccessible as String] = accessibilityConstant(config.accessibility)
    }

    // Sync / group
    attributes[kSecAttrSynchronizable as String] = config.synchronizable
    if let group = config.accessGroup {
      attributes[kSecAttrAccessGroup as String] = group
    }

    var status = SecItemAdd(attributes as CFDictionary, nil)

    // If duplicate, update the value
    if status == errSecDuplicateItem {
      var query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: publicKeyHex,
        kSecAttrAccount as String: account,
      ]
      if let group = config.accessGroup {
        query[kSecAttrAccessGroup as String] = group
      }
      let update: [String: Any] = [kSecValueData as String: valueData]
      status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
    }

    guard status == errSecSuccess else {
      throw SecureStorageManagerError.keychainError(status)
    }
  }
}


