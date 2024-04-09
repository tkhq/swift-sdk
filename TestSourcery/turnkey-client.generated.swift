// Generated using Sourcery 2.2.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
import OpenAPIRuntime
import OpenAPIURLSession
import Foundation

public struct TurnkeyClient {
    private let underlyingClient: Client

    internal init(underlyingClient: Client) {
        self.underlyingClient = underlyingClient
    }

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
            body: .json(Components.Schemas.GetWhoamiRequest(organizationId: organizationId)
        )
        return try await underlyingClient.GetWhoami(input)
    }
}