import Foundation

/// The evidence type used to attest an API key when authenticating a request.
public enum AttestedStampScheme: String, Sendable {
  case p256OIDC = "STAMP_ATTESTED_SCHEME_P256_OIDC"
  case p256VerificationToken = "STAMP_ATTESTED_SCHEME_P256_VERIFICATION_TOKEN"
}

/// Signs requests with a locally held P-256 key and attaches an OIDC or OTP verification-token
/// attestation. Use this stamper for login activities and MFA approval before a session exists.
public final class AttestedStamper: StampProvider {
  private let attestedIdentity: String
  private let scheme: AttestedStampScheme
  private let stamper: Stamper

  /// - Parameters:
  ///   - attestedIdentity: An OIDC token or OTP verification token that attests the API key.
  ///   - scheme: The identity type used for the attestation.
  ///   - stamper: A stamper backed by the attested API key.
  public init(
    attestedIdentity: String,
    scheme: AttestedStampScheme,
    stamper: Stamper
  ) {
    self.attestedIdentity = attestedIdentity
    self.scheme = scheme
    self.stamper = stamper
  }

  public func stamp(payload: String) async throws -> (
    stampHeaderName: String, stampHeaderValue: String
  ) {
    guard let publicKey = stamper.publicKeyHex else {
      throw StampError.attestedStamperRequiresPublicKey
    }

    let signature = try await stamper.sign(payload: payload, format: .der)
    let stamp: [String: String] = [
      "publicKeyAttestation": attestedIdentity,
      "scheme": scheme.rawValue,
      "publicKey": publicKey,
      "signature": signature,
    ]
    let stampData = try JSONSerialization.data(withJSONObject: stamp, options: [])
    let encodedStamp =
      stampData
      .base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .trimmingCharacters(in: CharacterSet(charactersIn: "="))

    return ("X-Stamp-Attested", encodedStamp)
  }
}

extension AttestedStamper: @unchecked Sendable {}
