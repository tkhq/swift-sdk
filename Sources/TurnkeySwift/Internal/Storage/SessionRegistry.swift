// Storage/SessionRegistry.swift
import Foundation

/// Index of all stored session-key strings.
enum SessionRegistry {
  private static let key = "com.turnkey.sdk.sessionKeys"  // [String]
  private static let q = DispatchQueue(label: "sessionKeys", attributes: .concurrent)

  // MARK: add / remove
  static func add(_ sessionKey: String) {
    q.async(flags: .barrier) {
      var list = (LocalStore.get(key) as [String]?) ?? []
      if !list.contains(sessionKey) { list.append(sessionKey) }
      try? LocalStore.set(list, for: key)
    }
  }

  static func remove(_ sessionKey: String) {
    q.async(flags: .barrier) {
      var list = (LocalStore.get(key) as [String]?) ?? []
      list.removeAll { $0 == sessionKey }
      try? LocalStore.set(list, for: key)
    }
  }

  // MARK: read
  static func all() -> [String] { q.sync { (LocalStore.get(key) as [String]?) ?? [] } }

  // MARK: purge
  /// Drop any session whose JWT payload is missing or whose `exp` is in the past.
  static func purgeExpiredSessions(secureAccount: String) {
    for sessionKey in all() {
      guard let sess = JWTSessionStore.load(key: sessionKey) else {
        // JSON missing / corrupt → remove index entry
        remove(sessionKey)
        continue
      }
      if Date(timeIntervalSince1970: sess.exp) <= Date() {
        JWTSessionStore.delete(key: sessionKey)
        KeyPairStore.delete(for: sess.publicKey)
        remove(sessionKey)
      }
    }
  }
}
