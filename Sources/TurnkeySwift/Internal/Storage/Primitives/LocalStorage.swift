import Foundation

enum LocalStore {
  private static let ud = UserDefaults.standard

  static func set<T: Codable>(_ value: T, for key: String) throws {
    do {
      let blob = try JSONEncoder().encode(value)
      ud.set(blob, forKey: key)
    } catch {
      throw StorageError.encodingFailed(key: key, underlying: error)
    }
  }

  static func get<T: Codable>(_ key: String) throws -> T? {
    guard let blob = ud.data(forKey: key) else { return nil }
    do {
      return try JSONDecoder().decode(T.self, from: blob)
    } catch {
      throw StorageError.decodingFailed(key: key, underlying: error)
    }
  }

  static func delete(_ key: String) {
    ud.removeObject(forKey: key)
  }
}
