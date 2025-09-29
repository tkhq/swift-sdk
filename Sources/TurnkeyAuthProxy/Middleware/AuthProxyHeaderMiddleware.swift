import Foundation
import HTTPTypes
import OpenAPIRuntime

package struct AuthProxyHeaderMiddleware {
  private let configId: String

  package init(configId: String) {
    self.configId = configId
  }
}

extension AuthProxyHeaderMiddleware: ClientMiddleware {
  package func intercept(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String,
    next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
  ) async throws -> (HTTPResponse, HTTPBody?) {
    var request = request
    // Always attach required config header; content negotiation headers are set by generated code.
    request.headerFields.append(HTTPField(name: .init("X-Auth-Proxy-Config-Id")!, value: configId))
    return try await next(request, body, baseURL)
  }
}
