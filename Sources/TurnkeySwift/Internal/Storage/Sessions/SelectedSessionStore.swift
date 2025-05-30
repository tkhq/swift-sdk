import Foundation

/// Stores and retrieves the session key of the currently selected session.
/// This allows the app to remember which session was active across app launches.
enum SelectedSessionStore: KeyValueStore {
  private static let storeKey = Constants.Storage.selectedSessionKey

  static func save(_ value: String, key: String = storeKey) throws {
    try LocalStore.set(value, for: key)
  }

  static func load(key: String = storeKey) throws -> String? {
    try LocalStore.get(key)
  }

  static func delete(key: String = storeKey) {
    LocalStore.delete(key)
  }
}
