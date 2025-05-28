import Foundation
import Security

enum SecureStore {
  enum ItemClass { case genericPassword, key }

  static func set(
    _ data: Data,
    service: String,
    account: String,
    accessible: CFString = kSecAttrAccessibleAfterFirstUnlock,
    itemClass: ItemClass = .genericPassword
  ) throws {
    let query: [String: Any] = [
      kSecClass as String: keyClass(itemClass),
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(query as CFDictionary)  // upsert
    var attrs = query
    attrs[kSecValueData as String] = data
    attrs[kSecAttrAccessible as String] = accessible
    let s = SecItemAdd(attrs as CFDictionary, nil)
    guard s == errSecSuccess else { throw SessionStoreError.keychainAddFailed(status: s) }
  }

  /// Fetch one item, return `Data?`
  static func get(
    service: String,
    account: String,
    itemClass: ItemClass = .genericPassword
  ) -> Data? {
    let q: [String: Any] = [
      kSecClass as String: keyClass(itemClass),
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var out: CFTypeRef?
    let s = SecItemCopyMatching(q as CFDictionary, &out)
    guard s == errSecSuccess else { return nil }
    return out as? Data
  }

  /// Remove (ignore if missing)
  static func delete(
    service: String,
    account: String,
    itemClass: ItemClass = .genericPassword
  ) {
    let q: [String: Any] = [
      kSecClass as String: keyClass(itemClass),
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(q as CFDictionary)
  }

  private static func keyClass(_ c: ItemClass) -> CFString {
    switch c {
    case .genericPassword: return kSecClassGenericPassword
    case .key: return kSecClassKey
    }
  }
}
