import Foundation

enum JWTSessionStore {
  static func save(_ session: TurnkeySession, key: String) throws {
    try LocalStore.set(session, for: key)
  }

  static func load(key: String) -> TurnkeySession? { LocalStore.get(key) }

  static func delete(key: String) { LocalStore.delete(key) }
}
