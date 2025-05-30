import Foundation
import HTTPTypes
import OpenAPIRuntime

enum ProxyMiddlewareError: Error {
  case invalidHeaderName(String)
}

extension ProxyMiddlewareError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .invalidHeaderName(let name):
      return "Failed to construct HTTP header name: \"\(name)\""
    }
  }
}

package struct ProxyMiddleware {
  private let proxyURL: URL

  /// Initializes the middleware with a proxy base URL.
  ///
  /// - Parameter proxyURL: The base URL to forward all requests to.
  package init(proxyURL: URL) {
    self.proxyURL = proxyURL
  }
}

extension ProxyMiddleware: ClientMiddleware {

  /// Intercepts an outgoing HTTP request, appends a proxy header, and rewrites the base URL.
  ///
  /// - Parameters:
  ///   - request: The original HTTP request.
  ///   - body: The request body, if present.
  ///   - baseURL: The original base URL.
  ///   - operationID: The OpenAPI operation ID (unused here).
  ///   - next: The next middleware or transport to call.
  /// - Returns: A tuple of HTTP response and optional body.
  /// - Throws: Any error thrown by downstream middleware or transport.
  package func intercept(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String,
    next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
  ) async throws -> (HTTPResponse, HTTPBody?) {
    // we save the original full URL: baseURL + request.path
    let originalURL = baseURL.appendingPathComponent(request.path ?? "")

    // we add the X-Turnkey-Request-Url header to the request
    var request = request
    let headerName = "X-Turnkey-Request-Url"
    guard let headerFieldName = HTTPField.Name(headerName) else {
      throw ProxyMiddlewareError.invalidHeaderName(headerName)
    }

    let xTurnkeyRequestUrl = HTTPField(
      name: headerFieldName,
      value: originalURL.absoluteString
    )
    request.headerFields.append(xTurnkeyRequestUrl)

    // we clear the path since the proxy handles routing
    request.path = ""

    // we forward the modified request to the proxy URL
    return try await next(request, body, proxyURL)
  }
}
