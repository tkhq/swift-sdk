import Foundation
import OpenAPIURLSession

extension AuthProxyClient {

  /// Initialize an AuthProxyClient that automatically attaches `X-Auth-Proxy-Config-Id`.
  /// - Parameters:
  ///   - configId: Value for `X-Auth-Proxy-Config-Id` header.
  ///   - baseUrl: API base URL.
  public init(
    configId: String,
    baseUrl: String = AuthProxyClient.baseURLString
  ) {
    self.init(
      underlyingClient: Client(
        serverURL: URL(string: baseUrl)!,
        transport: URLSessionTransport(),
        middlewares: [
          AuthProxyHeaderMiddleware(configId: configId),
          AuthProxyCaptureMiddleware.shared,
        ]
      )
    )
  }
}
