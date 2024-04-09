// The Swift Programming Language
// https://docs.swift.org/swift-book

import OpenAPIRuntime
import OpenAPIURLSession
import Foundation

/// A hand-written Swift API for the greeting service, one that doesn't leak any generated code.
public struct TurnkeyClient {

    /// The underlying generated client to make HTTP requests to GreetingService.
    private let underlyingClient: any APIProtocol

    /// An internal initializer used by other initializers and by tests.
    /// - Parameter underlyingClient: The client to use to make HTTP requests.
    internal init(underlyingClient: any APIProtocol) { self.underlyingClient = underlyingClient }

    /// Creates a new client for GreetingService.
    public init() {
        self.init(
            underlyingClient: Client(
                serverURL: URL(string: "https://api.turnkey.com")!,
                transport: URLSessionTransport()
            )
        )
    }

    public func getWhoami(organizationId: String) async throws -> Operations.GetWhoami.Output {
        let input = Operations.GetWhoami.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.GetWhoamiRequest(organizationId: organizationId))
        )
        return try await underlyingClient.GetWhoami(input)
    }
}