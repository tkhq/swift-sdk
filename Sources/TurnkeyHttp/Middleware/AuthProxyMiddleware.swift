import Foundation
import HTTPTypes
import OpenAPIRuntime

enum AuthProxyHeaderError: Error {
  case configIdMissing
  case invalidHeaderName(String)
}

extension AuthProxyHeaderError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .configIdMissing:
      return "Auth Proxy Config ID is required but was not provided."
    case .invalidHeaderName(let name):
      return "Invalid HTTP header name: \"\(name)\""
    }
  }
}

package struct AuthProxyHeaderMiddleware {
  private let configId: String?

  package init(configId: String?) {
    self.configId = configId
  }
}

extension AuthProxyHeaderMiddleware: ClientMiddleware {

  /// Intercepts an outgoing HTTP request and appends the `X-Auth-Proxy-Config-ID` header.
  ///
  /// - Parameters:
  ///   - request: The original HTTP request.
  ///   - body: The request body, if present.
  ///   - baseURL: The base URL of the API.
  ///   - operationID: The operation ID defined by OpenAPI.
  ///   - next: The next middleware or transport to call in the chain.
  /// - Returns: A tuple containing the HTTP response and optional body.
  /// - Throws:
  ///   - `AuthProxyHeaderError.configIdMissing` if no Auth Proxy Config ID is provided.
  ///   - `AuthProxyHeaderError.invalidHeaderName` if the header name is invalid.
  package func intercept(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String,
    next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
  ) async throws -> (HTTPResponse, HTTPBody?) {
    guard let configId else {
      throw AuthProxyHeaderError.configIdMissing
    }

    var request = request
    guard let fieldName = HTTPField.Name("X-Auth-Proxy-Config-ID") else {
      throw AuthProxyHeaderError.invalidHeaderName("X-Auth-Proxy-Config-ID")
    }
    request.headerFields[fieldName] = configId

    return try await next(request, body, baseURL)
  }
}
