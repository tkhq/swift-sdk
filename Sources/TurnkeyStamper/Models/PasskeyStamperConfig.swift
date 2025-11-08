import Foundation
import AuthenticationServices

/// Public configuration for passkey-based stamping.
///
/// Note: `ASPresentationAnchor` is not `Sendable`; this type uses `@unchecked Sendable`.
public struct PasskeyStamperConfig: @unchecked Sendable {
  public let rpId: String
  public let presentationAnchor: ASPresentationAnchor

  public init(rpId: String, presentationAnchor: ASPresentationAnchor) {
    self.rpId = rpId
    self.presentationAnchor = presentationAnchor
  }
}


