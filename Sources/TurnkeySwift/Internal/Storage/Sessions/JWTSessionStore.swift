import Foundation

/// Internal storage structure for session data including both decoded JWT and raw token
struct StoredSession: Codable {
    let decoded: TurnkeySession
    let jwt: String
}

/// Stores and retrieves decoded Turnkey session JWTs  by session key
/// Used to persist session metadata such as organization ID, user ID, and public key
/// so that sessions can be restored or reused across app launches.
enum JwtSessionStore: KeyValueStore {
  typealias Value = StoredSession
  
  static func save(_ value: StoredSession, key: String) throws {
    try LocalStore.set(value, for: key)
  }

  static func load(key: String) throws -> StoredSession? {
    try LocalStore.get(key)
  }

  static func delete(key: String) {
    LocalStore.delete(key)
  }
}
