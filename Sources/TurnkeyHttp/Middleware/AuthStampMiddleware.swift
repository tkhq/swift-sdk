import CryptoKit
import Foundation
import HTTPTypes
import OpenAPIRuntime
import TurnkeyStamper

enum AuthStampError: Error {
    case failedToStampAndSendRequest(error: Error)
}

extension AuthStampError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .failedToStampAndSendRequest(let error):
            return "Failed to stamp and send request: \(error.localizedDescription)"
        }
    }
}

package struct AuthStampMiddleware {
    private let stamper: Stamper
    
    package init(stamper: Stamper) {
        self.stamper = stamper
    }
}

extension AuthStampMiddleware: ClientMiddleware {
    
    /// Intercepts an outgoing HTTP request, stamps its body using the `Stamper`, and adds a custom header.
    ///
    /// - Parameters:
    ///   - request: The original HTTP request.
    ///   - body: The request body, if present.
    ///   - baseURL: The base URL of the API.
    ///   - operationID: The operation ID defined by OpenAPI.
    ///   - next: The next middleware or transport to call.
    /// - Returns: A tuple of HTTP response and optional body.
    /// - Throws: `AuthStampError` if stamping or request forwarding fails.
    package func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        let maxBytes = 1_000_000
        
        do {
            if let body = body {
                let bodyString = try await String(collecting: body, upTo: maxBytes)
                let (stampHeaderName, stampHeaderValue) = try await stamper.stamp(payload: bodyString)
                
                let stampHeader = HTTPField(
                    name: HTTPField.Name(stampHeaderName)!,
                    value: stampHeaderValue
                )
                request.headerFields.append(stampHeader)
            }
            
            return try await next(request, body, baseURL)
            
        } catch {
            throw AuthStampError.failedToStampAndSendRequest(error: error)
        }
    }
}
