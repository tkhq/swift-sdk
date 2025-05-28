import Foundation

/// Tracks keys generated but not yet associated with a JWT.
enum PendingKeysStore {
  private static let storeKey = "com.turnkey.sdk.pendingList"  // [publicKeyHex : Date]
  private static let q = DispatchQueue(label: "pendingKeys", attributes: .concurrent)

  // Add newly generated public key
  static func add(_ pub: String) {
    q.async(flags: .barrier) {
      var dict = (LocalStore.get(storeKey) as [String: Date]?) ?? [:]
      dict[pub] = Date()
      try? LocalStore.set(dict, for: storeKey)
    }
  }

  // Remove once a JWT session is established
  static func remove(_ pub: String) {
    q.async(flags: .barrier) {
      var dict = (LocalStore.get(storeKey) as [String: Date]?) ?? [:]
      dict.removeValue(forKey: pub)
      try? LocalStore.set(dict, for: storeKey)
    }
  }

  // Read‑only snapshot
  static func all() -> [String: Date] {
    q.sync { (LocalStore.get(storeKey) as [String: Date]?) ?? [:] }
  }

  /// Purge keys older than `ttlHours` that still have no JWT.
  static func purge(ttlHours: Double = 24, secureAccount: String) {
    let cutoff = Date().addingTimeInterval(-ttlHours * 3600)
    for (pub, createdAt) in all() where createdAt < cutoff {
      SecureStore.delete(service: pub, account: secureAccount)
      remove(pub)
    }
  }
}
