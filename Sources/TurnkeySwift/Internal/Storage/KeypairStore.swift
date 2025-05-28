import Foundation

enum KeyPairStore {
  private static let account = "p256-private"

  static func save(privateHex: String, for publicHex: String) throws {
    try SecureStore.set(
      Data(privateHex.utf8),
      service: publicHex,
      account: account)
  }

  static func getPrivateHex(for publicHex: String) -> String? {
    SecureStore.get(service: publicHex, account: account)
      .flatMap { String(data: $0, encoding: .utf8) }
  }

  static func delete(for publicHex: String) {
    SecureStore.delete(service: publicHex, account: account)
  }
}
