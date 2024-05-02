import CryptoKit
import Foundation
import HTTPTypes
import OpenAPIRuntime
import Shared

package struct AuthStampMiddleware {
  private let stamper: Stamper

  package init(stamper: Stamper) {
    self.stamper = stamper
  }
}
// Define an enum for custom errors
enum AuthStampError: Error {
  case failedToStampAndSendRequest(String, Error)  // Includes message and cURL command
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
    var curlCommand = ""
    do {
      if let body = body {

        bodyString = try await String(collecting: body, upTo: maxBytes)

        let (stampHeaderName, stampHeaderValue) = try await stamper.stamp(payload: bodyString)

        // Create and append the stamp header
        let stampHeader = HTTPField(name: HTTPField.Name(stampHeaderName)!, value: stampHeaderValue)
        request.headerFields.append(stampHeader)
      }

      return try await next(request, body, baseURL)
    } catch {
      // Throw a custom enum error with the cURL command
      throw AuthStampError.failedToStampAndSendRequest("Failed to process request", error)
    }
  }
}
