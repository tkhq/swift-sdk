import CryptoKit

/// Helper utilities for Turnkey authentication flows.
public struct AuthHelpers {
  /// Generates an ephemeral P256 key agreement key pair.
  /// - Returns: A tuple containing the ephemeral private key and its public key in x963 hex form.
  public static func generateEphemeralKeyAgreement() throws -> (
    ephemeralPrivateKey: P256.KeyAgreement.PrivateKey,
    publicKeyHex: String
  ) {
    let ephemeralPrivateKey = P256.KeyAgreement.PrivateKey()
    let publicKeyHex = try ephemeralPrivateKey.publicKey.toString(representation: .x963)
    return (ephemeralPrivateKey, publicKeyHex)
  }
}
