import Foundation

/// Public configuration for API key–backed stamping.
public struct ApiKeyStamperConfig: Sendable {
  public let apiPublicKey: String
  public let apiPrivateKey: String

  public init(apiPublicKey: String, apiPrivateKey: String) {
    self.apiPublicKey = apiPublicKey
    self.apiPrivateKey = apiPrivateKey
  }
}


