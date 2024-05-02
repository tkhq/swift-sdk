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
        print("Body: \(body)")
        bodyString = try await String(collecting: body, upTo: maxBytes)
        print("Body String: \(bodyString)")
        let (stampHeaderName, stampHeaderValue) = try await stamper.stamp(payload: bodyString)
        print("Stamp header name: \(stampHeaderName), value: \(stampHeaderValue)")
        // Create and append the stamp header
        let stampHeader = HTTPField(name: HTTPField.Name(stampHeaderName)!, value: stampHeaderValue)
        request.headerFields.append(stampHeader)
      }
      curlCommand = generateCurlCommand(
        request: request, body: bodyString, baseURL: baseURL, operationID: operationID)
      return try await next(request, body, baseURL)
    } catch {
      // Throw a custom enum error with the cURL command
      throw AuthStampError.failedToStampAndSendRequest("Failed to process request", error)
    }
  }
}

func generateCurlCommand(
  request: HTTPRequest,
  body: String,
  baseURL: URL,
  operationID: String
) -> String {
  var curlCommand = "curl -X \(request.method.rawValue) \\\n"
  curlCommand += "  '\(baseURL.appendingPathComponent(request.path!))' \\\n"

  for header in request.headerFields {
    curlCommand += "  -H '\(header.name): \(header.value)' \\\n"
  }

  if !body.isEmpty {
    curlCommand += "  -d '\(body)'"
  }

  print("cURL command: \(curlCommand)")
  return curlCommand
}
