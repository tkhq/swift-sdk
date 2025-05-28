import CryptoKit
import Foundation
import TurnkeyEncoding

enum SignatureVerifier {

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
}
