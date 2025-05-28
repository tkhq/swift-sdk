import CryptoKit
import Foundation

public struct TurnkeyCrypto {

  public static func generateP256KeyPair() -> (
    publicKeyUncompressed: String,
    publicKeyCompressed: String,
    privateKey: String
  ) {
    let priv = P256.Signing.PrivateKey()

    let pubHexUncompressed = priv.publicKey.x963Representation.hexString
    let pubHexCompressed = priv.publicKey.compressedRepresentation.hexString
    let privHex = priv.rawRepresentation.hexString

    return (
      publicKeyUncompressed: pubHexUncompressed,
      publicKeyCompressed: pubHexCompressed,
      privateKey: privHex
    )
  }

  public static func decryptCredentialBundle(
    encryptedBundle: String,
    ephemeralPrivateKey: P256.KeyAgreement.PrivateKey
  ) throws -> (P256.Signing.PrivateKey, P256.Signing.PublicKey) {
    return try HPKEHelpers.decryptCredentialBundle(
      encryptedBundle: encryptedBundle,
      ephemeralPrivateKey: ephemeralPrivateKey
    )
  }

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

    return try HPKEHelpers.decryptExportBundle(
      exportBundle: exportBundle,
      organizationId: organizationId,
      embeddedPrivateKey: privateKey,
      dangerouslyOverrideSignerPublicKey: dangerouslyOverrideSignerPublicKey,
      keyFormat: keyFormat,
      returnMnemonic: returnMnemonic
    )
  }

  public static func encryptWalletToBundle(
    mnemonic: String,
    importBundle: String,
    userId: String,
    organizationId: String,
    dangerouslyOverrideSignerPublicKey: String? = nil
  ) throws -> String {
    return try HPKEHelpers.encryptWalletToBundle(
      mnemonic: mnemonic,
      importBundle: importBundle,
      userId: userId,
      organizationId: organizationId,
      dangerouslyOverrideSignerPublicKey: dangerouslyOverrideSignerPublicKey
    )
  }
}
