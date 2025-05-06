//
//  SecureEnclaveKeyManager.swift
//  Handles creation, retrieval, and signing with Secure-Enclave-resident P-256 keys.
//  NOTE: Initial stub for Step-0; logic will be filled in subsequent steps.
//

import CryptoKit
import Foundation
import Security

public enum SecureEnclaveKeyManagerError: Error {
  case keyGenerationFailed(Error)
  case keyRetrievalFailed(OSStatus)
  case publicKeyExtractionFailed
  case externalRepresentationFailed
  case keyNotFound
  case signingNotSupported
}

/// Manages P-256 keys stored in the device’s Secure Enclave (HSM/TPM).
public struct SecureEnclaveKeyManager {

  public init() {}

  /// Generates and stores a new Secure-Enclave P-256 signing key, returning the persistent tag.
  public func createKeypair() throws -> String {
    let tag = "com.turnkey.sdk.enclave.\(UUID().uuidString)"
    guard let tagData = tag.data(using: .utf8) else {
      throw SecureEnclaveKeyManagerError.keyGenerationFailed(
        NSError(domain: "TagEncoding", code: -1))
    }

    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256,
      kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: tagData,
      ],
    ]

    var error: Unmanaged<CFError>?
    guard SecKeyCreateRandomKey(attributes as CFDictionary, &error) != nil else {
      throw SecureEnclaveKeyManagerError.keyGenerationFailed(error!.takeRetainedValue() as Error)
    }
    return tag
  }

  /// Retrieves the public key (ANSI X9.63 representation) for a stored key.
  public func publicKey(tag: String) throws -> Data {
    guard let tagData = tag.data(using: .utf8) else {
      throw SecureEnclaveKeyManagerError.keyRetrievalFailed(errSecParam)
    }
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrApplicationTag as String: tagData,
      kSecReturnRef as String: true,
    ]
    // Retrieve the SecKey reference as a CFTypeRef
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let item = item else {
      throw SecureEnclaveKeyManagerError.keyRetrievalFailed(status)
    }
    // Force-cast the CFTypeRef to SecKey (guaranteed by SecItemCopyMatching)
    let privKey = item as! SecKey
    guard let pubKey = SecKeyCopyPublicKey(privKey) else {
      throw SecureEnclaveKeyManagerError.publicKeyExtractionFailed
    }
    var error: Unmanaged<CFError>?
    guard let ext = SecKeyCopyExternalRepresentation(pubKey, &error) as Data? else {
      throw SecureEnclaveKeyManagerError.externalRepresentationFailed
    }
    return ext
  }

  /// Signs arbitrary data with the Secure-Enclave private key identified by `tag`.
  public func sign(tag: String, data: Data) throws -> Data {
    // Convert tag to Data
    guard let tagData = tag.data(using: .utf8) else {
      throw SecureEnclaveKeyManagerError.keyGenerationFailed(
        NSError(domain: "InvalidTag", code: -1))
    }

    // Query the keychain for the private key with the given tag
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: tagData,
      kSecReturnRef as String: true,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let item = item else {
      throw SecureEnclaveKeyManagerError.keyNotFound
    }

    // Force-cast to SecKey since kSecReturnRef always returns a SecKey
    let privateKey = item as! SecKey

    // Determine the appropriate algorithm based on key type
    let attributes = SecKeyCopyAttributes(privateKey) as? [String: Any]
    let keyType = attributes?[kSecAttrKeyType as String] as? String
    let algorithm: SecKeyAlgorithm
    if keyType == (kSecAttrKeyTypeRSA as String) {
      algorithm = .rsaSignatureMessagePKCS1v15SHA256
    } else {
      algorithm = .ecdsaSignatureMessageX962SHA256
    }

    // Check if the algorithm is supported
    guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
      throw SecureEnclaveKeyManagerError.signingNotSupported
    }

    // Create signature
    var error: Unmanaged<CFError>?
    guard
      let signature = SecKeyCreateSignature(privateKey, algorithm, data as CFData, &error) as Data?
    else {
      throw error!.takeRetainedValue() as Error
    }
    return signature
  }
}
