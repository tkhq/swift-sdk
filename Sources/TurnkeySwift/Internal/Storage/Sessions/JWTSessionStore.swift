import Foundation

/// Stores and retrieves decoded Turnkey session JWTs  by session key
/// Used to persist session metadata such as organization ID, user ID, and public key
/// so that sessions can be restored or reused across app launches.
enum JwtSessionStore: KeyValueStore {
  static func save(_ value: TurnkeySession, key: String) throws {
    try LocalStore.set(value, for: key)
  }

  static func load(key: String) throws -> TurnkeySession? {
    try LocalStore.get(key)
  }

  static func delete(key: String) {
    LocalStore.delete(key)
  }
}
