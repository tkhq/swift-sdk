import Foundation
import HTTPTypes
import OpenAPIRuntime

package struct ProxyMiddleware {
  private let proxyURL: URL

  package init(proxyURL: URL) {
    self.proxyURL = proxyURL
  }
}

extension ProxyMiddleware: ClientMiddleware {
  package func intercept(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String,
    next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
  ) async throws -> (HTTPResponse, HTTPBody?) {
    // Save the current full path of the request (baseUrl + request.path)
    let originalURL = baseURL.appendingPathComponent(request.path ?? "")

    // Set the X-Turnkey-Request-Url header with the saved original request URL
    var request = request
    let xTurnkeyRequestUrl = HTTPField(
      name: HTTPField.Name("X-Turnkey-Request-Url")!, value: originalURL.absoluteString)
    request.headerFields.append(xTurnkeyRequestUrl)

    // Remove the request path and just forward to the proxyBaseURL
    request.path = ""

    // Call and return the next middleware with the modified request and proxy base URL
    return try await next(request, body, proxyURL)
  }
}
