import Foundation
import TurnkeyStamper

/// Tracks generated but unused public keys along with their expiration timestamps.
/// This is used to clean up stale key material that was never used to establish a session.
enum PendingKeysStore {
    private static let storeKey = Constants.Storage.pendingKeysStoreKey
    private static let q = DispatchQueue(label: "pendingKeys", attributes: .concurrent)
    
    static func add(_ pub: String, ttlHours: Double = 1) throws {
        try q.sync(flags: .barrier) {
            var dict = (try? LocalStore.get(storeKey) as [String: TimeInterval]?) ?? [:]
            let expiry = Date().addingTimeInterval(ttlHours * 3600).timeIntervalSince1970
            dict[pub] = expiry
            try LocalStore.set(dict, for: storeKey)
        }
    }
    
    static func remove(_ pub: String) throws {
        try q.sync(flags: .barrier) {
            var dict = (try? LocalStore.get(storeKey) as [String: TimeInterval]?) ?? [:]
            dict.removeValue(forKey: pub)
            try LocalStore.set(dict, for: storeKey)
        }
    }
    
    static func all() -> [String: TimeInterval] {
        q.sync { (try? LocalStore.get(storeKey) as [String: TimeInterval]?) ?? [:] }
    }
    
    static func purge() {
        let now = Date().timeIntervalSince1970
        for (pub, expiry) in all() where expiry < now {
            do {
                try Stamper.deleteOnDeviceKeyPair(publicKeyHex: pub)
                try remove(pub)
            } catch {
                print("PendingKeysStore purge error for \(pub): \(error)")
            }
        }
    }
}
