import Foundation

/// Tracks generated but unused public keys along with their creation timestamps.
/// This is used to clean up stale key material that was never used to establish a session.
enum PendingKeysStore {
  private static let storeKey = Constants.Storage.pendingKeysStoreKey
  private static let secureAccount = Constants.Storage.secureAccount
  private static let q = DispatchQueue(label: "pendingKeys", attributes: .concurrent)

  static func add(_ pub: String) throws {
    try q.sync(flags: .barrier) {
      var dict = (try? LocalStore.get(storeKey) as [String: Date]?) ?? [:]
      dict[pub] = Date()
      try LocalStore.set(dict, for: storeKey)
    }
  }

  static func remove(_ pub: String) throws {
    try q.sync(flags: .barrier) {
      var dict = (try? LocalStore.get(storeKey) as [String: Date]?) ?? [:]
      dict.removeValue(forKey: pub)
      try LocalStore.set(dict, for: storeKey)
    }
  }

  static func all() -> [String: Date] {
    q.sync { (try? LocalStore.get(storeKey) as [String: Date]?) ?? [:] }
  }

static func purgeExpiredSessions() {
  do {
    for sessionKey in try all() {
      do {
        guard let sess = try JwtSessionStore.load(key: sessionKey) else {
          try remove(sessionKey)           // dangling index
          continue
        }

        if Date(timeIntervalSince1970: sess.exp) <= Date() {
          JwtSessionStore.delete(key: sessionKey)
          try KeyPairStore.delete(for: sess.publicKey)
          try remove(sessionKey)
        }
      } catch {
        print("SessionRegistry purge error for \(sessionKey): \(error)")
      }
    }
  } catch {
    print("SessionRegistry purge error (enumerating keys): \(error)")
  }
}

}
