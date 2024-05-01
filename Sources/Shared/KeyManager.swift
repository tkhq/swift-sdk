import Base58Check
import BigNumber
import CryptoKit
import Foundation

public class KeyManager {
  private let keyTag = "com.turnkey.emailAuth"
  private var privateKey: P256.KeyAgreement.PrivateKey?
  private let base58Check: Base58CheckCoding = Base58Check()

  public init() {}

  public func createKeyPair() throws -> P256.KeyAgreement.PublicKey {
    // Step 1: Generate a new private key
    privateKey = P256.KeyAgreement.PrivateKey()

    // Get the corresponding public key
    guard let publicKey = privateKey?.publicKey else {
      throw NSError(
        domain: "KeyManager", code: 0,
        userInfo: [NSLocalizedDescriptionKey: "Failed to generate public key"])
    }

    print("publicKey \(publicKey)")
    return publicKey
  }

  @available(iOS 17.0, *)
  public func decryptBundle(_ encryptedBundle: String) throws -> Data {
    do {
      let decodedEncryptedBundle = try base58Check.decode(string: encryptedBundle)
      print("decodedEncryptedBundle length", decodedEncryptedBundle.count)
      let compressedEncapsulatedKey = decodedEncryptedBundle.prefix(33)
      let encryptedPrivateKey = decodedEncryptedBundle.dropFirst(33)

      guard compressedEncapsulatedKey.count == 33 else {
        throw NSError(
          domain: "KeyManager", code: 0,
          userInfo: [NSLocalizedDescriptionKey: "Invalid compressed key length"])
      }

      let uncompressedEncapsulatedKey = try P256.KeyAgreement.PublicKey(
        compressedRepresentation: compressedEncapsulatedKey
      ).x963Representation

      guard let recieverPrivateKey = privateKey else {
        throw NSError(
          domain: "KeyManager", code: 0,
          userInfo: [NSLocalizedDescriptionKey: "No private key available"])
      }

      guard let recieverPublicKey = privateKey?.publicKey.x963Representation else {
        throw NSError(
          domain: "KeyManager", code: 0,
          userInfo: [NSLocalizedDescriptionKey: "Could not derive reciever public key"])
      }

      print(
        "recieverPublicKey", recieverPublicKey.map { String(format: "%02x", $0) }.joined(),
        "uncompressedEncapsulatedKey",
        uncompressedEncapsulatedKey.map { String(format: "%02x", $0) }.joined())

      let ciphersuite = HPKE.Ciphersuite(
        kem: HPKE.KEM.P256_HKDF_SHA256, kdf: HPKE.KDF.HKDF_SHA256, aead: HPKE.AEAD.AES_GCM_256)

      // Create an HPKE recipient instance
      var recipient = try HPKE.Recipient(
        privateKey: recieverPrivateKey,
        ciphersuite: ciphersuite,
        info: "turnkey_hpke".data(using: .utf8)!,
        encapsulatedKey: uncompressedEncapsulatedKey
      )

      let aad = uncompressedEncapsulatedKey + recieverPublicKey

      let decryptedPrivateKey = try recipient.open(encryptedPrivateKey, authenticating: aad)

      return decryptedPrivateKey.map { String(format: "%02x", $0) }.joined()
    } catch let error as NSError {
      print("Error decrypting bundle: \(error.localizedDescription)")
      throw error
    }
  }
}

class Base58 {
  static let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
  static let base = BInt(58)

  static func decode(_ input: String) -> [UInt8]? {
    var bigNumber = BInt(0)
    var bytes: [UInt8] = []

    for char in input {
      guard let index = alphabet.firstIndex(of: char) else {
        return nil
      }
      bigNumber = bigNumber * base + BInt(alphabet.distance(from: alphabet.startIndex, to: index))
    }

    while bigNumber > 0 {
      bytes.append(UInt8(bigNumber & 0xff))
      bigNumber >>= 8
    }

    return bytes.reversed()
  }

  static func decodeCheck(_ input: String) -> [UInt8]? {
    guard let decodedBytes = decode(input),
      decodedBytes.count > 4
    else {
      return nil
    }

    let checksum = decodedBytes.suffix(4)
    let payload = decodedBytes.dropLast(4)

    // Hash the payload
    let hash1 = Array(SHA256.hash(data: Data(payload)))
    let hash2 = Array(SHA256.hash(data: Data(hash1)))

    // Compare the checksum
    if Array(hash2.prefix(4)) == Array(checksum) {
      return Array(payload)
    } else {
      return nil
    }
  }
}
