// Generated using Sourcery 2.2.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT






Components.Schemas.GetWhoamiRequest(organizationId: organizationId

    public func getWhoami(organizationId: String) async throws -> Operations.GetWhoami.Output {
        let input = Operations.GetWhoami.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.GetWhoamiRequest(organizationId: organizationId)
        )
        return try await underlyingClient.GetWhoami(input)
    }
