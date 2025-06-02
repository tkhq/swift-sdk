import Foundation

/// Stores a list of all active session keys.
/// Used to track and manage multiple JWT-backed sessions, and to purge expired ones.
enum SessionRegistryStore: CollectionStore {
    
    private static let storeKey = Constants.Storage.sessionRegistryKey
    private static let secureAccount = Constants.Storage.secureAccount
    private static let q = DispatchQueue(label: "sessionKeys", attributes: .concurrent)
    
    static func add(_ sessionKey: String) throws {
        try q.sync(flags: .barrier) {
            var list: [String] = try LocalStore.get(storeKey) ?? []
            guard !list.contains(sessionKey) else { return }
            list.append(sessionKey)
            try LocalStore.set(list, for: storeKey)
        }
    }
    
    static func remove(_ sessionKey: String) throws {
        try q.sync(flags: .barrier) {
            var list: [String] = try LocalStore.get(storeKey) ?? []
            list.removeAll { $0 == sessionKey }
            try LocalStore.set(list, for: storeKey)
        }
    }
    
    static func all() throws -> [String] {
        try q.sync {
            try LocalStore.get(storeKey) ?? []
        }
    }
    
    static func purgeExpiredSessions() {
        do {
            let sessionKeys = try all()
            for sessionKey in sessionKeys {
                if let sess = try JwtSessionStore.load(key: sessionKey) {
                    if Date(timeIntervalSince1970: sess.exp) <= Date() {
                        JwtSessionStore.delete(key: sessionKey)
                        try KeyPairStore.delete(for: sess.publicKey)
                        try remove(sessionKey)
                    }
                } else {
                    try remove(sessionKey)
                }
            }
        } catch {
            print("purgeExpiredSessions error: \(error)")
        }
    }
}
