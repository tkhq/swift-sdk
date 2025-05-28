import Foundation

enum LocalStore {
  private static let ud = UserDefaults.standard

  /// Persist a Codable value.
  static func set<T: Codable>(_ value: T, for key: String) throws {
    let blob = try JSONEncoder().encode(value)
    ud.set(blob, forKey: key)
  }

  /// Retrieve a Codable value or `nil` if not present / corrupted.
  static func get<T: Codable>(_ key: String) -> T? {
    guard let blob = ud.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(T.self, from: blob)
  }

  /// Remove the stored value for `key` (no‑op if absent).
  static func delete(_ key: String) {
    ud.removeObject(forKey: key)
  }
}
