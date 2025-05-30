import Foundation

/// Stores private key material in the device's secure storage.
/// Keys are indexed by their public key hex string and used for signing authenticated Turnkey requests.
enum KeyPairStore {
  private static let secureAccount = Constants.Storage.secureAccount

  static func save(privateHex: String, for publicHex: String) throws {
    try SecureStore.set(Data(privateHex.utf8), service: publicHex, account: secureAccount)
  }

  static func getPrivateHex(for publicHex: String) throws -> String {
    guard let data = try SecureStore.get(service: publicHex, account: secureAccount),
      let str = String(data: data, encoding: .utf8)
    else {
      throw TurnkeySwiftError.keyNotFound
    }
    return str
  }

  static func delete(for publicHex: String) throws {
    try SecureStore.delete(service: publicHex, account: secureAccount)
  }
}
