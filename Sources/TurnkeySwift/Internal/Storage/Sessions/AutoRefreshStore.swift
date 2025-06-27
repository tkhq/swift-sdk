import Foundation

/// Stores the auto-refresh duration (in seconds) for each session key.
/// Used to drive automatic session refreshes before JWT expiry.
enum AutoRefreshStore {
    private static let storeKey = Constants.Storage.autoRefreshStoreKey
    private static let q = DispatchQueue(label: "autoRefreshStore", attributes: .concurrent)
    
    static func set(durationSeconds: String, for sessionKey: String) throws {
        try q.sync(flags: .barrier) {
            var dict = (try? LocalStore.get(storeKey) as [String: String]?) ?? [:]
            dict[sessionKey] = durationSeconds
            try LocalStore.set(dict, for: storeKey)
        }
    }
    
    static func remove(for sessionKey: String) throws {
        try q.sync(flags: .barrier) {
            var dict = (try? LocalStore.get(storeKey) as [String: String]?) ?? [:]
            dict.removeValue(forKey: sessionKey)
            try LocalStore.set(dict, for: storeKey)
        }
    }
    
    static func durationSeconds(for sessionKey: String) -> String? {
        q.sync {
            let dict = (try? LocalStore.get(storeKey) as [String: String]?) ?? [:]
            return dict[sessionKey]
        }
    }
}
