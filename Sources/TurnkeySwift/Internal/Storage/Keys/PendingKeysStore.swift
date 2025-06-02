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

  static func purge(ttlHours: Double = 24) {
    let cutoff = Date().addingTimeInterval(-ttlHours * 3600)
    for (pub, createdAt) in all() where createdAt < cutoff {
      do {
        try SecureStore.delete(service: pub, account: secureAccount)
        try remove(pub)
      } catch {
        print("PendingKeysStore purge error for \(pub): \(error)")
      }
    }
  }
}
