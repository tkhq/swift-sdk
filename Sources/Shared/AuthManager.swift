import Base58Check
import BigNumber
import CryptoKit
import Foundation
import LocalAuthentication
import Valet

public enum AuthKeyError: Error {
  case publicKeyGenerationFailed
  case invalidCompressedKeyLength
  case noPrivateKeyAvailable
  case receiverPublicKeyDerivationFailed
  case keyDecryptionFailed(Error)
  case unableToCreateSecKey
  case keyStoreFailure(String)
}

public class AuthKeyManager {
  // MARK: - Private Properties

  /// The prefix used for key storage in the keychain.
  private let pkStorageKeyPrefix = "pk"

  /// The private key used for signing, kept in memory.
  /// This key can be cleared from memory using the `clearPrivateKey()` method
  /// and can be `nil` if caching is disabled.
  private var privateKey: P256.Signing.PrivateKey?

  /// The public key corresponding to `privateKey`.
  private var publicKey: P256.Signing.PublicKey?

  /// An ephemeral private key used during key agreement processes.
  private var ephemeralPrivateKey: P256.KeyAgreement.PrivateKey?

  /// A helper object for encoding and decoding Base58Check format.
  private let base58Check: Base58CheckCoding = Base58Check()

  private let domain: String

  /// The default accessibility level for key storage.
  /// For more information on accessibility values, see [Accessibility.swift](https://github.com/square/Valet/blob/398816da91d2cb8fcc087a746f69ab872b04a5d5/Sources/Valet/Accessibility.swift#L21).
  private static let defaultAccessibility = Accessibility.whenUnlocked

  // MARK: - Initializers

  /// Convenience initializer that attempts to retrieve a private key associated with the given email and domain.
  /// If the private key is not available, it throws an error.
  ///
  /// - Parameters:
  ///   - email: The email address used to retrieve the private key.
  ///   - domain: The domain used to scope the key storage specific to an app.
  ///   - accessibility: Optional accessibility level for the key storage, defaults to `whenUnlocked`.
  ///     For more information on accessibility values, see [Accessibility.swift](https://github.com/square/Valet/blob/398816da91d2cb8fcc087a746f69ab872b04a5d5/Sources/Valet/Accessibility.swift#L21).
  ///
  /// Example:
  /// ```
  /// do {
  ///   let authKeyManager = try AuthKeyManager(email: "user@example.com", domain: "com.turnkey")
  /// } catch AuthKeyError.noPrivateKeyAvailable {
  ///   print("No private key available for the provided email.")
  /// } catch {
  ///   // Handle other potential errors
  /// }
  /// ```
  // public init(domain: String, keyIdentifier: String, accessibility: Accessibility) throws {
  //   self.valet = Valet.valet(
  //     with: Identifier(nonEmpty: "\(domain):\(email)")!,
  //     accessibility: accessibility ?? .whenUnlocked)

  //   do {
  //     let privateKey = try valet.object(forKey: email)
  //     self.privateKey = try P256.Signing.PrivateKey(x963Representation: privateKey)
  //     self.publicKey = self.privateKey?.publicKey
  //   } catch {
  //     self.privateKey = nil
  //     self.publicKey = nil
  //   }
  // }

  public init(domain: String) {
    self.domain = domain
  }

  // MARK: - Email Auth Methods

  /// Generates a new ephemeral key pair specifically for the email authentication flow. This method is typically called
  /// when initiating a new session that requires a secure exchange of keys without persisting them to permanent storage.
  ///
  /// The private key generated is stored in memory and should be cleared after the authentication flow is completed to ensure
  /// security.
  ///
  /// This method supports the Email Auth process as described in Turnkey's documentation.
  /// For more details on the Email Auth process, refer to the [Turnkey Email Auth Documentation](https://docs.turnkey.com/features/email-auth).
  ///
  /// - Returns: The public key component of the generated ephemeral key pair.
  /// - Throws: `AuthKeyError.publicKeyGenerationFailed` if the public key cannot be derived from the private key.
  ///
  /// ## Example
  /// ```swift
  /// let authManager = AuthKeyManager()
  /// do {
  ///   let publicKey = try authManager.createKeyPair()
  ///   print("Public Key: \(publicKey)")
  /// } catch {
  ///   print("Failed to generate key pair: \(error)")
  /// }
  /// ```
  public func createKeyPair() throws -> P256.KeyAgreement.PublicKey {
    // Generate a new ephemeral private key
    ephemeralPrivateKey = P256.KeyAgreement.PrivateKey()

    // Attempt to extract the public key from the private key
    guard let publicKey = ephemeralPrivateKey?.publicKey else {
      // If the public key cannot be derived, throw an error
      throw AuthKeyError.publicKeyGenerationFailed
    }

    // Return the derived public key
    return publicKey
  }

  /// `PersistOptions` is a structure used to define the storage options for cryptographic keys.
  ///
  /// This structure includes the identifier for the key and the accessibility level, which determines when the key can be accessed.
  ///
  /// ## Usage Example
  /// ```swift
  /// let options = PersistOptions(keyIdentifier: "user@example.com", accessibility: .whenUnlocked)
  /// ```
  public struct PersistOptions {
    /// The identifier for the key, typically associated with a user's unique identifier.
    let keyIdentifier: String

    /// The accessibility level of the key, determining when it can be accessed.
    let accessibility: Accessibility
  }

  /// Decrypts an encrypted bundle received during the Email Auth process without persisting the keys.
  ///
  /// This function is part of the Email Auth flow where the user receives an encrypted bundle via email.
  /// The bundle contains encrypted keys that are essential for completing the authentication process.
  /// This method allows for the decryption of that bundle to retrieve the private and public keys without
  /// storing them persistently in the device's secure storage.
  ///
  /// - Parameter encryptedBundle: The encrypted data bundle received via email.
  /// - Returns: A tuple containing the decrypted private and public keys.
  /// - Throws: An error if decryption fails or keys cannot be derived.
  ///
  /// ## Usage Example
  /// ```swift
  /// let encryptedBundle = "A6ZPGAlxBRZhjKWky4RpXnHVceGzJjTuBrzKvMGnIgZ3r6JD4D1iiSg_m-y_u0BgJKI397Xjn0wgu17w9wuRooEp-F38m4ql57FgQ7sX9nQA"
  /// do {
  ///   let (privateKey, publicKey) = try authManager.decryptBundle(encryptedBundle)
  ///   print("Decrypted Private Key: \(privateKey)")
  ///   print("Decrypted Public Key: \(publicKey)")
  /// } catch {
  ///   print("Failed to decrypt bundle: \(error)")
  /// }
  /// ```
  public func decryptBundle(_ encryptedBundle: String) throws
    -> (P256.Signing.PrivateKey, P256.Signing.PublicKey)
  {
    return try decryptBundle(encryptedBundle, persistOptions: nil)
  }

  public func decryptBundle(_ encryptedBundle: String, persistOptions: PersistOptions?) throws
    -> (P256.Signing.PrivateKey, P256.Signing.PublicKey)
  {
    do {
      let decodedEncryptedBundle = try base58Check.decode(string: encryptedBundle)

      let compressedEncapsulatedKey = decodedEncryptedBundle.prefix(33)
      let encryptedPrivateKey = decodedEncryptedBundle.dropFirst(33)

      guard compressedEncapsulatedKey.count == 33 else {
        throw AuthKeyError.invalidCompressedKeyLength

      }

      let uncompressedEncapsulatedKey = try P256.KeyAgreement.PublicKey(
        compressedRepresentation: compressedEncapsulatedKey
      ).x963Representation

      guard let receiverPrivateKey = ephemeralPrivateKey else {
        throw AuthKeyError.noPrivateKeyAvailable
      }

      guard let receiverPublicKey = ephemeralPrivateKey?.publicKey.x963Representation else {
        throw AuthKeyError.receiverPublicKeyDerivationFailed
      }

      let ciphersuite = HPKE.Ciphersuite(
        kem: HPKE.KEM.P256_HKDF_SHA256, kdf: HPKE.KDF.HKDF_SHA256, aead: HPKE.AEAD.AES_GCM_256)

      var recipient = try HPKE.Recipient(
        privateKey: receiverPrivateKey,
        ciphersuite: ciphersuite,
        info: "turnkey_hpke".data(using: .utf8)!,
        encapsulatedKey: uncompressedEncapsulatedKey
      )

      let aad = uncompressedEncapsulatedKey + receiverPublicKey
      let compressedPrivateKey = try recipient.open(encryptedPrivateKey, authenticating: aad)

      let privateKey = try P256.Signing.PrivateKey(rawRepresentation: compressedPrivateKey)
      let publicKey = privateKey.publicKey

      if let options = persistOptions {
        try persistPrivateKey(
          privateKey,
          keyIdentifier: options.keyIdentifier, accessibility: options.accessibility)
      }

      return (privateKey, publicKey)
    } catch {
      throw AuthKeyError.keyDecryptionFailed(error)

    }
  }

  // MARK: - Key Management

  /// Persists the given private key into secure storage and optionally caches it in memory.
  ///
  /// This method stores the private key securely using the Valet framework. It can also cache the key in memory
  /// to avoid frequent secure storage access, which might be beneficial for performance in scenarios where
  /// the key is accessed frequently.
  ///
  /// - Parameters:
  ///   - key: The `P256.Signing.PrivateKey` to be stored.
  ///   - keyIdentifier: A unique identifier for the key to manage retrieval and storage.
  ///   - accessibility: The security attribute that determines when the key can be accessed. Default is `.whenUnlocked`.
  ///   - cache: If `true`, the key is also stored in memory. Default is `false`.
  ///
  /// - Throws: `AuthKeyError.keyStoreFailure` if there is an error during the storage operation.
  ///
  /// - Note: Caching the key in memory can improve performance but may have security implications as the key remains
  ///   in RAM. Use this feature only if necessary and ensure to clear the key when it's no longer needed by calling
  ///   `clearPrivateKey()`.
  ///
  /// - Usage:
  ///   ```
  ///   do {
  ///     try authKeyManager.persistPrivateKey(privateKey, keyIdentifier: "user123", cache: true)
  ///   } catch {
  ///     print("Failed to store private key: \(error)")
  ///   }
  ///   ```
  public func persistPrivateKey(
    _ key: P256.Signing.PrivateKey, keyIdentifier: String,
    accessibility: Accessibility = .whenUnlocked, cache: Bool = false
  )
    throws
  {
    let valet = getValet(keyIdentifier: keyIdentifier)
    do {
      try valet.setObject(
        key.x963Representation,
        forKey: StorageKey.privateKey.forKey(keyIdentifier: keyIdentifier))
      // If cache is true, store the key in memory
      if cache {
        self.privateKey = key
      }
    } catch {
      throw AuthKeyError.keyStoreFailure("Unable to store item: \(error)")
    }
  }

  /// Retrieves the private key associated with the given key identifier.
  /// In the email auth flow this identifier will typically be the email address of the user.
  ///
  /// - Parameter keyIdentifier: The identifier for the private key to retrieve.
  /// - Returns: The `P256.Signing.PrivateKey` associated with the given identifier.
  /// - Throws: `AuthKeyError.privateKeyNotFound` if the private key cannot be found.
  public func getPrivateKey(keyIdentifier: String) throws -> P256.Signing.PrivateKey? {
    let valet = getValet(keyIdentifier: keyIdentifier)
    guard let key = privateKey as? P256.Signing.PrivateKey else {
      // Attempt to retrieve the key from the keychain
      let keyData = try valet.object(
        forKey: StorageKey.privateKey.forKey(keyIdentifier: keyIdentifier))
      guard let privateKey = try? P256.Signing.PrivateKey(x963Representation: keyData) else {
        throw AuthKeyError.noPrivateKeyAvailable
      }
      return privateKey
    }
    return key
  }

  /// Clears the stored private key from memory.
  ///
  /// This method should be used when you need to ensure that the private key is no longer
  /// retained in memory, for instance, when logging out a user or when security policies
  /// require removal of sensitive data from memory after use.
  public func clearPrivateKey() {
    self.privateKey = nil
  }

  enum StorageKey: String {
    case privateKey

    func forKey(keyIdentifier: String) -> String {
      switch self {
      case .privateKey:
        return "pk:\(keyIdentifier)"
      }
    }
  }

  private func getValet(keyIdentifier: String) -> Valet {
    return Valet.valet(
      with: Identifier(nonEmpty: "\(self.domain):\(keyIdentifier)")!,
      accessibility: .whenUnlocked)
  }
}
