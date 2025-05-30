import Foundation

protocol KeyValueStore {
  associatedtype Value: Codable

  static func save(_ value: Value, key: String) throws
  static func load(key: String) throws -> Value?
  static func delete(key: String)
}

protocol CollectionStore {
  associatedtype Element

  static func add(_ element: Element) throws
  static func remove(_ element: Element) throws
  static func all() throws -> [Element]
}
