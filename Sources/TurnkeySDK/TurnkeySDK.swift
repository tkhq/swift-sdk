import OpenAPIRuntime
import OpenAPIURLSession
import Foundation
import CryptoKit
import AuthStampMiddleware

public struct TurnkeyClientOld {
    private let underlyingClient: any APIProtocol
    private let apiPrivateKey: String
    private let apiPublicKey: String
    
    internal init(underlyingClient: any APIProtocol, apiPrivateKey: String, apiPublicKey: String) {
        self.underlyingClient = underlyingClient
        self.apiPrivateKey = apiPrivateKey
        self.apiPublicKey = apiPublicKey
    }
    public init(apiPrivateKey: String, apiPublicKey: String) {
        self.init(
            underlyingClient: Client(
                serverURL: URL(string: "https://api.turnkey.com")!,
                transport: URLSessionTransport(),
                middlewares: [AuthStampMiddleware(apiPrivateKey: apiPrivateKey, apiPublicKey: apiPublicKey)]
            ),
            apiPrivateKey: apiPrivateKey,
            apiPublicKey: apiPublicKey
        )
    }


}
