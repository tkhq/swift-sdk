import Foundation
import TurnkeyAuthProxy

extension TurnkeyContext {

    /// Creates an `AuthProxyClient` configured with your organization’s Auth Proxy configuration id.
    ///
    /// - Parameters:
    ///   - configId: The Auth Proxy configuration identifier obtained from the Turnkey dashboard.
    ///   - baseUrl: Optional override for the Auth Proxy host. Defaults to the public production endpoint.
    /// - Returns: A configured `AuthProxyClient` ready to perform Auth Proxy flows.
    public func makeAuthProxyClient(
        configId: String,
        baseUrl: String = AuthProxyClient.baseURLString
    ) -> AuthProxyClient {
        AuthProxyClient(configId: configId, baseUrl: baseUrl)
    }
}
