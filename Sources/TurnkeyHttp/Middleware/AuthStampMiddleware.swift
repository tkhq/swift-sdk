import CryptoKit
import Foundation
import HTTPTypes
import OpenAPIRuntime
import TurnkeyStamper

package struct AuthStampMiddleware {
  private let stamper: Stamper

  package init(stamper: Stamper) {
    self.stamper = stamper
  }
}

enum AuthStampError: Error {
  case failedToStampAndSendRequest(String, Error)
}

extension AuthStampMiddleware: ClientMiddleware {
  package func intercept(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String,
    next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
  ) async throws -> (HTTPResponse, HTTPBody?) {
    var request = request

    // Define the maximum number of bytes you're willing to collect
    let maxBytes = 1_000_000

    var bodyString = ""
    do {
      if let body = body {
        bodyString = try await String(collecting: body, upTo: maxBytes)

        let (stampHeaderName, stampHeaderValue) = try await stamper.stamp(payload: bodyString)

        let stampHeader = HTTPField(name: HTTPField.Name(stampHeaderName)!, value: stampHeaderValue)
        request.headerFields.append(stampHeader)
      }

      return try await next(request, body, baseURL)
    } catch {
      throw AuthStampError.failedToStampAndSendRequest("Failed to process request", error)
    }
  }
}
