import AuthenticationServices
import CryptoKit
import Foundation
import OpenAPIURLSession
import TurnkeyStamper

extension TurnkeyClient {
  /// Initializes a `TurnkeyClient` with a proxy server URL.
  /// - Parameter proxyURL: The URL of the proxy server.
  public init(proxyURL: String) {
    self.init(
      underlyingClient: Client(
        serverURL: URL(string: TurnkeyClient.baseURLString)!,
        transport: URLSessionTransport(),
        middlewares: [ProxyMiddleware(proxyURL: URL(string: proxyURL)!)]
      )
    )
  }

  /// Initializes a `TurnkeyClient` with API keys for authentication.
  public init(
    apiPrivateKey: String, apiPublicKey: String, baseUrl: String = TurnkeyClient.baseURLString
  ) {
    let stamper = Stamper(apiPublicKey: apiPublicKey, apiPrivateKey: apiPrivateKey)
    self.init(
      underlyingClient: Client(
        serverURL: URL(string: baseUrl)!,
        transport: URLSessionTransport(),
        middlewares: [AuthStampMiddleware(stamper: stamper)]
      )
    )
  }

  /// Initializes a `TurnkeyClient` using on-device session credentials.
  public init() {
    let stamper = Stamper()
    self.init(
      underlyingClient: Client(
        serverURL: URL(string: TurnkeyClient.baseURLString)!,
        transport: URLSessionTransport(),
        middlewares: [AuthStampMiddleware(stamper: stamper)]
      )
    )
  }

  /// Creates an instance of the TurnkeyClient that uses passkeys for authentication.
  public init(
    rpId: String, presentationAnchor: ASPresentationAnchor,
    baseUrl: String = TurnkeyClient.baseURLString
  ) {
    let stamper = Stamper(rpId: rpId, presentationAnchor: presentationAnchor)
    self.init(
      underlyingClient: Client(
        serverURL: URL(string: baseUrl)!,
        transport: URLSessionTransport(),
        middlewares: [AuthStampMiddleware(stamper: stamper)]
      )
    )
  }

}
