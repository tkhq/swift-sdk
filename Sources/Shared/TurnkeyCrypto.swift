import Base58Check
import CryptoKit
import Foundation

public enum CryptoError: Error {
  case invalidCompressedKeyLength
  case invalidPrivateLength(expected: Int, found: Int)
  case invalidPublicLength(expected: Int, found: Int)
  case missingEncappedPublic

  case invalidHexString(String)
  case invalidSignatureEncoding
  case invalidUTF8

  case invalidPublicKey
  case orgIdMismatch(expected: String, found: String?)
  case signerMismatch(expected: String, found: String)
  case signatureVerificationFailed
  case userIdMismatch(expected: String, found: String?)
}

extension CryptoError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .invalidCompressedKeyLength:
      return "Bundle too small – first 33 bytes (compressed pub‑key) missing."

    case let .invalidHexString(s):
      return "String “\(s)” is not valid hex."

    case .missingEncappedPublic:
      return "Signed payload lacked “encappedPublic”."

    case let .invalidPrivateLength(e, f):
      return "Secret scalar length \(f) bytes – expected \(e)."

    case let .invalidPublicLength(e, f):
      return "Public‑key length \(f) bytes – expected \(e)."

    case let .signerMismatch(exp, got):
      return "Signer pub‑key mismatch – expected \(exp), got \(got)."

    case let .orgIdMismatch(exp, got):
      return "OrganizationId mismatch – expected \(exp), got \(got ?? "nil")."

    case let .userIdMismatch(exp, got):
      return "UserId mismatch – expected \(exp), got \(got ?? "nil")."

    case .invalidPublicKey:
      return "Could not parse SEC‑1 public key."

    case .invalidSignatureEncoding:
      return "ECDSA signature isn’t valid DER."

    case .signatureVerificationFailed:
      return "Signature verification returned “false”."

    case .invalidUTF8:
      return "Byte‑sequence is not valid UTF‑8 text."
    }
  }

}

public enum KeyFormat { case other, solana }

/// A utility struct providing cryptographic operations for the Turnkey SDK.
public struct TurnkeyCrypto {

  private static let PRODUCTION_SIGNER_PUBLIC_KEY =
    "04cf288fe433cc4e1aa0ce1632feac4ea26bf2f5a09dcfe5a42c398e06898710330f0572882f4dbdf0f5304b8fc8703acd69adca9a4bbf7f5d00d20a5e364b2569"
  fileprivate static let hpkeInfo = "turnkey_hpke".data(using: .utf8)!

  private struct BundleOuter: Decodable {
    let enclaveQuorumPublic: String
    let dataSignature: String
    let data: String
  }
  private struct SignedInner: Decodable {
    let organizationId: String?
    let userId: String?
    let encappedPublic: String?
    let targetPublic: String?
    let ciphertext: String?
  }

  /**
  * Decrypts the Base58Check credential bundle received during e‑mail login.
  *
  * - Parameters:
  *   - encryptedBundle: Base58Check string from Turnkey.
  *   - ephemeralPrivateKey: P‑256 key created by the client for this login.
  * - Returns: The sender’s P‑256 signing private key and its public key.
  * - Throws: `CryptoError` if the bundle is malformed or HPKE decryption fails.
  */
  public static func decryptCredentialBundle(
    encryptedBundle: String,
    ephemeralPrivateKey: P256.KeyAgreement.PrivateKey
  ) throws -> (P256.Signing.PrivateKey, P256.Signing.PublicKey) {

    let decoded = try Base58Check().decode(string: encryptedBundle)
    guard decoded.count > 33 else { throw CryptoError.invalidCompressedKeyLength }

    let compressedEncappedKey = decoded.prefix(33)
    let ciphertext = decoded.dropFirst(33)

    let encappedKey = try P256.KeyAgreement.PublicKey(
      compressedRepresentation: compressedEncappedKey
    ).x963Representation

    let plaintext = try hpkeDecrypt(
      ciphertext: Data(ciphertext),
      encappedKey: encappedKey,
      receiverPriv: ephemeralPrivateKey)

    let signingPriv = try P256.Signing.PrivateKey(rawRepresentation: plaintext)
    return (signingPriv, signingPriv.publicKey)
  }

  /**
  * Decrypts a Turnkey export bundle validated against the enclave signature.
  *
  * - Parameters:
  *   - exportBundle: JSON string returned by `exports.download`.
  *   - organizationId: Expected organization ID inside the signed payload.
  *   - embeddedKey: P‑256 key authorised in the export policy.
  *   - dangerouslyOverrideSignerPublicKey: Optional signer key override.
  *   - keyFormat: `.other` or `.solana`.
  *   - returnMnemonic: When `true`, interpret the plaintext as UTF‑8 mnemonic.
  * - Returns: Hex string, Base58 key‑pair, or the mnemonic words.
  * - Throws: `CryptoError` on signature / ID mismatch, hex or HPKE failure, or
  *           UTF‑8 decoding failure.
  */
  public static func decryptExportBundle(
    exportBundle: String,
    organizationId: String,
    embeddedKey: P256.KeyAgreement.PrivateKey,
    dangerouslyOverrideSignerPublicKey: String? = nil,
    keyFormat: KeyFormat = .other,
    returnMnemonic: Bool = false
  ) throws -> String {

    let outer = try JSONDecoder().decode(BundleOuter.self, from: Data(exportBundle.utf8))

    guard
      try verifyEnclaveSignature(
        enclaveQuorumPublic: outer.enclaveQuorumPublic,
        publicSignature: outer.dataSignature,
        signedData: outer.data,
        dangerouslyOverrideSignerPublicKey: dangerouslyOverrideSignerPublicKey)
    else {
      throw CryptoError.signatureVerificationFailed
    }

    guard let innerData = Data(hexString: outer.data) else {
      throw CryptoError.invalidHexString(outer.data)
    }
    let inner = try JSONDecoder().decode(SignedInner.self, from: innerData)
    guard inner.organizationId == organizationId else {
      throw CryptoError.orgIdMismatch(expected: organizationId, found: inner.organizationId)
    }
    guard let encappedHex = inner.encappedPublic else {
      throw CryptoError.missingEncappedPublic
    }

    guard let ct = Data(hexString: inner.ciphertext!),
      let ek = Data(hexString: encappedHex)
    else {
      throw CryptoError.invalidHexString(inner.ciphertext!)
    }

    let plaintext = try hpkeDecrypt(
      ciphertext: ct,
      encappedKey: ek,
      receiverPriv: embeddedKey)

    switch keyFormat {
    case .solana where !returnMnemonic:
      guard plaintext.count == 32 else {
        throw CryptoError.invalidPrivateLength(expected: 32, found: plaintext.count)
      }
      let pubKey = try deriveEd25519PublicKey(from: plaintext)
      guard pubKey.count == 32 else {
        throw CryptoError.invalidPublicLength(expected: 32, found: pubKey.count)
      }
      let combo = plaintext + pubKey
      return Base58Check().encode(data: combo)

    default:
      if returnMnemonic {
        guard let mnemonic = String(data: plaintext, encoding: .utf8) else {
          throw CryptoError.invalidUTF8
        }
        return mnemonic
      } else {
        return plaintext.toHexString()
      }
    }
  }

  /**
  * Encrypts a mnemonic into an HPKE bundle suitable for `imports.upload`.
  *
  * - Parameters:
  *   - mnemonic: BIP‑39 words to protect.
  *   - importBundle: JSON string from `imports.prepare` containing the target key.
  *   - userId: Must match the signed payload.
  *   - organizationId: Must match the signed payload.
  *   - dangerouslyOverrideSignerPublicKey: Optional signer key override.
  * - Returns: JSON with `encappedPublic` and `ciphertext` fields (hex strings).
  * - Throws: `CryptoError` on signature / ID mismatch or HPKE encryption failure.
  */
  public static func encryptWalletToBundle(
    mnemonic: String,
    importBundle: String,
    userId: String,
    organizationId: String,
    dangerouslyOverrideSignerPublicKey: String? = nil
  ) throws -> String {

    let outer = try JSONDecoder().decode(
      BundleOuter.self,
      from: Data(importBundle.utf8))

    guard
      try verifyEnclaveSignature(
        enclaveQuorumPublic: outer.enclaveQuorumPublic,
        publicSignature: outer.dataSignature,
        signedData: outer.data,
        dangerouslyOverrideSignerPublicKey: dangerouslyOverrideSignerPublicKey)
    else {
      throw CryptoError.signatureVerificationFailed
    }

    guard let innerData = Data(hexString: outer.data) else {
      throw CryptoError.invalidHexString(outer.data)
    }
    let inner = try JSONDecoder().decode(SignedInner.self, from: innerData)

    guard inner.organizationId == organizationId else {
      throw CryptoError.orgIdMismatch(
        expected: organizationId,
        found: inner.organizationId)
    }
    guard inner.userId == userId else {
      throw CryptoError.userIdMismatch(expected: userId, found: inner.userId)
    }
    guard let targetHex = inner.targetPublic else {
      throw CryptoError.missingEncappedPublic
    }

    let plain = Data(mnemonic.utf8)
    let bundleBytes = try hpkeEncrypt(
      plaintext: plain,
      recipientPubKeyHex: targetHex)

    guard bundleBytes.count > 33 else { throw CryptoError.invalidCompressedKeyLength }

    let compressed = bundleBytes.prefix(33)
    let cipher = bundleBytes.dropFirst(33)

    // uncompress to 65‑byte sec-1
    let uncompressedPub = try P256.KeyAgreement.PublicKey(
      compressedRepresentation: compressed
    ).x963Representation

    let json: [String: String] = [
      "encappedPublic": uncompressedPub.toHexString(),
      "ciphertext": cipher.toHexString(),
    ]
    let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
    return String(decoding: jsonData, as: UTF8.self)
  }

  /**
  * Verifies a Turnkey enclave ECDSA‑P256 / SHA‑256 signature.
  *
  * - Parameters:
  *   - enclaveQuorumPublic: 65‑byte uncompressed public key (hex).
  *   - publicSignature: DER‑encoded ECDSA signature (hex).
  *   - signedData: Hex‑encoded payload that was signed.
  *   - dangerouslyOverrideSignerPublicKey: Optional signer key override.
  * - Returns: `true` when the signature is valid.
  * - Throws: `CryptoError` if the signer mismatches, decoding fails, or the
  *           signature is invalid.
  */
  @discardableResult
  fileprivate static func verifyEnclaveSignature(
    enclaveQuorumPublic: String,
    publicSignature: String,
    signedData: String,
    dangerouslyOverrideSignerPublicKey: String? = nil
  ) throws -> Bool {

    let expectedKey = dangerouslyOverrideSignerPublicKey ?? PRODUCTION_SIGNER_PUBLIC_KEY
    guard enclaveQuorumPublic == expectedKey else {
      throw CryptoError.signerMismatch(
        expected: expectedKey, found: enclaveQuorumPublic)
    }

    guard let pubKeyData = Data(hexString: enclaveQuorumPublic),
      let sigData = Data(hexString: publicSignature),
      let payload = Data(hexString: signedData)
    else {
      throw CryptoError.invalidHexString(enclaveQuorumPublic)
    }
    guard let publicKey = try? P256.Signing.PublicKey(x963Representation: pubKeyData) else {
      throw CryptoError.invalidPublicKey
    }

    let signature: P256.Signing.ECDSASignature
    do {
      signature = try P256.Signing.ECDSASignature(derRepresentation: sigData)
    } catch {
      throw CryptoError.invalidSignatureEncoding
    }

    let digest = SHA256.hash(data: payload)

    return publicKey.isValidSignature(signature, for: digest)
  }

  /**
  * HPKE‑decrypt helper for P‑256 / HKDF‑SHA256 / AES‑GCM‑256.
  *
  * - Parameters:
  *   - ciphertext: AES‑GCM ciphertext.
  *   - encappedKey: 65‑byte uncompressed encapsulated public key.
  *   - receiverPriv: The recipient's P-256 private key used for decryption.
  * - Returns: Decrypted plaintext bytes.
  * - Throws: `CryptoError` when HPKE decryption fails.
  */
  fileprivate static func hpkeDecrypt(
    ciphertext: Data,
    encappedKey: Data,
    receiverPriv: P256.KeyAgreement.PrivateKey
  ) throws -> Data {

    let suite = HPKE.Ciphersuite(
      kem: .P256_HKDF_SHA256,
      kdf: .HKDF_SHA256,
      aead: .AES_GCM_256)

    var recipient = try HPKE.Recipient(
      privateKey: receiverPriv,
      ciphersuite: suite,
      info: hpkeInfo,
      encapsulatedKey: encappedKey)

    let aad = encappedKey + receiverPriv.publicKey.x963Representation
    return try recipient.open(ciphertext, authenticating: aad)
  }

  fileprivate static func deriveEd25519PublicKey(from secretScalar: Data) throws -> Data {
    guard secretScalar.count == 32 else {
      throw CryptoError.invalidPrivateLength(expected: 32, found: secretScalar.count)
    }

    let priv = try Curve25519.Signing.PrivateKey(rawRepresentation: secretScalar)
    return priv.publicKey.rawRepresentation
  }

  /**
  * HPKE‑encrypt helper (ephemeral mode) producing `[compressedEncapped ‖ ciphertext]`.
  *
  * - Parameters:
  *   - plaintext: Data to encrypt.
  *   - recipientPubKeyHex: 65‑byte uncompressed recipient key (hex).
  * - Returns: Binary bundle of 33‑byte compressed key plus ciphertext.
  * - Throws: `CryptoError` when hex decoding or HPKE encryption fails.
  */
  fileprivate static func hpkeEncrypt(
    plaintext: Data,
    recipientPubKeyHex: String
  ) throws -> Data {

    guard let recipientData = Data(hexString: recipientPubKeyHex) else {
      throw CryptoError.invalidHexString(recipientPubKeyHex)
    }
    let recipientPub = try P256.KeyAgreement.PublicKey(x963Representation: recipientData)

    let suite = HPKE.Ciphersuite(
      kem: .P256_HKDF_SHA256,
      kdf: .HKDF_SHA256,
      aead: .AES_GCM_256)
    let info = hpkeInfo

    var sender = try HPKE.Sender(
      recipientKey: recipientPub,
      ciphersuite: suite,
      info: info)

    let aad = sender.encapsulatedKey + recipientData

    let ciphertext = try sender.seal(plaintext, authenticating: aad)

    let compressedEncapped =
      try P256.KeyAgreement.PublicKey(x963Representation: sender.encapsulatedKey)
      .compressedRepresentation

    guard compressedEncapped.count == 33 else {
      throw CryptoError.invalidCompressedKeyLength
    }

    var out = Data()
    out.append(compressedEncapped)
    out.append(ciphertext)
    return out
  }

}
