import CryptoKit
import Foundation
import TurnkeyEncoding

public struct TurnkeyCrypto {

  /// Generates a new P-256 keypair and returns it in hex format.
  ///
  /// - Returns: A tuple containing:
  ///   - `publicKeyUncompressed`: The uncompressed public key in hex format.
  ///   - `publicKeyCompressed`: The compressed public key in hex format.
  ///   - `privateKey`: The raw private key in hex format.
  public static func generateP256KeyPair() -> (
    publicKeyUncompressed: String,
    publicKeyCompressed: String,
    privateKey: String
  ) {
    let priv = P256.Signing.PrivateKey()

    let pubHexUncompressed = priv.publicKey.x963Representation.toHexString()
    let pubHexCompressed = priv.publicKey.compressedRepresentation.toHexString()
    let privHex = priv.rawRepresentation.toHexString()

    return (
      publicKeyUncompressed: pubHexUncompressed,
      publicKeyCompressed: pubHexCompressed,
      privateKey: privHex
    )
  }

  /// Decrypts a credential bundle using the provided ephemeral private key.
  ///
  /// - Parameters:
  ///   - encryptedBundle: The base58-encoded bundle string.
  ///   - ephemeralPrivateKey: The ephemeral private key used for HPKE decryption.
  /// - Returns: A tuple containing the decrypted signing private key and corresponding public key.
  /// - Throws: `CryptoError` if decryption or decoding fails.
  public static func decryptCredentialBundle(
    encryptedBundle: String,
    ephemeralPrivateKey: P256.KeyAgreement.PrivateKey
  ) throws -> (P256.Signing.PrivateKey, P256.Signing.PublicKey) {
    return try HpkeHelpers.decryptCredentialBundle(
      encryptedBundle: encryptedBundle,
      ephemeralPrivateKey: ephemeralPrivateKey
    )
  }

  /// Decrypts an export bundle and returns either a hex string or mnemonic depending on configuration.
  ///
  /// - Parameters:
  ///   - exportBundle: A signed and encrypted bundle from Turnkey's enclave.
  ///   - organizationId: The expected organization ID to verify against.
  ///   - embeddedPrivateKey: The raw embedded private key in hex format.
  ///   - dangerouslyOverrideSignerPublicKey: Optional override of the signer public key (for dev/test).
  ///   - keyFormat: The output format for Solana or other keys.
  ///   - returnMnemonic: If `true`, returns the plaintext as a UTF-8 encoded mnemonic.
  /// - Returns: The decrypted payload as either a mnemonic or hex string.
  /// - Throws: `CryptoError` if any validation, decoding, or decryption fails.
  public static func decryptExportBundle(
    exportBundle: String,
    organizationId: String,
    embeddedPrivateKey: String,
    dangerouslyOverrideSignerPublicKey: String? = nil,
    keyFormat: KeyFormat = .other,
    returnMnemonic: Bool = false
  ) throws -> String {
    guard let keyData = Data(hexString: embeddedPrivateKey) else {
      throw CryptoError.invalidHexString(embeddedPrivateKey)
    }

    let privateKey: P256.KeyAgreement.PrivateKey
    do {
      privateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: keyData)
    } catch {
      throw CryptoError.invalidPrivateKey(error)
    }

    return try HpkeHelpers.decryptExportBundle(
      exportBundle: exportBundle,
      organizationId: organizationId,
      embeddedPrivateKey: privateKey,
      dangerouslyOverrideSignerPublicKey: dangerouslyOverrideSignerPublicKey,
      keyFormat: keyFormat,
      returnMnemonic: returnMnemonic
    )
  }

  /// Encrypts a mnemonic into a bundle using the import payload from the enclave.
  ///
  /// - Parameters:
  ///   - mnemonic: The plaintext mnemonic string to encrypt.
  ///   - importBundle: The enclave-generated bundle to use for encryption.
  ///   - userId: The expected user ID to verify against.
  ///   - organizationId: The expected organization ID to verify against.
  ///   - dangerouslyOverrideSignerPublicKey: Optional override of the signer public key (for dev/test).
  /// - Returns: The encrypted bundle as a JSON string.
  /// - Throws: `CryptoError` if validation or encryption fails.
  public static func encryptWalletToBundle(
    mnemonic: String,
    importBundle: String,
    userId: String,
    organizationId: String,
    dangerouslyOverrideSignerPublicKey: String? = nil
  ) throws -> String {
    return try HpkeHelpers.encryptWalletToBundle(
      mnemonic: mnemonic,
      importBundle: importBundle,
      userId: userId,
      organizationId: organizationId,
      dangerouslyOverrideSignerPublicKey: dangerouslyOverrideSignerPublicKey
    )
  }
}
