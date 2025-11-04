import Foundation
import TurnkeyTypes
import AuthenticationServices
import CryptoKit
import Security

extension TurnkeyContext {
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
    
    internal func runOAuthSession(
        provider: String,
        clientId: String,
        scheme: String,
        anchor: ASPresentationAnchor,
        nonce: String,
        additionalState: [String: String]? = nil
    ) async throws -> OAuthCallbackParams {
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
                let sessionKey = comps.queryItems?.first(where: { $0.name == "sessionKey" })?.value
                continuation.resume(returning: OAuthCallbackParams(oidcToken: idToken, sessionKey: sessionKey))
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }


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
    
    /// Resolves OAuth provider settings using runtime and user config.
    ///
    /// Honors per-provider redirect overrides (e.g., Discord/X defaulting to scheme://)
    /// and falls back to proxy/user redirect base.
    ///
    /// - Parameter provider: The OAuth provider name (e.g., "google", "apple", "x", "discord").
    /// - Returns: A tuple containing the clientId, redirectUri, and appScheme for the provider.
    /// - Throws: Never directly, but consumers may need to handle missing configuration.
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
