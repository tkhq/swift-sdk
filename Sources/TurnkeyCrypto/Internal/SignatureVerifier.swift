import CryptoKit
import Foundation
import TurnkeyEncoding

enum SignatureVerifier {

  /// Verifies that the given signature is valid for the provided signed data using the enclave's public key.
  ///
  /// - Parameters:
  ///   - enclaveQuorumPublic: The hex-encoded public key of the enclave (should match the expected signer).
  ///   - publicSignature: The hex-encoded ECDSA signature over the signed data.
  ///   - signedData: The hex-encoded data that was signed.
  ///   - dangerouslyOverrideSignerPublicKey: An optional override to bypass the production public key check (used in dev/test).
  /// - Returns: `true` if the signature is valid.
  /// - Throws: `CryptoError` if the public key is invalid, the data can't be decoded, or the signature is malformed or does not match.
  @discardableResult
  static func verifyEnclaveSignature(
    enclaveQuorumPublic: String,
    publicSignature: String,
    signedData: String,
    dangerouslyOverrideSignerPublicKey: String? = nil
  ) throws -> Bool {
    let expectedKey =
      dangerouslyOverrideSignerPublicKey ?? TurnkeyConstants.productionSignerPublicKey

    guard enclaveQuorumPublic == expectedKey else {
      throw CryptoError.signerMismatch(expected: expectedKey, found: enclaveQuorumPublic)
    }

    guard let pubKeyData = Data(hexString: enclaveQuorumPublic) else {
      throw CryptoError.invalidHexString(enclaveQuorumPublic)
    }
    guard let sigData = Data(hexString: publicSignature) else {
      throw CryptoError.invalidHexString(publicSignature)
    }
    guard let payload = Data(hexString: signedData) else {
      throw CryptoError.invalidHexString(signedData)
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
}
