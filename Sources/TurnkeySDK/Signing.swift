import CryptoKit
import Foundation

func signWithApiKey(content: String, publicKey: String, privateKey: String) async throws -> String {
    guard let privateKey = try? P256.Signing.PrivateKey(pemRepresentation: privateKey) else {
        throw SigningError.invalidPrivateKey
    }
    
    let derivedPublicKey = privateKey.publicKey.pemRepresentation 
    
    if privateKey.publicKey.pemRepresentation != publicKey {
        throw SigningError.mismatchedPublicKey(expected: publicKey, actual: derivedPublicKey)
    }
    
    let contentData = Data(content.utf8)
    let signature = try privateKey.signature(for: contentData)
    let derSignature = try signature.derRepresentation.hexString
    
    return derSignature
}

enum SigningError: Error {
    case invalidPrivateKey
    case mismatchedPublicKey(expected: String, actual: String)
}

extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

func decodeHex(_ hex: String) throws -> Data {
    guard hex.count % 2 == 0 else {
        throw DecodingError.oddLengthString
    }
    
    var data = Data()
    var bytePair = ""
    
    for char in hex {
        bytePair += String(char)
        if bytePair.count == 2 {
            guard let byte = UInt8(bytePair, radix: 16) else {
                throw DecodingError.invalidHexCharacter
            }
            data.append(byte)
            bytePair = ""
        }
    }
    
    return data
}

enum DecodingError: Error {
    case oddLengthString
    case invalidHexCharacter
}