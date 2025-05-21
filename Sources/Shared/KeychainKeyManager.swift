//  KeychainKeyManager.swift
//  Software-keychain implementation of the `KeyManager` protocol.
//
//  Unlike `SecureEnclaveKeyManager`, this manager stores P-256 keys in the
//  *application Keychain* only—no Secure Enclave / hardware-backing required.
//  This makes it usable on the iOS simulator, macOS tests, and devices that
//  lack a Secure Enclave. Because the private key bits exist in software they
//  are inherently less protected, but still benefit from the Keychain’s file
//  system encryption and data-protection classes.
//
//  Typical usage:
//  ```swift
//  let keyManager = KeychainKeyManager()
//  let tag = try keyManager.createKeypair()
//  let pub = try keyManager.publicKey(tag: tag)          // ANSI X9.63 bytes
//  let sig = try keyManager.sign(tag: tag, data: message)
//  ```
//
//  The generated tag (e.g. "com.turnkey.sdk.keychain.<UUID>") serves as the
//  *primary key* to look the SecKey up later. It is safe to persist this tag
//  alongside your `Session` object.
//
//  - Important: *Security trade-off*
//    Keys produced by this manager can be exported (because the bits live in
//    the keychain database). If your threat-model requires hardware isolation
//    you should use `SecureEnclaveKeyManager` instead.
//

import Foundation
import Security

public enum KeychainKeyManagerError: Error {
  case keyGenerationFailed(Error)
  case keyRetrievalFailed(OSStatus)
  case publicKeyExtractionFailed
  case externalRepresentationFailed
  case keyNotFound
  case signingNotSupported
}

/// Manages P-256 keys stored in the regular Keychain (software-backed).
public struct KeychainKeyManager: KeyManager {

  public init() {}

  // MARK: Key generation

  /// Generates a new software-backed **P-256** key-pair and stores the private
  /// key permanently in the application Keychain.
  ///
  /// The key is created with the following SecKey attributes:
  /// * `kSecAttrKeyType` = `ECSECPrimeRandom`
  /// * `kSecAttrKeySizeInBits` = 256
  /// * `kSecAttrIsPermanent` = `true`
  ///
  /// The absence of `kSecAttrTokenIDSecureEnclave` means the key material is
  /// software-extractable (though still encrypted at rest by the Keychain).
  ///
  /// Persist the returned **tag** alongside your `Session` so that you can
  /// later retrieve the key for signing or public-key export.
  ///
  /// - Returns: A unique tag string of the form
  ///   `"com.turnkey.sdk.keychain.<UUID>"`.
  /// - Throws: `KeychainKeyManagerError.keyGenerationFailed` when
  ///   `SecKeyCreateRandomKey` fails (rare, e.g. out-of-memory).
  public func createKeypair() throws -> String {
    let tag = "com.turnkey.sdk.keychain.\(UUID().uuidString)"
    guard let tagData = tag.data(using: .utf8) else {
      throw KeychainKeyManagerError.keyGenerationFailed(NSError(domain: "TagEncoding", code: -1))
    }

    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256,
      // Notice: NO kSecAttrTokenIDSecureEnclave => software key.
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: tagData,
      ],
    ]

    var error: Unmanaged<CFError>?
    guard SecKeyCreateRandomKey(attributes as CFDictionary, &error) != nil else {
      throw KeychainKeyManagerError.keyGenerationFailed(error!.takeRetainedValue() as Error)
    }
    return tag
  }

  // MARK: Public key retrieval

  /// Returns the ANSI X9.63 (uncompressed) public-key bytes for the key
  /// identified by `tag`.
  ///
  /// Call this when you need to register the public key with Turnkey or embed
  /// it in a JWT/verifiable credential.
  ///
  /// - Parameter tag: The application-tag obtained from `createKeypair()`.
  /// - Returns: Raw 65-byte public key (`0x04 | X | Y`).
  /// - Throws:
  ///   - `keyRetrievalFailed` if the key cannot be found.
  ///   - `publicKeyExtractionFailed` if the key lacks a public component.
  ///   - `externalRepresentationFailed` if the system cannot export it.
  public func publicKey(tag: String) throws -> Data {
    guard let tagData = tag.data(using: .utf8) else {
      throw KeychainKeyManagerError.keyRetrievalFailed(errSecParam)
    }

    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrApplicationTag as String: tagData,
      kSecReturnRef as String: true,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let item = item else {
      throw KeychainKeyManagerError.keyRetrievalFailed(status)
    }
    let privKey = item as! SecKey
    guard let pubKey = SecKeyCopyPublicKey(privKey) else {
      throw KeychainKeyManagerError.publicKeyExtractionFailed
    }
    var error: Unmanaged<CFError>?
    guard let ext = SecKeyCopyExternalRepresentation(pubKey, &error) as Data? else {
      throw KeychainKeyManagerError.externalRepresentationFailed
    }
    return ext
  }

  // MARK: Sign

  /// Signs arbitrary data with the private key referenced by `tag`.
  ///
  /// The signature algorithm is **ECDSA-P256 with SHA-256** and the returned
  /// value is in **raw X9.62** format (`r || s`, 64 bytes).
  ///
  /// - Parameters:
  ///   - tag: Application-tag identifying the key.
  ///   - data: Message bytes to sign. Hash the data yourself beforehand if you
  ///     need a deterministic digest (mirroring `SessionManager.signRequest`).
  /// - Returns: The signature bytes.
  /// - Throws: `KeychainKeyManagerError` variants when the key is missing or
  ///   the cryptographic operation fails.
  public func sign(tag: String, data: Data) throws -> Data {
    guard let tagData = tag.data(using: .utf8) else {
      throw KeychainKeyManagerError.keyGenerationFailed(NSError(domain: "InvalidTag", code: -1))
    }
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: tagData,
      kSecReturnRef as String: true,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let item = item else {
      throw KeychainKeyManagerError.keyNotFound
    }
    let privateKey = item as! SecKey

    // Use ECDSA P-256 SHA-256
    let algorithm: SecKeyAlgorithm = .ecdsaSignatureMessageX962SHA256
    guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
      throw KeychainKeyManagerError.signingNotSupported
    }
    var error: Unmanaged<CFError>?
    guard
      let signature = SecKeyCreateSignature(privateKey, algorithm, data as CFData, &error) as Data?
    else {
      throw error!.takeRetainedValue() as Error
    }
    return signature
  }

  /// Exports *both* the private-key bits **and** the public key
  /// for the key referenced by `tag`.
  ///
  /// - Parameter tag: Application-tag of the key.
  /// - Returns: Tuple `(publicKey: Data, privateKey: Data)` both in ANSI X9.63
  ///   representation (private key is a 32-byte big-endian integer for P-256).
  /// - Throws: `KeychainKeyManagerError` when the key cannot be found or the
  ///           system refuses to export it (e.g. due to ACL restrictions).
  public func keypair(tag: String) throws -> (publicKey: Data, privateKey: Data) {
    guard let tagData = tag.data(using: .utf8) else {
      throw KeychainKeyManagerError.keyRetrievalFailed(errSecParam)
    }
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrApplicationTag as String: tagData,
      kSecReturnRef as String: true,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let item = item else {
      throw KeychainKeyManagerError.keyRetrievalFailed(status)
    }
    let privKey = item as! SecKey
    guard let pubKey = SecKeyCopyPublicKey(privKey) else {
      throw KeychainKeyManagerError.publicKeyExtractionFailed
    }

    var error: Unmanaged<CFError>?
    guard let privData = SecKeyCopyExternalRepresentation(privKey, &error) as Data? else {
      throw KeychainKeyManagerError.externalRepresentationFailed
    }
    error = nil
    guard let pubData = SecKeyCopyExternalRepresentation(pubKey, &error) as Data? else {
      throw KeychainKeyManagerError.externalRepresentationFailed
    }
    return (publicKey: pubData, privateKey: privData)
  }
}
