import AuthenticationServices
import CryptoKit
import Foundation
import LocalAuthentication
import TurnkeyPasskeys

public class Stamper {
  private let apiPublicKey: String?
  private let apiPrivateKey: String?
  private let presentationAnchor: ASPresentationAnchor?
  private let passkeyManager: PasskeyStamper?

  public init() {
    self.apiPublicKey = nil
    self.apiPrivateKey = nil
    self.presentationAnchor = nil
    self.passkeyManager = nil
  }

  /// Initializes the stamper with an API key pair for signature stamping.
  ///
  /// - Parameters:
  ///   - apiPublicKey: The public key in hex format.
  ///   - apiPrivateKey: The corresponding private key in hex format.
  public init(apiPublicKey: String, apiPrivateKey: String) {
    self.apiPublicKey = apiPublicKey
    self.apiPrivateKey = apiPrivateKey
    self.presentationAnchor = nil
    self.passkeyManager = nil
  }

  /// Initializes the stamper with a passkey setup for WebAuthn-based signing.
  ///
  /// - Parameters:
  ///   - rpId: The relying party ID used in the passkey challenge.
  ///   - presentationAnchor: The anchor used for displaying authentication UI.
  public init(rpId: String, presentationAnchor: ASPresentationAnchor) {
    self.apiPublicKey = nil
    self.apiPrivateKey = nil
    self.presentationAnchor = presentationAnchor
    self.passkeyManager = PasskeyStamper(rpId: rpId, presentationAnchor: presentationAnchor)
  }

  /// Generates a signed stamp for the given payload using either API key or passkey credentials.
  ///
  /// - Parameter payload: The raw string payload to be signed.
  /// - Returns: A tuple containing the header name and the base64url-encoded stamp.
  /// - Throws: `StampError` if credentials are missing or signing fails.
  public func stamp(payload: String) async throws -> (
    stampHeaderName: String, stampHeaderValue: String
  ) {
    guard let payloadData = payload.data(using: .utf8) else {
      throw StampError.invalidPayload
    }

    let payloadHash = SHA256.hash(data: payloadData)

    if let pub = apiPublicKey, let priv = apiPrivateKey {
      let stamp = try ApiKeyStamper.stamp(
        payload: payloadHash, publicKeyHex: pub, privateKeyHex: priv)
      return ("X-Stamp", stamp)
    } else if let manager = passkeyManager {
      let stamp = try await PasskeyStampBuilder.stamp(
        payload: payloadHash, passkeyManager: manager)
      return ("X-Stamp-WebAuthn", stamp)
    } else {
      throw StampError.unknownError("Unable to stamp request")
    }
  }
}

/// we need this extention  to `Stamper` to be used safely across concurrency boundaries
extension Stamper: @unchecked Sendable {}

extension SHA256Digest {
  var hexEncoded: String {
    self.map { String(format: "%02x", $0) }.joined()
  }
}
