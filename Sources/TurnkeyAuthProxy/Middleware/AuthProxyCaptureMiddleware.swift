import Foundation
import HTTPTypes
import OpenAPIRuntime

package struct CapturedHTTPResponse {
  package let statusCode: Int
  package let headers: HTTPFields
  package let body: Data
}


package final class CapturedResponseStorage {
  package var last: CapturedHTTPResponse?
}

package enum AuthProxyCapturedResponse {
  @TaskLocal static var storage: CapturedResponseStorage?
}

package struct AuthProxyCaptureMiddleware: ClientMiddleware {
  private let maxBytes: Int? // nil = unlimited

  package init(maxBytes: Int? = 1 << 20) {
    self.maxBytes = maxBytes
  }

  package static let shared = AuthProxyCaptureMiddleware()

  package func intercept(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String,
    next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
  ) async throws -> (HTTPResponse, HTTPBody?) {
    let (response, body) = try await next(request, body, baseURL)

    // Only capture and buffer non-2xx responses to limit overhead.
    guard !(200...299).contains(response.status.code) else {
      return (response, body)
    }

    var data = Data()
    var newBody: HTTPBody? = body
    if let body = body {
      // Decide whether to capture based on configured cap and Content-Length.
      var willCapture = true
      if let cap = maxBytes {
        if let clString = response.headerFields[.contentLength], let contentLength = Int(clString) {
          willCapture = contentLength <= cap
        } else {
          // Unknown length with a cap: avoid collecting to prevent unbounded memory or throws.
          willCapture = false
        }
      }

      if willCapture {
        let limit = maxBytes ?? Int.max
        // Safe to collect: either unlimited or Content-Length <= limit
        data = try await Data(collecting: body, upTo: limit)
        newBody = HTTPBody(data)
      }
    }

    if let storage = AuthProxyCapturedResponse.storage {
      storage.last = CapturedHTTPResponse(
        statusCode: response.status.code,
        headers: response.headerFields,
        body: data
      )
    }

    return (response, newBody)
  }
}
