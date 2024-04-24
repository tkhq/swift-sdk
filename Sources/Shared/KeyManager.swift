import Foundation
import Security

class KeyManager {
    private let keyTag = "com.turnkey.emailAuth"
    
    func createKeyPair() throws -> SecKey {
        let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .privateKeyUsage,
            nil
        )!
        
        let attributes: NSDictionary = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
            kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs: [
                kSecAttrIsPermanent: true,
                kSecAttrApplicationTag: keyTag,
                kSecAttrAccessControl: access
            ]
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw NSError(domain: "KeyManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get public key"])
        }
        
        return publicKey
    }
    
    func decryptBundle(_ encryptedBundle: String) throws -> String {
        guard let cipherText = Data(base64Encoded: encryptedBundle) else {
            throw NSError(domain: "KeyManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert encrypted bundle to Data"])
        }
        
        let query: NSDictionary = [
            kSecClass: kSecClassKey,
            kSecAttrApplicationTag: keyTag,
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query, &item)
        guard status == errSecSuccess else {
            throw NSError(domain: "KeyManager", code: status, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve private key"])
        }
        
        let privateKey = item as! SecKey
        
        let algorithm: SecKeyAlgorithm = .eciesEncryptionCofactorX963SHA256AESGCM
        
        var error: Unmanaged<CFError>?
        guard let clearText = SecKeyCreateDecryptedData(privateKey, algorithm, cipherText as CFData, &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }
        
        guard let decryptedString = String(data: clearText, encoding: .utf8) else {
            throw NSError(domain: "KeyManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert decrypted data to string"])
        }
        
        return decryptedString
    }
}