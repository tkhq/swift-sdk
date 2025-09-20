import Foundation
import OpenAPIURLSession

extension AuthProxyClient {

  /// Initialize an AuthProxyClient that automatically attaches `X-Auth-Proxy-Config-Id`.
  public init(configId: String, baseUrl: String = AuthProxyClient.baseURLString) {
    self.init(
      underlyingClient: Client(
        serverURL: URL(string: baseUrl)!,
        transport: URLSessionTransport(),
        middlewares: [
          AuthProxyHeaderMiddleware(configId: configId)
        ]
      )
    )
  }
}
