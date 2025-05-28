import Foundation

enum SelectedSessionStore {
  private static let key = "com.turnkey.sdk.selectedSessionKey"

  static func set(_ sessionKey: String) {
    try? LocalStore.set(sessionKey, for: key)
  }

  static func get() -> String? { LocalStore.get(key) }

  static func clear() { LocalStore.delete(key) }
}
