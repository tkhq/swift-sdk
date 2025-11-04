import Foundation
import TurnkeyTypes
import AuthenticationServices
import CryptoKit
import TurnkeyHttp

extension TurnkeyContext: ASWebAuthenticationPresentationContextProviding {
    
    /// Logs in an existing user via OAuth using the provided OIDC token and public key.
    ///
    /// Performs a proxy OAuth login, creates a session, and returns the resulting session token.
    ///
    /// - Parameters:
    ///   - oidcToken: The OIDC token returned from the OAuth provider.
    ///   - publicKey: The public key bound to the login session. This key is required because it is directly
    ///                tied to the nonce used during OIDC token generation and must match the value
    ///                encoded in the token.
    ///   -  organizationId: Optional organization ID if known.
    ///   - invalidateExisting: Whether to invalidate any existing session (defaults to `false`).
    ///   - sessionKey: Optional session key to associate with the login.
    ///
    /// - Returns: A `BaseAuthResult` containing the created session.
    ///
    /// - Throws: `TurnkeySwiftError.missingAuthProxyConfiguration` if no client is configured,
    ///           or `TurnkeySwiftError.failedToLoginWithOAuth` if login fails.
    internal func loginWithOAuth(
        oidcToken: String,
        publicKey: String,
        organizationId: String? = nil,
        invalidateExisting: Bool = false,
        sessionKey: String? = nil,
    ) async throws -> BaseAuthResult {
        guard let client = client else {
            throw TurnkeySwiftError.missingAuthProxyConfiguration
        }
        
        do {
            let response = try await client.proxyOAuthLogin(ProxyTOAuthLoginBody(
                invalidateExisting: invalidateExisting,
                oidcToken: oidcToken,
                organizationId: organizationId,
                publicKey: publicKey
            ))
            let session = response.session
            try await storeSession(jwt: session, sessionKey: sessionKey)
            return BaseAuthResult(session: session)
        } catch {
            throw TurnkeySwiftError.failedToLoginWithOAuth(underlying: error)
        }
    }
    
    /// Signs up a new sub-organization and user via OAuth, then performs login.
    ///
    /// Adds the OAuth provider details to the sub-organization parameters,
    /// executes the signup request, and logs in using the same OIDC token.
    ///
    /// - Parameters:
    ///   - oidcToken: The OIDC token returned from the OAuth provider.
    ///   - publicKey: The public key bound to the login session. This key is required because it is directly
    ///                tied to the nonce used during OIDC token generation and must match the value
    ///                encoded in the token.
    ///   - providerName: The OAuth provider name (defaults to `"OpenID Connect Provider <timestamp>"`).
    ///   - createSubOrgParams: Optional parameters for sub-organization creation.
    ///   - invalidateExisting: Whether to invalidate any existing session (defaults to `false`).
    ///   - sessionKey: Optional session key to associate with the signup.
    ///
    /// - Returns: A `BaseAuthResult` containing the created session.
    ///
    /// - Throws: `TurnkeySwiftError.missingAuthProxyConfiguration` if no client is configured,
    ///           or `TurnkeySwiftError.failedToSignUpWithOAuth` if signup or login fails.
    internal func signUpWithOAuth(
        oidcToken: String,
        publicKey: String,
        providerName: String?,
        createSubOrgParams: CreateSubOrgParams? = nil,
        invalidateExisting: Bool = false,
        sessionKey: String? = nil
    ) async throws -> BaseAuthResult {
        guard let client = client else {
            throw TurnkeySwiftError.missingAuthProxyConfiguration
        }
        
        do {
            var merged = createSubOrgParams ?? CreateSubOrgParams()
            
            let resolvedProviderName = providerName ?? "OpenID Connect Provider \(Int(Date().timeIntervalSince1970))"
            var oauthProviders = merged.oauthProviders ?? []
            oauthProviders.append(.init(providerName: resolvedProviderName, oidcToken: oidcToken))
            merged.oauthProviders = oauthProviders
            
            let signupBody = buildSignUpBody(createSubOrgParams: merged)
            let res = try await client.proxySignup(signupBody)
            _ = res.organizationId
            
            // after signing up we login
            return try await loginWithOAuth(
                oidcToken: oidcToken,
                publicKey: publicKey,
                invalidateExisting: invalidateExisting,
                sessionKey: sessionKey
            )
        } catch {
            throw TurnkeySwiftError.failedToSignUpWithOAuth(underlying: error)
        }
    }
    
    /// Completes the OAuth flow by checking for an existing account and performing login or signup.
    ///
    /// Looks up the account using the OIDC token; if an organization exists, logs in,
    /// otherwise creates a new sub-organization and completes signup.
    ///
    /// - Parameters:
    ///   - oidcToken: The OIDC token returned from the OAuth provider.
    ///   - publicKey: The public key bound to the session.
    ///   - providerName: The OAuth provider name (defaults to `"OpenID Connect Provider <timestamp>"`).
    ///   - invalidateExisting: Whether to invalidate any existing session (defaults to `false`).
    ///   - createSubOrgParams: Optional parameters for sub-organization creation.
    ///   - sessionKey: Optional session key returned from the OAuth redirect.
    ///
    /// - Returns: A `CompleteOAuthResult` describing whether a login or signup occurred.
    ///
    /// - Throws: `TurnkeySwiftError.missingAuthProxyConfiguration` if no client is configured,
    ///           or `TurnkeySwiftError.failedToCompleteOAuth` if the operation fails.
    public func completeOAuth(
        oidcToken: String,
        publicKey: String,
        providerName: String? = nil,
        invalidateExisting: Bool = false,
        createSubOrgParams: CreateSubOrgParams? = nil,
        sessionKey: String? = nil
    ) async throws -> CompleteOAuthResult {
        guard let client = client else {
            throw TurnkeySwiftError.missingAuthProxyConfiguration
        }
        
        do {
            let account = try await client.proxyGetAccount(ProxyTGetAccountBody(
                filterType: "OIDC_TOKEN",
                filterValue: oidcToken
            ))
            
            if let organizationId = account.organizationId, !organizationId.isEmpty {
                
                let result = try await loginWithOAuth(
                    oidcToken: oidcToken,
                    publicKey: publicKey,
                    organizationId: organizationId,
                    invalidateExisting: invalidateExisting,
                    sessionKey: sessionKey
                )
                return CompleteOAuthResult(session: result.session, action: .login)
            } else {
                let result = try await signUpWithOAuth(
                    oidcToken: oidcToken,
                    publicKey: publicKey,
                    providerName: providerName,
                    createSubOrgParams: createSubOrgParams,
                    invalidateExisting: invalidateExisting,
                    sessionKey: sessionKey
                )
                return CompleteOAuthResult(session: result.session, action: .signup)
            }
        } catch {
            throw TurnkeySwiftError.failedToCompleteOAuth(underlying: error)
        }
    }
    
    /// Launches the Google OAuth flow, retrieves the OIDC token, and completes login or signup.
    ///
    /// Starts the OAuth flow in the system browser, handles the redirect response,
    /// and either returns early via `onOAuthSuccess` or completes authentication internally.
    ///
    /// - Parameters:
    ///   - anchor: The presentation anchor for the OAuth web session.
    ///   - clientId: Optional Google OAuth client ID override.
    ///   - additionalState: Optional key-value pairs appended to the OAuth request state.
    ///   - onOAuthSuccess: Optional callback invoked with the OIDC token and public key before auto-login.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidConfiguration` if required provider settings are missing.
    ///   - `TurnkeySwiftError.failedToRetrieveOAuthCredential` if the OAuth session fails.
    ///   - `TurnkeySwiftError.failedToCompleteOAuth` if login or signup via Auth Proxy fails.
    public func handleGoogleOAuth(
        anchor: ASPresentationAnchor,
        clientId: String? = nil,
        additionalState: [String: String]? = nil,
        onOAuthSuccess: (@Sendable (OAuthSuccess) -> Void)? = nil
    ) async throws {
        
        // we create a keypair and compute the nonce based on the publicKey
        let publicKey = try createKeyPair()
        let nonceData = Data(publicKey.utf8)
        let nonce = SHA256.hash(data: nonceData).map { String(format: "%02x", $0) }.joined()
        
        // we resolve the provider settings
        let settings = try getOAuthProviderSettings(provider: "google")
        let clientId = clientId ?? settings.clientId
        let scheme = settings.appScheme
        
        guard !clientId.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration("Missing clientId for Google OAuth")
        }
        guard !scheme.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration("Missing app scheme for OAuth redirect")
        }
        
        // we start OAuth flow in the system browser and get an oidcToken
        let oauth = try await runOAuthSession(
            provider: "google",
            clientId: clientId,
            scheme: scheme,
            anchor: anchor,
            nonce: nonce,
            additionalState: additionalState
        )
        
        // if onOAuthSuccess was passed in then we run the callback
        // and then return early
        if let callback = onOAuthSuccess {
            callback(.init(oidcToken: oauth.oidcToken, providerName: "google", publicKey: publicKey))
            return
        }
        
        // since theres no onOAuthSuccess then we handle auth for them
        // via the authProxy
        _ = try await completeOAuth(
            oidcToken: oauth.oidcToken,
            publicKey: publicKey,
            providerName: "google",
            sessionKey: oauth.sessionKey
        )
    }
    
    /// Launches the Apple OAuth flow, retrieves the OIDC token, and completes login or signup.
    ///
    /// Starts the OAuth flow in the system browser, handles the redirect response,
    /// and either returns early via `onOAuthSuccess` or completes authentication internally.
    ///
    /// - Parameters:
    ///   - anchor: The presentation anchor for the OAuth web session.
    ///   - clientId: Optional Apple OAuth client ID override.
    ///   - additionalState: Optional key-value pairs appended to the OAuth request state.
    ///   - onOAuthSuccess: Optional callback invoked with the OIDC token and public key before auto-login.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidConfiguration` if required provider settings are missing.
    ///   - `TurnkeySwiftError.failedToRetrieveOAuthCredential` if the OAuth session fails.
    ///   - `TurnkeySwiftError.failedToCompleteOAuth` if login or signup via Auth Proxy fails.
    public func handleAppleOAuth(
        anchor: ASPresentationAnchor,
        clientId: String? = nil,
        additionalState: [String: String]? = nil,
        onOAuthSuccess: (@Sendable (OAuthSuccess) -> Void)? = nil
    ) async throws {
        // we create a keypair and compute the nonce based on the publicKey
        let publicKey = try createKeyPair()
        let nonceData = Data(publicKey.utf8)
        let nonce = SHA256.hash(data: nonceData).map { String(format: "%02x", $0) }.joined()
        
        // we resolve the provider settings
        let settings = try getOAuthProviderSettings(provider: "apple")
        let clientId = clientId ?? settings.clientId
        let scheme = settings.appScheme
        
        guard !clientId.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration("Missing clientId for Apple OAuth")
        }
        guard !scheme.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration("Missing app scheme for OAuth redirect")
        }
        
        // we start OAuth flow in the system browser and get an oidcToken
        let oauth = try await runOAuthSession(
            provider: "apple",
            clientId: clientId,
            scheme: scheme,
            anchor: anchor,
            nonce: nonce,
            additionalState: additionalState
        )
        
        // if onOAuthSuccess was passed in then we run the callback
        // and then return early
        if let callback = onOAuthSuccess {
            callback(.init(oidcToken: oauth.oidcToken, providerName: "apple", publicKey: publicKey))
            return
        }
        
        // since theres no onOAuthSuccess then we handle auth for them
        // via the authProxy
        _ = try await completeOAuth(
            oidcToken: oauth.oidcToken,
            publicKey: publicKey,
            providerName: "apple",
            sessionKey: oauth.sessionKey
        )
    }
    
    /// Launches the Discord OAuth (PKCE) flow, exchanges the authorization code via Auth Proxy,
    /// and completes login or signup using the retrieved OIDC token.
    ///
    /// Builds the OAuth request with nonce and public key, opens the system browser,
    /// exchanges the returned code, and either triggers `onOAuthSuccess` or finalizes authentication.
    ///
    /// - Parameters:
    ///   - anchor: The presentation anchor for the OAuth web session.
    ///   - clientId: Optional Discord OAuth client ID override.
    ///   - additionalState: Optional key-value pairs appended to the OAuth request state.
    ///   - onOAuthSuccess: Optional callback invoked with the OIDC token and public key before auto-login.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidConfiguration` if provider configuration is missing.
    ///   - `TurnkeySwiftError.missingAuthProxyConfiguration` if no client is configured.
    ///   - `TurnkeySwiftError.failedToRetrieveOAuthCredential` if the OAuth session fails.
    ///   - `TurnkeySwiftError.failedToCompleteOAuth` if login or signup via Auth Proxy fails.
    public func handleDiscordOAuth(
        anchor: ASPresentationAnchor,
        clientId: String? = nil,
        additionalState: [String: String]? = nil,
        onOAuthSuccess: (@Sendable (OAuthSuccess) -> Void)? = nil
    ) async throws {
        guard let client = client else {
            throw TurnkeySwiftError.missingAuthProxyConfiguration
        }
        
        // we create a keypair and compute the nonce based on the publicKey
        let publicKey = try createKeyPair()
        let nonceData = Data(publicKey.utf8)
        let nonce = SHA256.hash(data: nonceData).map { String(format: "%02x", $0) }.joined()
        
        // we resolve the provider settings
        let settings = try getOAuthProviderSettings(provider: "discord")
        let clientId = clientId ?? settings.clientId
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
        
        // we generate a verifier and challenge pair
        let pkce = try generatePKCEPair()
        
        // random state
        let state = UUID().uuidString
        
        // we build the provider auth url
        let discordAuthUrl = try buildOAuth2AuthURL(
            baseURL: "https://discord.com/oauth2/authorize",
            clientId: clientId,
            redirectUri: redirectUri,
            codeChallenge: pkce.challenge,
            scope: "identify email",
            state: state
        )
        
        // run system web auth to retrieve authorization code and state
        let oauth = try await runOAuth2CodeSession(url: discordAuthUrl, scheme: scheme, anchor: anchor)
        
        // we validate that returned state matches what we sent
        guard oauth.state == state else {
            throw TurnkeySwiftError.failedToRetrieveOAuthCredential(
                type: .authCode,
                underlying: NSError(
                    domain: "TurnkeySwiftError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "OAuth state mismatch"]
                )
            )
        }
        
        // we exchange the code for an oidcToken via the authProxy
        let resp = try await client.proxyOAuth2Authenticate(ProxyTOAuth2AuthenticateBody(
            authCode: oauth.code,
            clientId: clientId,
            codeVerifier: pkce.verifier,
            nonce: nonce,
            provider: .oauth2_provider_discord,
            redirectUri: redirectUri
        ))
        
        let oidcToken = resp.oidcToken
        
        // if onOAuthSuccess was passed in then we run the callback
        // and then return early
        if let callback = onOAuthSuccess {
            callback(.init(oidcToken: oidcToken, providerName: "discord", publicKey: publicKey))
            return
        }
        
        // since theres no onOAuthSuccess then we handle auth for them
        // via the authProxy
        _ = try await completeOAuth(
            oidcToken: oidcToken,
            publicKey: publicKey,
            providerName: "discord"
        )
    }
    
    /// Launches the X (Twitter) OAuth (PKCE) flow, exchanges the authorization code via Auth Proxy,
    /// and completes login or signup using the retrieved OIDC token.
    ///
    /// Builds the OAuth request with nonce and public key, opens the system browser,
    /// exchanges the returned code, and either triggers `onOAuthSuccess` or finalizes authentication.
    ///
    /// - Parameters:
    ///   - anchor: The presentation anchor for the OAuth web session.
    ///   - clientId: Optional X OAuth client ID override.
    ///   - sessionKey: Optional session storage key for the resulting session.
    ///   - additionalState: Optional key-value pairs appended to the OAuth request state.
    ///   - onOAuthSuccess: Optional callback invoked with the OIDC token and public key before auto-login.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidConfiguration` if provider configuration is missing.
    ///   - `TurnkeySwiftError.missingAuthProxyConfiguration` if no client is configured.
    ///   - `TurnkeySwiftError.failedToRetrieveOAuthCredential` if the OAuth session fails.
    ///   - `TurnkeySwiftError.failedToCompleteOAuth` if login or signup via Auth Proxy fails.
    public func handleXOauth(
        anchor: ASPresentationAnchor,
        clientId: String? = nil,
        sessionKey: String? = nil,
        additionalState: [String: String]? = nil,
        onOAuthSuccess: (@Sendable (OAuthSuccess) -> Void)? = nil
    ) async throws {
        guard let client = client else {
            throw TurnkeySwiftError.missingAuthProxyConfiguration
        }
        
        // we create a keypair and compute the nonce based on the publicKey
        let publicKey = try createKeyPair()
        let nonceData = Data(publicKey.utf8)
        let nonce = SHA256.hash(data: nonceData).map { String(format: "%02x", $0) }.joined()
        
        // we resolve the provider settings
        let settings = try getOAuthProviderSettings(provider: "x")
        let clientId = clientId ?? settings.clientId
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
        
        // we generate a verifier and challenge pair
        let pkce = try generatePKCEPair()
        
        // random state
        let state = UUID().uuidString
        
        // we build the provider auth url
        let xAuthUrl = try buildOAuth2AuthURL(
            baseURL: "https://x.com/i/oauth2/authorize",
            clientId: clientId,
            redirectUri: redirectUri,
            codeChallenge:pkce.challenge,
            scope: "tweet.read users.read",
            state: state
        )
        
        // run system web auth to retrieve authorization code and state
        let oauth = try await runOAuth2CodeSession(url: xAuthUrl, scheme: scheme, anchor: anchor)
        
        // we validate that returned state matches what we sent
        guard oauth.state == state else {
            throw TurnkeySwiftError.failedToRetrieveOAuthCredential(
                type: .authCode,
                underlying: NSError(
                    domain: "TurnkeySwiftError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "OAuth state mismatch"]
                )
            )
        }
        
        // we exchange the code for an oidcToken via the authProxy
        let resp = try await client.proxyOAuth2Authenticate(ProxyTOAuth2AuthenticateBody(
            authCode: oauth.code,
            clientId: clientId,
            codeVerifier: pkce.verifier,
            nonce: nonce,
            provider: .oauth2_provider_x,
            redirectUri: redirectUri
        ))
        
        let oidcToken = resp.oidcToken
        
        // if onOAuthSuccess was passed in then we run the callback
        // and then return early
        if let callback = onOAuthSuccess {
            callback(.init(oidcToken: oidcToken, providerName: "twitter", publicKey: publicKey))
            return
        }
        
        // since theres no onOAuthSuccess then we handle auth for them
        // via the authProxy
        _ = try await completeOAuth(
            oidcToken: oidcToken,
            publicKey: publicKey,
            providerName: "twitter"
        )
    }
    
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        oauthAnchor ?? ASPresentationAnchor()
    }
}
