import CryptoKit
import Foundation
import Security
import LocalAuthentication
import TurnkeyEncoding
import TurnkeyCrypto

/// A Keychain-backed stamper that stores private keys in the iOS Keychain as Generic Password entries with:
/// - service = public key (hex, compressed)
/// - account = "TurnkeySecureStorageStamper"
/// - label = "TurnkeyApiKeyPair"
///
/// Note:
/// Keychain queries must match how items were stored (e.g., access group, iCloud synchronizable,
/// and whether access control requiring user presence/biometry was applied). If you store with
/// non-default attributes or an access control policy, use the config-based overloads of
/// `listKeyPairs`, `clearKeyPairs`, `deleteKeyPair`, and `stamp` to ensure lookups and auth UI
/// behave as intended. If you use the defaults, the no-config methods are sufficient.
enum SecureStorageStamper {
  private static let account = "TurnkeySecureStorageStamper"
  private static let label = "TurnkeyApiKeyPair"

  /// Configuration for how keys are stored and accessed from the Keychain.
  ///
  /// Defaults:
  /// - `accessibility`: `.afterFirstUnlockThisDeviceOnly` (available after first unlock, not migrated)
  /// - `accessControlPolicy`: `.none` (no per-access user prompt)
  /// - `authPrompt`: `nil` (system default prompt if needed)
  /// - `biometryReuseWindowSeconds`: `0` (no reuse window)
  /// - `synchronizable`: `false` (do not sync via iCloud Keychain)
  /// - `accessGroup`: `nil` (no shared access group)
  struct SecureStorageConfig: Sendable {
    enum Accessibility {
      case whenUnlockedThisDeviceOnly
      case afterFirstUnlockThisDeviceOnly
      case whenPasscodeSetThisDeviceOnly
    }

    enum AccessControlPolicy {
      case none
      case userPresence
      case biometryAny
      case biometryCurrentSet
      case devicePasscode
    }

    let accessibility: Accessibility
    let accessControlPolicy: AccessControlPolicy
    let authPrompt: String?
    let biometryReuseWindowSeconds: Int
    let synchronizable: Bool
    let accessGroup: String?

    init(
      accessibility: Accessibility = .afterFirstUnlockThisDeviceOnly,
      accessControlPolicy: AccessControlPolicy = .none,
      authPrompt: String? = nil,
      biometryReuseWindowSeconds: Int = 0,
      synchronizable: Bool = false,
      accessGroup: String? = nil
    ) {
      self.accessibility = accessibility
      self.accessControlPolicy = accessControlPolicy
      self.authPrompt = authPrompt
      self.biometryReuseWindowSeconds = biometryReuseWindowSeconds
      self.synchronizable = synchronizable
      self.accessGroup = accessGroup
    }
  }

  // MARK: - Public API

  static func listKeyPairs() throws -> [String] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrLabel as String: label,
      kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
      kSecReturnAttributes as String: true,
      kSecMatchLimit as String: kSecMatchLimitAll,
    ]

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
      return []
    }
    guard status == errSecSuccess else {
      throw SecureStorageStamperError.keychainError(status)
    }

    guard let items = result as? [[String: Any]] else {
      return []
    }

    var services: [String] = []
    services.reserveCapacity(items.count)
    for attributes in items {
      if let publicKey = attributes[kSecAttrService as String] as? String {
        services.append(publicKey)
      }
    }
    return services
  }

  /// List stored public keys using the provided config to scope lookups (e.g., access group,
  /// iCloud Keychain). Use when you stored with non-default attributes.
  static func listKeyPairs(config: SecureStorageConfig) throws -> [String] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrLabel as String: label,
      kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
      kSecReturnAttributes as String: true,
      kSecMatchLimit as String: kSecMatchLimitAll,
    ]
    if let group = config.accessGroup {
      query[kSecAttrAccessGroup as String] = group
    }

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
      return []
    }
    guard status == errSecSuccess else {
      throw SecureStorageStamperError.keychainError(status)
    }

    guard let items = result as? [[String: Any]] else {
      return []
    }

    var services: [String] = []
    services.reserveCapacity(items.count)
    for attributes in items {
      if let publicKey = attributes[kSecAttrService as String] as? String {
        services.append(publicKey)
      }
    }
    return services
  }

  static func clearKeyPairs() throws {
    for publicKey in try listKeyPairs() {
      try deleteKeyPair(publicKeyHex: publicKey)
    }
  }

  /// Clear stored keys using the provided config to target the correct domain (e.g., access group,
  /// iCloud Keychain). Use when you stored with non-default attributes.
  static func clearKeyPairs(config: SecureStorageConfig) throws {
    for publicKey in try listKeyPairs(config: config) {
      try deleteKeyPair(publicKeyHex: publicKey, config: config)
    }
  }

  static func createKeyPair(
    externalKeyPair: (publicKey: String, privateKey: String)? = nil
  ) throws -> String {
    let privateKeyHex: String
    let publicKeyHex: String

    if let provided = externalKeyPair {
      privateKeyHex = provided.privateKey
      publicKeyHex = provided.publicKey
    } else {
      let keyPair = TurnkeyCrypto.generateP256KeyPair()
      privateKeyHex = keyPair.privateKey
      publicKeyHex = keyPair.publicKeyCompressed
    }

    try savePrivateKey(privateKeyHex, for: publicKeyHex, config: SecureStorageConfig())
    return publicKeyHex
  }

  static func createKeyPair(config: SecureStorageConfig) throws -> String {
    let keyPair = TurnkeyCrypto.generateP256KeyPair()
    let privateKeyHex = keyPair.privateKey
    let publicKeyHex = keyPair.publicKeyCompressed
    try savePrivateKey(privateKeyHex, for: publicKeyHex, config: config)
    return publicKeyHex
  }

  static func createKeyPair(
    externalKeyPair: (publicKey: String, privateKey: String),
    config: SecureStorageConfig
  ) throws -> String {
    try savePrivateKey(externalKeyPair.privateKey, for: externalKeyPair.publicKey, config: config)
    return externalKeyPair.publicKey
  }

  static func deleteKeyPair(publicKeyHex: String) throws {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: publicKeyHex,
      kSecAttrAccount as String: account,
    ]

    let status = SecItemDelete(query as CFDictionary)
    if status == errSecItemNotFound || status == errSecSuccess {
      return
    }
    throw SecureStorageStamperError.keychainError(status)
  }

  /// Delete a specific key using the provided config to match how it was stored (e.g., access group,
  /// iCloud Keychain). Use when you stored with non-default attributes.
  /// Note: Does not throw if the key isn't found (treat as success).
  static func deleteKeyPair(publicKeyHex: String, config: SecureStorageConfig) throws {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: publicKeyHex,
      kSecAttrAccount as String: account,
    ]
    if let group = config.accessGroup {
      query[kSecAttrAccessGroup as String] = group
    }

    let status = SecItemDelete(query as CFDictionary)
    
    if status == errSecItemNotFound || status == errSecSuccess {
      return
    }
    throw SecureStorageStamperError.keychainError(status)
  }

  static func stamp(
    payload: String,
    publicKeyHex: String
  ) throws -> String {
    guard let payloadData = payload.data(using: .utf8) else {
      throw SecureStorageStamperError.payloadEncodingFailed
    }
    let digest = SHA256.hash(data: payloadData)

    guard let privateKeyHex = try getPrivateKey(publicKeyHex: publicKeyHex, config: nil) else {
      throw SecureStorageStamperError.privateKeyNotFound(publicKeyHex: publicKeyHex)
    }

    let stamp = try ApiKeyStamper.stamp(
      payload: digest,
      publicKeyHex: publicKeyHex,
      privateKeyHex: privateKeyHex
    )
    return stamp
  }

  /// Generate a stamp while honoring access control and scoping (e.g., access group, iCloud). If the
  /// key was saved with an access control policy, supply `authPrompt` and optionally a reuse window
  /// via `config` so the system can present authentication UI.
  static func stamp(
    payload: String,
    publicKeyHex: String,
    config: SecureStorageConfig
  ) throws -> String {
    guard let payloadData = payload.data(using: .utf8) else {
      throw SecureStorageStamperError.payloadEncodingFailed
    }
    let digest = SHA256.hash(data: payloadData)

    guard let privateKeyHex = try getPrivateKey(publicKeyHex: publicKeyHex, config: config) else {
      throw SecureStorageStamperError.privateKeyNotFound(publicKeyHex: publicKeyHex)
    }

    let stamp = try ApiKeyStamper.stamp(
      payload: digest,
      publicKeyHex: publicKeyHex,
      privateKeyHex: privateKeyHex
    )
    return stamp
  }

  // MARK: - Keychain helpers

  private static func savePrivateKey(
    _ privateKeyHex: String,
    for publicKeyHex: String,
    config: SecureStorageConfig
  ) throws {
    guard let valueData = privateKeyHex.data(using: .utf8) else {
      throw SecureStorageStamperError.stringEncodingFailed
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
      throw SecureStorageStamperError.keychainError(status)
    }
  }

  private static func getPrivateKey(publicKeyHex: String, config: SecureStorageConfig?) throws -> String? {
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

    var ctx: LAContext?
    if let cfg = config {
      let c = LAContext()
      if #available(iOS 13.0, *) {
        let seconds = max(0, min(10, cfg.biometryReuseWindowSeconds))
        c.touchIDAuthenticationAllowableReuseDuration = TimeInterval(seconds)
      }
      if let prompt = cfg.authPrompt { c.localizedReason = prompt }
      ctx = c
      query[kSecUseAuthenticationContext as String] = c
    }

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess else {
      throw SecureStorageStamperError.keychainError(status)
    }
    guard let data = result as? Data, let privateKeyHex = String(data: data, encoding: .utf8) else {
      throw SecureStorageStamperError.stringEncodingFailed
    }
    return privateKeyHex
  }

  private static func accessibilityConstant(_ a: SecureStorageConfig.Accessibility) -> CFString {
    switch a {
    case .whenUnlockedThisDeviceOnly:
      return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    case .afterFirstUnlockThisDeviceOnly:
      return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    case .whenPasscodeSetThisDeviceOnly:
      return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
    }
  }

  private static func makeAccessControl(from config: SecureStorageConfig) -> SecAccessControl? {
    guard config.accessControlPolicy != .none else { return nil }
    var flags: SecAccessControlCreateFlags = []
    switch config.accessControlPolicy {
    case .none:
      flags = []
    case .userPresence:
      flags = [.userPresence]
    case .biometryAny:
      flags = [.biometryAny]
    case .biometryCurrentSet:
      flags = [.biometryCurrentSet]
    case .devicePasscode:
      flags = [.devicePasscode]
    }
    var error: Unmanaged<CFError>?
    let access = SecAccessControlCreateWithFlags(
      kCFAllocatorDefault,
      accessibilityConstant(config.accessibility),
      flags,
      &error
    )
    return access
  }
}


