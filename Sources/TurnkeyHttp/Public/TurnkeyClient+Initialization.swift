import AuthenticationServices
import CryptoKit
import Foundation
import OpenAPIURLSession
import TurnkeyStamper

extension TurnkeyClient {
    
    /// Initializes a `TurnkeyClient` with a proxy server URL.
    ///
    /// - Parameter proxyURL: The URL of the proxy server that requests will be forwarded to.
    public init(proxyURL: String) {
        self.init(
            underlyingClient: Client(
                serverURL: URL(string: TurnkeyClient.baseURLString)!,
                transport: URLSessionTransport(),
                middlewares: [
                    ProxyMiddleware(proxyURL: URL(string: proxyURL)!)
                ]
            )
        )
    }
    
    /// Initializes a `TurnkeyClient` with an API key pair for authenticated requests.
    ///
    /// - Parameters:
    ///   - apiPrivateKey: The base64-encoded API private key.
    ///   - apiPublicKey: The base64-encoded API public key.
    ///   - baseUrl: Optional base URL (defaults to Turnkey production).
    public init(
        apiPrivateKey: String,
        apiPublicKey: String,
        baseUrl: String = TurnkeyClient.baseURLString
    ) {
        let stamper = Stamper(apiPublicKey: apiPublicKey, apiPrivateKey: apiPrivateKey)
        self.init(
            underlyingClient: Client(
                serverURL: URL(string: baseUrl)!,
                transport: URLSessionTransport(),
                middlewares: [
                    AuthStampMiddleware(stamper: stamper)
                ]
            )
        )
    }
    
    /// Initializes a `TurnkeyClient` using on-device session credentials.
    ///
    /// Assumes a valid session JWT has been stored locally.
    public init() {
        let stamper = Stamper()
        self.init(
            underlyingClient: Client(
                serverURL: URL(string: TurnkeyClient.baseURLString)!,
                transport: URLSessionTransport(),
                middlewares: [
                    AuthStampMiddleware(stamper: stamper)
                ]
            )
        )
    }
    
    /// Initializes a `TurnkeyClient` using passkeys for authentication.
    ///
    /// - Parameters:
    ///   - rpId: The Relying Party ID (must match your app's associated domain config).
    ///   - presentationAnchor: The window or view used to present authentication prompts.
    ///   - baseUrl: Optional base URL (defaults to Turnkey production).
    public init(
        rpId: String,
        presentationAnchor: ASPresentationAnchor,
        baseUrl: String = TurnkeyClient.baseURLString
    ) {
        let stamper = Stamper(rpId: rpId, presentationAnchor: presentationAnchor)
        self.init(
            underlyingClient: Client(
                serverURL: URL(string: baseUrl)!,
                transport: URLSessionTransport(),
                middlewares: [
                    AuthStampMiddleware(stamper: stamper)
                ]
            )
        )
    }
}
