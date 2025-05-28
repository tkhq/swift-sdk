import Base58Check
import CryptoKit
import Foundation
import TurnkeyEncoding

enum HPKEHelpers {

  static func decryptCredentialBundle(
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

  static func decryptExportBundle(
    exportBundle: String,
    organizationId: String,
    embeddedPrivateKey: P256.KeyAgreement.PrivateKey,
    dangerouslyOverrideSignerPublicKey: String?,
    keyFormat: KeyFormat,
    returnMnemonic: Bool
  ) throws -> String {

    let outer = try JSONDecoder().decode(BundleOuter.self, from: Data(exportBundle.utf8))

    guard
      try SignatureVerifier.verifyEnclaveSignature(
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
      receiverPriv: embeddedPrivateKey)

    switch keyFormat {
    case .solana where !returnMnemonic:
      guard plaintext.count == 32 else {
        throw CryptoError.invalidPrivateLength(expected: 32, found: plaintext.count)
      }
      let pubKey = try deriveEd25519PublicKey(from: plaintext)
      guard pubKey.count == 32 else {
        throw CryptoError.invalidPublicLength(expected: 32, found: pubKey.count)
      }
      return Base58Check().encode(data: plaintext + pubKey)

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

  static func encryptWalletToBundle(
    mnemonic: String,
    importBundle: String,
    userId: String,
    organizationId: String,
    dangerouslyOverrideSignerPublicKey: String?
  ) throws -> String {

    let outer = try JSONDecoder().decode(BundleOuter.self, from: Data(importBundle.utf8))

    guard
      try SignatureVerifier.verifyEnclaveSignature(
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
    guard inner.userId == userId else {
      throw CryptoError.userIdMismatch(expected: userId, found: inner.userId)
    }
    guard let targetHex = inner.targetPublic else {
      throw CryptoError.missingEncappedPublic
    }

    let plaintext = Data(mnemonic.utf8)
    let bundleBytes = try hpkeEncrypt(
      plaintext: plaintext,
      recipientPubKeyHex: targetHex)

    guard bundleBytes.count > 33 else {
      throw CryptoError.invalidCompressedKeyLength
    }

    let compressed = bundleBytes.prefix(33)
    let cipher = bundleBytes.dropFirst(33)

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

  static func hpkeDecrypt(
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
      info: TurnkeyConstants.hpkeInfo,
      encapsulatedKey: encappedKey)

    let aad = encappedKey + receiverPriv.publicKey.x963Representation
    return try recipient.open(ciphertext, authenticating: aad)
  }

  static func hpkeEncrypt(
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

    var sender = try HPKE.Sender(
      recipientKey: recipientPub,
      ciphersuite: suite,
      info: TurnkeyConstants.hpkeInfo)

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

  static func deriveEd25519PublicKey(from secretScalar: Data) throws -> Data {
    guard secretScalar.count == 32 else {
      throw CryptoError.invalidPrivateLength(expected: 32, found: secretScalar.count)
    }

    let priv = try Curve25519.Signing.PrivateKey(rawRepresentation: secretScalar)
    return priv.publicKey.rawRepresentation
  }
}
