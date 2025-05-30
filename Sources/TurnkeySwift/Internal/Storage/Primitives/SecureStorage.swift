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
    let deleteStatus = SecItemDelete(query as CFDictionary)
    if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
      throw StorageError.keychainDeleteFailed(status: deleteStatus)
    }

    var attrs = query
    attrs[kSecValueData as String] = data
    attrs[kSecAttrAccessible as String] = accessible

    let addStatus = SecItemAdd(attrs as CFDictionary, nil)
    guard addStatus == errSecSuccess else {
      throw StorageError.keychainAddFailed(status: addStatus)
    }
  }

  static func get(
    service: String,
    account: String,
    itemClass: ItemClass = .genericPassword
  ) throws -> Data? {
    let query: [String: Any] = [
      kSecClass as String: keyClass(itemClass),
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var out: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &out)

    if status == errSecItemNotFound {
      return nil
    }

    guard status == errSecSuccess else {
      throw StorageError.keychainFetchFailed(status: status)
    }

    return out as? Data
  }

  static func delete(
    service: String,
    account: String,
    itemClass: ItemClass = .genericPassword
  ) throws {
    let query: [String: Any] = [
      kSecClass as String: keyClass(itemClass),
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    let status = SecItemDelete(query as CFDictionary)
    if status != errSecSuccess && status != errSecItemNotFound {
      throw StorageError.keychainDeleteFailed(status: status)
    }
  }

  private static func keyClass(_ c: ItemClass) -> CFString {
    switch c {
    case .genericPassword: return kSecClassGenericPassword
    case .key: return kSecClassKey
    }
  }
}
