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
    // Create a dictionary to hold the proxy request data
    var proxyRequestData: [String: Any] = [:]

    // Set the request headers
    var headers: [String: String] = [:]
    for header in request.headerFields {
      headers[header.name.rawValue] = header.value
    }
    proxyRequestData["headers"] = headers

    // Set the request body
    if let body = body {
      let bodyData = try await body.collect()
      proxyRequestData["body"] = String(data: bodyData, encoding: .utf8)
    }

    // Set the destination URL
    let destinationURL = baseURL.appendingPathComponent(request.path).absoluteString
    proxyRequestData["destinationURL"] = destinationURL

    // Convert the proxy request data to JSON
    let jsonData = try JSONSerialization.data(withJSONObject: proxyRequestData, options: [])

    // Create a new URL request with the proxy URL
    var proxyRequest = URLRequest(url: proxyURL)
    proxyRequest.httpMethod = "POST"
    proxyRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    proxyRequest.httpBody = jsonData

    // Send the proxied request
    let (data, urlResponse) = try await URLSession.shared.data(for: proxyRequest)

    // Create an HTTPResponse from the URL response
    let httpResponse = HTTPResponse(
      status: HTTPResponseStatus(rawValue: (urlResponse as? HTTPURLResponse)?.statusCode ?? 500)!,
      version: request.version,
      headerFields: HTTPFields(
        urlResponse.allHeaderFields.map {
          HTTPField(name: HTTPField.Name($0.key)!, value: "\($0.value)")
        }),
      body: data
    )

    return (httpResponse, nil)
  }
}
