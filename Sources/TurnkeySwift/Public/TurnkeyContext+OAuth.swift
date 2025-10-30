import Foundation
import TurnkeyTypes
import AuthenticationServices
import CryptoKit
import TurnkeyHttp

extension TurnkeyContext: ASWebAuthenticationPresentationContextProviding {
    // MARK: - Public Types (OAuth)
    
    public struct GoogleOAuthOptions: Sendable {
        public var clientId: String?
        public var additionalState: [String: String]?
        public var onOAuthSuccess: ( @Sendable (OAuthSuccess) -> Void)?
        
        public init(
            clientId: String? = nil,
            additionalState: [String: String]? = nil,
            onOAuthSuccess: ( @Sendable (OAuthSuccess) -> Void)? = nil
        ) {
            self.clientId = clientId
            self.additionalState = additionalState
            self.onOAuthSuccess = onOAuthSuccess
        }
    }
    @available(*, unavailable, renamed: "GoogleOAuthOptions")
    public typealias HandleGoogleOAuthParams = GoogleOAuthOptions
    
    public struct AppleOAuthOptions: Sendable {
        public var clientId: String?
        public var additionalState: [String: String]?
        public var onOAuthSuccess: ( @Sendable (OAuthSuccess) -> Void)?
        
        public init(
            clientId: String? = nil,
            additionalState: [String: String]? = nil,
            onOAuthSuccess: ( @Sendable(OAuthSuccess) -> Void)? = nil
        ) {
            self.clientId = clientId
            self.additionalState = additionalState
            self.onOAuthSuccess = onOAuthSuccess
        }
    }
    
    public struct DiscordOAuthOptions: Sendable {
        public var clientId: String?
        public var additionalState: [String: String]?
        public var onOAuthSuccess: (@Sendable (OAuthSuccess) -> Void)?
        
        public init(
            clientId: String? = nil,
            additionalState: [String: String]? = nil,
            onOAuthSuccess: ( @Sendable(OAuthSuccess) -> Void)? = nil
        ) {
            self.clientId = clientId
            self.additionalState = additionalState
            self.onOAuthSuccess = onOAuthSuccess
        }
    }
    
    public struct XOAuthOptions: Sendable {
        public var clientId: String?
        public var additionalState: [String: String]?
        public var onOAuthSuccess: ( @Sendable (OAuthSuccess) -> Void)?
        
        public init(
            clientId: String? = nil,
            additionalState: [String: String]? = nil,
            onOAuthSuccess: (@Sendable (OAuthSuccess) -> Void)? = nil
        ) {
            self.clientId = clientId
            self.additionalState = additionalState
            self.onOAuthSuccess = onOAuthSuccess
        }
    }
    
    public struct OAuthSuccess: Sendable {
        public let oidcToken: String
        public let providerName: String
        public let publicKey: String
    }
    
    public struct OAuthCallbackParams: Sendable {
        public let oidcToken: String
        public let sessionKey: String?
    }
    
    // MARK: - Orchestrator
    
    /// Launches Google OAuth, retrieves the OIDC token, and completes Turnkey login or signup.
    public func handleGoogleOAuth(
        anchor: ASPresentationAnchor,
        params: GoogleOAuthOptions = .init()
    ) async throws -> CompleteOAuthResult {
        // Create keypair and compute nonce = sha256(publicKey)
        let publicKey = try createKeyPair()
        let nonceData = Data(publicKey.utf8)
        let nonce = SHA256.hash(data: nonceData).map { String(format: "%02x", $0) }.joined()
        
        // Resolve provider settings (clientId, redirect base URL, app scheme)
        let settings = try getOAuthProviderSettings(provider: "google")
        let clientId = params.clientId ?? settings.clientId
        let scheme = settings.appScheme
        
        guard !clientId.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration("Missing clientId for Google OAuth")
        }
        guard !scheme.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration("Missing app scheme for OAuth redirect")
        }
        
        // Start OAuth in system browser and obtain Google-issued id_token (+ optional sessionKey)
        let oauth = try await runOAuthSession(
            provider: "google",
            clientId: clientId,
            scheme: scheme,
            anchor: anchor,
            nonce: nonce,
            additionalState: params.additionalState
        )
        
        // Optional early callback (parity with TS onOAuthSuccess)
        if let cb = params.onOAuthSuccess {
            cb(.init(oidcToken: oauth.oidcToken, providerName: "google", publicKey: publicKey))
            // In early-return mode caller handles completion.
            return .init(session: "", action: .login)
        }
        
        // Complete OAuth inside SDK (lookup → login or signup)
        return try await completeOAuth(
            oidcToken: oauth.oidcToken,
            publicKey: publicKey,
            providerName: "google",
            sessionKey: oauth.sessionKey
        )
    }
    
    /// Launches Apple OAuth, retrieves the OIDC token, and completes Turnkey login or signup.
    public func handleAppleOAuth(
        anchor: ASPresentationAnchor,
        params: AppleOAuthOptions = .init()
    ) async throws -> CompleteOAuthResult {
        // Create keypair and compute nonce = sha256(publicKey)
        let publicKey = try createKeyPair()
        let nonceData = Data(publicKey.utf8)
        let nonce = SHA256.hash(data: nonceData).map { String(format: "%02x", $0) }.joined()
        
        // Resolve provider settings (clientId, redirect base URL, app scheme)
        let settings = try getOAuthProviderSettings(provider: "apple")
        let clientId = params.clientId ?? settings.clientId
        let scheme = settings.appScheme
        
        guard !clientId.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration("Missing clientId for Apple OAuth")
        }
        guard !scheme.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration("Missing app scheme for OAuth redirect")
        }
        
        // Start OAuth in system browser and obtain Apple-issued id_token (+ optional sessionKey)
        let oauth = try await runOAuthSession(
            provider: "apple",
            clientId: clientId,
            scheme: scheme,
            anchor: anchor,
            nonce: nonce,
            additionalState: params.additionalState
        )
        
        // Optional early callback (parity with TS onOAuthSuccess)
        if let cb = params.onOAuthSuccess {
            cb(.init(oidcToken: oauth.oidcToken, providerName: "apple", publicKey: publicKey))
            // In early-return mode caller handles completion.
            return .init(session: "", action: .login)
        }
        
        // Complete OAuth inside SDK (lookup → login or signup)
        return try await completeOAuth(
            oidcToken: oauth.oidcToken,
            publicKey: publicKey,
            providerName: "apple",
            sessionKey: oauth.sessionKey
        )
    }
    
    /// Launches Discord OAuth (PKCE), exchanges the code via Auth Proxy, and completes login/signup.
    public func handleDiscordOAuth(
        anchor: ASPresentationAnchor,
        params: DiscordOAuthOptions = .init()
    ) async throws -> CompleteOAuthResult {
        // Create keypair and compute nonce = sha256(publicKey)
        let publicKey = try createKeyPair()
        let nonceData = Data(publicKey.utf8)
        let nonce = SHA256.hash(data: nonceData).map { String(format: "%02x", $0) }.joined()
        
        // Resolve provider settings
        let settings = try getOAuthProviderSettings(provider: "discord")
        let clientId = params.clientId ?? settings.clientId
        let redirectUri = settings.redirectUri
        let scheme = settings.appScheme
        
        guard !clientId.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration("Missing clientId for Discord OAuth")
        }
        guard !redirectUri.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration("Missing redirectUri for OAuth")
        }
        guard !scheme.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration("Missing app scheme for OAuth redirect")
        }
        
        // Generate PKCE pair
        let pkce = try generatePKCEPair()
        
        // Build state
        var state = "provider=discord&flow=redirect&publicKey=\(publicKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? publicKey)&nonce=\(nonce)"
        if let additional = params.additionalState, !additional.isEmpty {
            let extra = additional
                .map { key, value in
                    let k = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                    let v = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                    return "\(k)=\(v)"
                }
                .joined(separator: "&")
            if !extra.isEmpty { state += "&\(extra)" }
        }
        
        // Build provider auth URL
        let discordAuthUrl = try buildOAuth2AuthURL(
            baseURL: "https://discord.com/oauth2/authorize",
            clientId: clientId,
            redirectUri: redirectUri,
            codeChallenge: pkce.challenge,
            scope: "identify email",
            state: state
        )
        
        // Run system web auth to retrieve authorization code and state
        let result = try await runOAuth2CodeSession(url: discordAuthUrl, scheme: scheme, anchor: anchor)
        guard let client = client else { throw TurnkeySwiftError.invalidSession }
        
        // Exchange code for OIDC token via Auth Proxy
        let resp = try await client.proxyOAuth2Authenticate(ProxyTOAuth2AuthenticateBody(
            authCode: result.code,
            clientId: clientId,
            codeVerifier: pkce.verifier,
            nonce: nonce,
            provider: .oauth2_provider_discord,
            redirectUri: redirectUri
        ))
        
        let oidcToken = resp.oidcToken
        let sessionKey = parseSessionKey(fromState: result.state)
        
        if let cb = params.onOAuthSuccess {
            cb(.init(oidcToken: oidcToken, providerName: "discord", publicKey: publicKey))
            return .init(session: "", action: .login)
        }
        
        return try await completeOAuth(
            oidcToken: oidcToken,
            publicKey: publicKey,
            providerName: "discord",
            sessionKey: sessionKey
        )
    }
    
    /// Launches X (Twitter) OAuth (PKCE), exchanges the code via Auth Proxy, and completes login/signup.
    public func handleXOauth(
        anchor: ASPresentationAnchor,
        params: XOAuthOptions = .init()
    ) async throws -> CompleteOAuthResult {
        // Create keypair and compute nonce = sha256(publicKey)
        let publicKey = try createKeyPair()
        let nonceData = Data(publicKey.utf8)
        let nonce = SHA256.hash(data: nonceData).map { String(format: "%02x", $0) }.joined()
        
        // Resolve provider settings
        let settings = try getOAuthProviderSettings(provider: "x")
        let clientId = params.clientId ?? settings.clientId
        let redirectUri = settings.redirectUri
        let scheme = settings.appScheme
        
        guard !clientId.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration("Missing clientId for X OAuth")
        }
        guard !redirectUri.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration("Missing redirectUri for OAuth")
        }
        guard !scheme.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration("Missing app scheme for OAuth redirect")
        }
        
        // Generate PKCE pair
        let pkce = try generatePKCEPair()
        
        // Build state (RN uses provider=twitter)
        var state = "provider=twitter&flow=redirect&publicKey=\(publicKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? publicKey)&nonce=\(nonce)"
        if let additional = params.additionalState, !additional.isEmpty {
            let extra = additional
                .map { key, value in
                    let k = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                    let v = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                    return "\(k)=\(v)"
                }
                .joined(separator: "&")
            if !extra.isEmpty { state += "&\(extra)" }
        }
        
        // Build provider auth URL
        let xAuthUrl = try buildOAuth2AuthURL(
            baseURL: "https://x.com/i/oauth2/authorize",
            clientId: clientId,
            redirectUri: redirectUri,
            codeChallenge: pkce.challenge,
            scope: "tweet.read users.read",
            state: state
        )
        
        // Run system web auth to retrieve authorization code and state
        let result = try await runOAuth2CodeSession(url: xAuthUrl, scheme: scheme, anchor: anchor)
        guard let client = client else { throw TurnkeySwiftError.invalidSession }
        
        // Exchange code for OIDC token via Auth Proxy
        let resp = try await client.proxyOAuth2Authenticate(ProxyTOAuth2AuthenticateBody(
            authCode: result.code,
            clientId: clientId,
            codeVerifier: pkce.verifier,
            nonce: nonce,
            provider: .oauth2_provider_x,
            redirectUri: redirectUri
        ))
        
        let oidcToken = resp.oidcToken
        let sessionKey = parseSessionKey(fromState: result.state)
        
        if let cb = params.onOAuthSuccess {
            cb(.init(oidcToken: oidcToken, providerName: "twitter", publicKey: publicKey))
            return .init(session: "", action: .login)
        }
        
        return try await completeOAuth(
            oidcToken: oidcToken,
            publicKey: publicKey,
            providerName: "twitter",
            sessionKey: sessionKey
        )
    }
    
    // MARK: - Deprecated public starter (use handleGoogleOAuth)
    /// Launches the Google OAuth flow and returns the OIDC token.
    ///
    /// - Parameters:
    ///   - clientId: The Google OAuth client ID.
    ///   - nonce: A unique string (must be `sha256(publicKey)`).
    ///   - scheme: The URL scheme used to return from the system browser.
    ///   - anchor: The presentation anchor for the authentication session.
    ///   - originUri: Optional override for the OAuth origin URL.
    ///   - redirectUri: Optional override for the OAuth redirect URL.
    ///
    /// - Returns: A valid Google-issued OIDC token.
    ///
    /// - Throws: `TurnkeySwiftError.oauthInvalidURL` if URL building fails,
    ///           `TurnkeySwiftError.oauthMissingIDToken` if token is not returned,
    ///           or `TurnkeySwiftError.oauthFailed` if the system session fails.
    @available(*, deprecated, message: "Use handleGoogleOAuth(anchor:params:) instead")
    public func startGoogleOAuthFlow(
        clientId: String,
        nonce: String,
        scheme: String,
        anchor: ASPresentationAnchor,
        originUri: String? = nil,
        redirectUri: String? = nil,
        additionalState: [String: String]? = nil
    ) async throws -> String {
        let result = try await runOAuthSession(
            provider: "google",
            clientId: clientId,
            scheme: scheme,
            anchor: anchor,
            nonce: nonce,
            additionalState: additionalState
        )
        return result.oidcToken
    }
    
    // MARK: - Internal helpers
    private func buildOAuthURL(
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
                    continuation.resume(throwing: TurnkeySwiftError.oauthFailed(underlying: error))
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
    
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        oauthAnchor ?? ASPresentationAnchor()
    }
}
