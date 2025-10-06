import AuthenticationServices
import CryptoKit
import Foundation
import OpenAPIRuntime
import OpenAPIURLSession
import TurnkeyAuthProxyAPI
import TurnkeyPublicAPI
import TurnkeyStamper

public struct TurnkeyClient {
  public static let baseURLString = "https://api.turnkey.com"
  public static let authProxyBaseURLString = "https://authproxy.turnkey.com"

  internal let publicClient: (any TurnkeyPublicAPI.APIProtocol)?
  internal let authProxyClient: (any TurnkeyAuthProxyAPI.APIProtocol)?

  internal init(
    publicClient: (any TurnkeyPublicAPI.APIProtocol)? = nil,
    authProxyClient: (any TurnkeyAuthProxyAPI.APIProtocol)? = nil
  ) {
    self.publicClient = publicClient
    self.authProxyClient = authProxyClient
  }

  /// Initializes a `TurnkeyClient` with an API key pair for stamping requests.
  ///
  /// Configures:
  /// - A public client that stamps requests using the provided API key pair.
  ///
  /// Use this when you only need to call stamped public API endpoints,
  /// and do not need Auth Proxy.
  ///
  /// - Parameters:
  ///   - apiPrivateKey: The base64-encoded API private key.
  ///   - apiPublicKey: The base64-encoded API public key.
  ///   - baseUrl: Optional base URL (defaults to Turnkey production).
  public init(
    apiPrivateKey: String,
    apiPublicKey: String,
    baseUrl: String = TurnkeyClient.baseURLString
  ) {
    let stamper = Stamper(apiPublicKey: apiPublicKey, apiPrivateKey: apiPrivateKey)
    self.init(
      publicClient: TurnkeyPublicAPI.Client(
        serverURL: URL(string: baseUrl)!,
        transport: URLSessionTransport(),
        middlewares: [AuthStampMiddleware(stamper: stamper)]
      ),
      authProxyClient: nil
    )
  }

  /// Initializes a `TurnkeyClient` with passkey authentication for stamping requests.
  ///
  /// Configures:
  /// - A public client that stamps requests using the provided passkey.
  ///
  /// Use this when you only need to call stamped public API endpoints,
  /// and do not need Auth Proxy.
  ///
  /// - Parameters:
  ///   - rpId: The Relying Party ID (must match your app’s associated domain config).
  ///   - presentationAnchor: The window or view used to present authentication prompts.
  ///   - baseUrl: Optional base URL (defaults to Turnkey production).
  public init(
    rpId: String,
    presentationAnchor: ASPresentationAnchor,
    baseUrl: String = TurnkeyClient.baseURLString
  ) {
    let stamper = Stamper(rpId: rpId, presentationAnchor: presentationAnchor)
    self.init(
      publicClient: TurnkeyPublicAPI.Client(
        serverURL: URL(string: baseUrl)!,
        transport: URLSessionTransport(),
        middlewares: [AuthStampMiddleware(stamper: stamper)]
      ),
      authProxyClient: nil
    )
  }

  /// Initializes a `TurnkeyClient` with Auth Proxy only.
  ///
  /// Configures:
  /// - An auth proxy client that includes the given config ID in requests.
  ///
  /// Use this when you only need to call Auth Proxy endpoints,
  /// and do not need stamped public API requests.
  ///
  /// - Parameters:
  ///   - authProxyConfigId: The Auth Proxy config ID to include in requests.
  ///   - authProxyUrl: Optional Auth Proxy URL (defaults to Turnkey production).
  public init(
    authProxyConfigId: String,
    authProxyUrl: String = TurnkeyClient.authProxyBaseURLString
  ) {
    self.init(
      publicClient: nil,
      authProxyClient: TurnkeyAuthProxyAPI.Client(
        serverURL: URL(string: authProxyUrl)!,
        transport: URLSessionTransport(),
        middlewares: [AuthProxyHeaderMiddleware(configId: authProxyConfigId)]
      )
    )
  }

  /// Initializes a `TurnkeyClient` with both API key authentication and Auth Proxy.
  ///
  /// Configures:
  /// - A public client that stamps requests using the provided API key pair.
  /// - An auth proxy client that includes the given config ID in requests.
  ///
  /// Use this when your app needs to call both stamped public API endpoints
  /// and Auth Proxy endpoints.
  ///
  /// - Parameters:
  ///   - apiPrivateKey: The base64-encoded API private key.
  ///   - apiPublicKey: The base64-encoded API public key.
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
      publicClient: TurnkeyPublicAPI.Client(
        serverURL: URL(string: baseUrl)!,
        transport: URLSessionTransport(),
        middlewares: [AuthStampMiddleware(stamper: stamper)]
      ),
      authProxyClient: TurnkeyAuthProxyAPI.Client(
        serverURL: URL(string: authProxyUrl)!,
        transport: URLSessionTransport(),
        middlewares: [AuthProxyHeaderMiddleware(configId: authProxyConfigId)]
      )
    )
  }

  /// Initializes a `TurnkeyClient` with both passkey authentication and Auth Proxy.
  ///
  /// Configures:
  /// - A public client that stamps requests using the provided passkey.
  /// - An auth proxy client that includes the given config ID in requests.
  ///
  /// Use this when your app needs to call both stamped public API endpoints
  /// and Auth Proxy endpoints.
  ///
  /// - Parameters:
  ///   - rpId: The Relying Party ID (must match your app’s associated domain config).
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
      publicClient: TurnkeyPublicAPI.Client(
        serverURL: URL(string: baseUrl)!,
        transport: URLSessionTransport(),
        middlewares: [AuthStampMiddleware(stamper: stamper)]
      ),
      authProxyClient: TurnkeyAuthProxyAPI.Client(
        serverURL: URL(string: authProxyUrl)!,
        transport: URLSessionTransport(),
        middlewares: [AuthProxyHeaderMiddleware(configId: authProxyConfigId)]
      )
    )
  }
}
