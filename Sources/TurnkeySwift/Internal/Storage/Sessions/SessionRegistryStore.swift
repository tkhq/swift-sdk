import Foundation
import TurnkeyStamper

/// Stores a list of all active session keys.
/// Used to track and manage multiple JWT-backed sessions, and to purge expired ones.
enum SessionRegistryStore: CollectionStore {
    
    private static let storeKey = Constants.Storage.sessionRegistryKey
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
            let selectedSessionKey = try? SelectedSessionStore.load()

            for sessionKey in sessionKeys {
                if let stored = try JwtSessionStore.load(key: sessionKey) {
                    if Date(timeIntervalSince1970: stored.decoded.exp) <= Date() {
                        JwtSessionStore.delete(key: sessionKey)
                        try AutoRefreshStore.remove(for: sessionKey)
                        try Stamper.deleteOnDeviceKeyPair(publicKeyHex: stored.decoded.publicKey)
                        try remove(sessionKey)
                        
                        // if we just removed the selected session we clear the SelectedSessionStore
                        if sessionKey == selectedSessionKey {
                            SelectedSessionStore.delete()
                        }
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
