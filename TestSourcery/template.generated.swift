// Generated using Sourcery 2.2.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// sourcery:file:Generated/Client+Lowercased.swift
import Foundation
import OpenAPIRuntime
import HTTPTypes

/// Review our [API Introduction](../api-introduction) to get started.
public struct Client {
    private let originalClient: TurnkeySDK.Client
    public init(
        serverURL: Foundation.URL,
        configuration: TurnkeySDK.Client.Configuration = .init(),
        transport: any ClientTransport,
        middlewares: [any ClientMiddleware] = []
    ) {
        self.originalClient = TurnkeySDK.Client(
            serverURL: serverURL, 
            configuration: configuration,
            transport: transport,
            middlewares: middlewares
        )
    }

    /// 
    ///
    /// - Remark: HTTP ``.
    public func getWhoami(_ input: Operations.GetWhoami.Input)() async throws -> Operations.GetWhoami.Output {
        let input = Operations.GetWhoami.Output()
        return try await originalClient.GetWhoami(_ input: Operations.GetWhoami.Input)(input)
    }
}
