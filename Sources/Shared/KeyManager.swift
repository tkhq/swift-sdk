import CryptoKit
import Foundation
import BigNumber
import Base58Check

public class KeyManager {
  private let keyTag = "com.turnkey.emailAuth"
  private var privateKey: P256.KeyAgreement.PrivateKey?
  private let  base58Check: Base58CheckCoding = Base58Check()

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
//      guard let decodedEncryptedBundle = Base58.decodeCheck(encryptedBundle) else {
//        throw NSError(
//          domain: "KeyManager", code: 0,
//          userInfo: [
//            NSLocalizedDescriptionKey: "Failed to decode base58 encoded encrypted bundle"
//          ])
//      }
     let decodedEncryptedBundle = try base58Check.decode(string: encryptedBundle)

        print(
          " decodedEncryptedBundle \( decodedEncryptedBundle.map{ String(format: "%02x", $0) }.joined() )"
        )
      let compressedEncapsulatedKey = decodedEncryptedBundle.prefix(33)
      let encryptedCredential = decodedEncryptedBundle.dropFirst(33)
        
        guard compressedEncapsulatedKey.count == 33 else {
                throw NSError(domain: "KeyManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid compressed key length"])
            }

        print(
          " compressedEncapsulatedKey \( compressedEncapsulatedKey.map{ String(format: "%02x", $0) }.joined() )"
        )
      let uncompressedEncapedKey = try P256.KeyAgreement.PublicKey(compressedRepresentation: compressedEncapsulatedKey)
      guard let privateKey = privateKey else {
        throw NSError(
          domain: "KeyManager", code: 0,
          userInfo: [NSLocalizedDescriptionKey: "No private key available"])
      }
    
        
        var stringKey = Data([0x04])
        let rawRepresentation = uncompressedEncapedKey.rawRepresentation
        stringKey.append(rawRepresentation)
        
        print("targetPublicKey", stringKey.map{ String(format: "%02x", $0) }.joined())

      let ciphersuite = HPKE.Ciphersuite(
        kem: HPKE.KEM.P256_HKDF_SHA256, kdf: HPKE.KDF.HKDF_SHA256, aead: HPKE.AEAD.AES_GCM_256)

      // Create an HPKE recipient instance
      var recipient = try HPKE.Recipient(
        privateKey: privateKey,
        ciphersuite: ciphersuite,
        info: "turnkey_hpke".data(using: .utf8)!,
        encapsulatedKey: Data(stringKey)
      )

      let decryptedCredential = try recipient.open(encryptedCredential)

      if let decryptedString = String(data: decryptedCredential, encoding: .utf8) {
        print("Decrypted credential: \(decryptedString)")
      } else {
        print("Failed to convert decrypted credential to string")
      }

      return decryptedCredential
    } catch let error as NSError {
      print("Error decrypting bundle: \(error.localizedDescription)")
      throw error
    }
  }
    
   
    
  // Assuming we have the `compressedEncapsulatedKey` available
//  func convertToUncompressed(compressedEncapsulatedKey: Data) throws -> Data {
//    // Check if the compressed key has valid length
//    guard compressedEncapsulatedKey.count == 33 else {
//      throw NSError(
//        domain: "KeyManager", code: 0,
//        userInfo: [NSLocalizedDescriptionKey: "Invalid compressed key length"])
//    }
//
//    // Extract the prefix and X coordinate
//    let prefix = compressedEncapsulatedKey[0]
//    let xCoordinate = compressedEncapsulatedKey.dropFirst()
//
//    // Determine the Y coordinate based on the X coordinate
//    let ecGroup = try ECGroup(curve: .prime256v1)  // P-256 is usually prime256v1
//
//    guard let point = ecGroup.reconstructPoint(from: xCoordinate, yIsEven: prefix == 0x02) else {
//      throw NSError(
//        domain: "KeyManager", code: 0,
//        userInfo: [NSLocalizedDescriptionKey: "Failed to reconstruct point"])
//    }
//
//    // Convert to uncompressed form (04 + X + Y)
//    let uncompressedKeyData = Data([0x04]) + point.xData + point.yData
//
//    return uncompressedKeyData
//  }
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
              decodedBytes.count > 4 else {
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
