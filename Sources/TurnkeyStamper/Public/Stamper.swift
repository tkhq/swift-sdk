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

  public init(apiPublicKey: String, apiPrivateKey: String) {
    self.apiPublicKey = apiPublicKey
    self.apiPrivateKey = apiPrivateKey
    self.presentationAnchor = nil
    self.passkeyManager = nil
  }

  public init(rpId: String, presentationAnchor: ASPresentationAnchor) {
    self.apiPublicKey = nil
    self.apiPrivateKey = nil
    self.presentationAnchor = presentationAnchor
    self.passkeyManager = PasskeyStamper(rpId: rpId, presentationAnchor: presentationAnchor)
  }

  public init() {
    self.apiPublicKey = nil
    self.apiPrivateKey = nil
    self.presentationAnchor = nil
    self.passkeyManager = nil
  }

  public func stamp(payload: String) async throws -> (
    stampHeaderName: String, stampHeaderValue: String
  ) {
    guard let payloadData = payload.data(using: .utf8) else {
      throw StampError.invalidPayload
    }

    let payloadHash = SHA256.hash(data: payloadData)

    if let pub = apiPublicKey, let priv = apiPrivateKey {
      let stamp = try APIKeyStamper.stamp(
        payload: payloadHash, publicKeyHex: pub, privateKeyHex: priv)
      return ("X-Stamp", stamp)
    } else if let manager = passkeyManager {
      let stamp = try await PasskeyStamperHelpers.stamp(
        payload: payloadHash, passkeyManager: manager)
      return ("X-Stamp-WebAuthn", stamp)
    } else {
      throw StampError.unknownError("Unable to stamp request")
    }
  }
}

extension Stamper: @unchecked Sendable {}

extension SHA256Digest {
  var hexEncoded: String {
    self.map { String(format: "%02x", $0) }.joined()
  }
}
