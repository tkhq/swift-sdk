import AuthenticationServices
import CryptoKit
import Foundation
import TurnkeyStamper
import TurnkeyTypes

/// Configuration for activity polling
public struct ActivityPollerConfig {
  /// Interval between poll attempts in milliseconds
  public let intervalMs: Int
  /// Maximum number of retry attempts
  public let numRetries: Int

  public init(intervalMs: Int = 1000, numRetries: Int = 3) {
    self.intervalMs = intervalMs
    self.numRetries = numRetries
  }
}

public struct TurnkeyClient {
  public static let baseURLString = "https://api.turnkey.com"
  public static let authProxyBaseURLString = "https://authproxy.turnkey.com"

  // Configuration
  internal let baseUrl: String
  internal let authProxyUrl: String?
  internal let authProxyConfigId: String?
  internal let stamper: Stamper?
  internal let activityPoller: ActivityPollerConfig

  internal init(
    baseUrl: String = TurnkeyClient.baseURLString,
    authProxyUrl: String? = nil,
    authProxyConfigId: String? = nil,
    stamper: Stamper? = nil,
    activityPoller: ActivityPollerConfig = ActivityPollerConfig()
  ) {
    self.baseUrl = baseUrl
    self.authProxyUrl = authProxyUrl
    self.authProxyConfigId = authProxyConfigId
    self.stamper = stamper
    self.activityPoller = activityPoller
  }

  /// Initializes a `TurnkeyClient` with an API key pair for stamping requests.
  ///
  /// - Parameters:
  ///   - apiPrivateKey: The hex-encoded API private key.
  ///   - apiPublicKey: The hex-encoded API public key.
  ///   - baseUrl: Optional base URL (defaults to Turnkey production).
  ///   - activityPoller: Optional activity polling configuration.
  public init(
    apiPrivateKey: String,
    apiPublicKey: String,
    baseUrl: String = TurnkeyClient.baseURLString,
    activityPoller: ActivityPollerConfig = ActivityPollerConfig()
  ) {
    let stamper = Stamper(apiPublicKey: apiPublicKey, apiPrivateKey: apiPrivateKey)
    self.init(
      baseUrl: baseUrl,
      stamper: stamper,
      activityPoller: activityPoller
    )
  }

  /// Initializes a `TurnkeyClient` with passkey authentication for stamping requests.
  ///
  /// - Parameters:
  ///   - rpId: The Relying Party ID (must match your app's associated domain config).
  ///   - presentationAnchor: The window or view used to present authentication prompts.
  ///   - baseUrl: Optional base URL (defaults to Turnkey production).
  public init(
    rpId: String,
    presentationAnchor: ASPresentationAnchor,
    baseUrl: String = TurnkeyClient.baseURLString
  ) {
    let stamper = Stamper(rpId: rpId, presentationAnchor: presentationAnchor)
    self.init(
      baseUrl: baseUrl,
      stamper: stamper
    )
  }

  /// Initializes a `TurnkeyClient` with Auth Proxy only.
  ///
  /// - Parameters:
  ///   - authProxyConfigId: The Auth Proxy config ID to include in requests.
  ///   - authProxyUrl: Optional Auth Proxy URL (defaults to Turnkey production).
  public init(
    authProxyConfigId: String,
    authProxyUrl: String = TurnkeyClient.authProxyBaseURLString
  ) {
    self.init(
      authProxyUrl: authProxyUrl,
      authProxyConfigId: authProxyConfigId,
      stamper: nil
    )
  }

  /// Initializes a `TurnkeyClient` with both API key authentication and Auth Proxy.
  ///
  /// - Parameters:
  ///   - apiPrivateKey: The hex-encoded API private key.
  ///   - apiPublicKey: The hex-encoded API public key.
  ///   - authProxyConfigId: The Auth Proxy config ID to include in requests.
  ///   - baseUrl: Optional base URL (defaults to Turnkey production).
  ///   - authProxyUrl: Optional Auth Proxy URL (defaults to Turnkey production).
  public init(
    apiPrivateKey: String,
    apiPublicKey: String,
    authProxyConfigId: String,
    baseUrl: String = TurnkeyClient.baseURLString,
    authProxyUrl: String = TurnkeyClient.authProxyBaseURLString
  ) {
    let stamper = Stamper(apiPublicKey: apiPublicKey, apiPrivateKey: apiPrivateKey)
    self.init(
      baseUrl: baseUrl,
      authProxyUrl: authProxyUrl,
      authProxyConfigId: authProxyConfigId,
      stamper: stamper
    )
  }

  /// Initializes a `TurnkeyClient` with both passkey authentication and Auth Proxy.
  ///
  /// - Parameters:
  ///   - rpId: The Relying Party ID (must match your app's associated domain config).
  ///   - presentationAnchor: The window or view used to present authentication prompts.
  ///   - authProxyConfigId: The Auth Proxy config ID to include in requests.
  ///   - baseUrl: Optional base URL (defaults to Turnkey production).
  ///   - authProxyUrl: Optional Auth Proxy URL (defaults to Turnkey production).
  public init(
    rpId: String,
    presentationAnchor: ASPresentationAnchor,
    authProxyConfigId: String,
    baseUrl: String = TurnkeyClient.baseURLString,
    authProxyUrl: String = TurnkeyClient.authProxyBaseURLString
  ) {
    let stamper = Stamper(rpId: rpId, presentationAnchor: presentationAnchor)
    self.init(
      baseUrl: baseUrl,
      authProxyUrl: authProxyUrl,
      authProxyConfigId: authProxyConfigId,
      stamper: stamper
    )
  }
}
