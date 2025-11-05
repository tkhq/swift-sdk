import Foundation
import TurnkeyTypes
import AuthenticationServices
import CryptoKit
import Security

extension TurnkeyContext {
    
    /// Builds an OAuth URL for initiating a login or signup flow.
    ///
    /// Constructs a fully encoded OAuth URL for the given provider,
    /// including client ID, redirect URI, nonce, and optional additional state parameters.
    ///
    /// - Parameters:
    ///   - provider: The OAuth provider name (e.g., "google", "apple", "x", "discord").
    ///   - clientId: The client identifier registered with the OAuth provider.
    ///   - redirectUri: The redirect URI used for callback.
    ///   - nonce: A unique nonce value to include in the request.
    ///   - additionalState: Optional additional key–value pairs to append as state.
    ///
    /// - Returns: A fully constructed OAuth request `URL`.
    ///
    /// - Throws: `TurnkeySwiftError.oauthInvalidURL` if the final URL cannot be created.
    internal func buildOAuthURL(
        provider: String,
        clientId: String,
        redirectUri: String,
        nonce: String,
        additionalState: [String: String]?
    ) throws -> URL {
        let finalOriginUri = Constants.Turnkey.oauthOriginUrl
        // Encode nested redirectUri like encodeURIComponent
        let allowedUnreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        let encodedRedirectUri = redirectUri.addingPercentEncoding(withAllowedCharacters: allowedUnreserved) ?? redirectUri
        
        var comps = URLComponents(string: finalOriginUri)!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "provider",    value: provider),
            URLQueryItem(name: "clientId",    value: clientId),
            URLQueryItem(name: "redirectUri", value: encodedRedirectUri),
            URLQueryItem(name: "nonce",       value: nonce)
        ]
        if let state = additionalState, !state.isEmpty {
            for (k, v) in state {
                let ev = v.addingPercentEncoding(withAllowedCharacters: allowedUnreserved) ?? v
                items.append(URLQueryItem(name: k, value: ev))
            }
        }
        comps.percentEncodedQueryItems = items
        guard let url = comps.url else { throw TurnkeySwiftError.oauthInvalidURL }
        return url
    }
    
    /// Runs an OAuth session and retrieves the OIDC token.
    ///
    /// Opens a system browser using `ASWebAuthenticationSession` to complete an OAuth flow,
    /// then extracts and returns the `id_token` (OIDC token) from the redirect URL upon successful authentication.
    ///
    /// - Parameters:
    ///   - provider: The OAuth provider name (e.g., `"google"`, `"discord"`).
    ///   - clientId: The OAuth client ID associated with the provider.
    ///   - scheme: The callback scheme used for redirect handling.
    ///   - anchor: The presentation anchor for the authentication session.
    ///   - nonce: A unique nonce value used to validate the OAuth response.
    ///   - additionalState: Optional additional state parameters appended to the OAuth request.
    ///
    /// - Returns: The OIDC token (`id_token`) returned by the OAuth provider.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.failedToRetrieveOAuthCredential` if the OAuth flow fails or is cancelled.
    ///   - `TurnkeySwiftError.oauthMissingIDToken` if the redirect URL does not include an `id_token`.
    internal func runOAuthSession(
        provider: String,
        clientId: String,
        scheme: String,
        anchor: ASPresentationAnchor,
        nonce: String,
        additionalState: [String: String]? = nil
    ) async throws -> String {
        self.oauthAnchor = anchor
        let settings = try getOAuthProviderSettings(provider: provider)
        let url = try buildOAuthURL(
            provider: provider,
            clientId: clientId,
            redirectUri: settings.redirectUri,
            nonce: nonce,
            additionalState: additionalState
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: scheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: TurnkeySwiftError.failedToRetrieveOAuthCredential(type: .oidcToken, underlying: error))
                    return
                }
                guard
                    let callbackURL,
                    let comps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                    let idToken = comps.queryItems?.first(where: { $0.name == "id_token" })?.value
                else {
                    continuation.resume(throwing: TurnkeySwiftError.oauthMissingIDToken)
                    return
                }
                continuation.resume(returning: idToken)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }
    
    /// Generates a PKCE verifier and challenge pair.
    ///
    /// Produces a cryptographically secure random verifier and its corresponding SHA-256 challenge
    /// encoded in Base64URL format, compliant with RFC 7636.
    ///
    /// - Returns: A tuple containing the `verifier` and `challenge` strings.
    ///
    /// - Throws: `TurnkeySwiftError.keyGenerationFailed` if secure random byte generation fails.
    internal func generatePKCEPair() throws -> (verifier: String, challenge: String) {
        var randomBytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if status != errSecSuccess {
            throw TurnkeySwiftError.keyGenerationFailed(NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
        }
        let verifierData = Data(randomBytes)
        let verifier = verifierData
            .base64EncodedString(options: [])
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let challengeData = Data(SHA256.hash(data: Data(verifier.utf8)))
        let challenge = challengeData
            .base64EncodedString(options: [])
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return (verifier: verifier, challenge: challenge)
    }
    
    /// Builds an OAuth 2.0 authorization URL using the PKCE flow.
    ///
    /// Constructs a compliant authorization URL including PKCE parameters such as
    /// `code_challenge` and `code_challenge_method`, used for exchanging an auth code later.
    ///
    /// - Parameters:
    ///   - baseURL: The OAuth authorization endpoint.
    ///   - clientId: The client identifier.
    ///   - redirectUri: The redirect URI registered for the client.
    ///   - codeChallenge: The PKCE challenge derived from the verifier.
    ///   - scope: The OAuth scope to request.
    ///   - state: A unique string used to verify request integrity.
    ///
    /// - Returns: A fully composed authorization `URL`.
    ///
    /// - Throws: `TurnkeySwiftError.oauthInvalidURL` if URL construction fails.
    internal func buildOAuth2AuthURL(
        baseURL: String,
        clientId: String,
        redirectUri: String,
        codeChallenge: String,
        scope: String,
        state: String
    ) throws -> URL {
        guard var comps = URLComponents(string: baseURL) else { throw TurnkeySwiftError.oauthInvalidURL }
        comps.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: state)
        ]
        guard let url = comps.url else { throw TurnkeySwiftError.oauthInvalidURL }
        return url
    }
    
    /// Runs an OAuth 2.0 authorization code session.
    ///
    /// Launches a browser session using `ASWebAuthenticationSession` and waits for
    /// a redirect containing an authorization code and optional state.
    ///
    /// - Parameters:
    ///   - url: The authorization URL to open.
    ///   - scheme: The callback scheme for the redirect URI.
    ///   - anchor: The presentation anchor for the browser session.
    ///
    /// - Returns: A tuple containing the `authorization code` and optional `state` string.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.failedToRetrieveOAuthCredential` if the session fails.
    ///   - `TurnkeySwiftError.invalidResponse` if the callback URL or code is missing.
    internal func runOAuth2CodeSession(
        url: URL,
        scheme: String,
        anchor: ASPresentationAnchor
    ) async throws -> (code: String, state: String?) {
        self.oauthAnchor = anchor
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: scheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: TurnkeySwiftError.failedToRetrieveOAuthCredential(type: .authCode, underlying: error))
                    return
                }
                guard
                    let callbackURL,
                    let comps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
                else {
                    continuation.resume(throwing: TurnkeySwiftError.invalidResponse)
                    return
                }
                let code = comps.queryItems?.first(where: { $0.name == "code" })?.value
                let state = comps.queryItems?.first(where: { $0.name == "state" })?.value
                guard let code else {
                    continuation.resume(throwing: TurnkeySwiftError.invalidResponse)
                    return
                }
                continuation.resume(returning: (code: code, state: state))
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }
    
    /// Resolves OAuth provider configuration for the given provider.
    ///
    /// Uses runtime and user configuration to determine client ID, redirect URI,
    /// and app scheme for a specific OAuth provider.
    ///
    /// - Parameter provider: The provider identifier (e.g., "google", "apple", "x", "discord").
    /// - Returns: A tuple containing the resolved `clientId`, `redirectUri`, and `appScheme`.
    ///
    /// - Throws: Never directly, but may return empty values if configuration is incomplete.
    internal func getOAuthProviderSettings(provider: String) throws -> (clientId: String, redirectUri: String, appScheme: String) {
        let providerInfo = runtimeConfig?.auth.oauth.providers[provider]
        let clientId = providerInfo?.clientId ?? ""
        let appScheme = runtimeConfig?.auth.oauth.appScheme ?? ""
        let redirectBase = runtimeConfig?.auth.oauth.redirectBaseUrl ?? Constants.Turnkey.oauthRedirectUrl
        let redirectUri = (providerInfo?.redirectUri?.isEmpty == false)
        ? (providerInfo!.redirectUri!)
        : "\(redirectBase)?scheme=\(appScheme)"
        
        return (clientId: clientId, redirectUri: redirectUri, appScheme: appScheme)
    }
}
