import Foundation
import AuthenticationServices
import TurnkeyHttp

extension TurnkeyContext: ASWebAuthenticationPresentationContextProviding {
    
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
    public func startGoogleOAuthFlow(
        clientId: String,
        nonce: String,
        scheme: String,
        anchor: ASPresentationAnchor,
        originUri: String? = nil,
        redirectUri: String? = nil
    ) async throws -> String {
        
        self.oauthAnchor = anchor
        
        let finalOriginUri = originUri ?? Constants.Turnkey.oauthOriginUrl
        let resolvedRedirectBase = runtimeConfig?.auth.oauth.redirectBaseUrl ?? Constants.Turnkey.oauthRedirectUrl
        let finalRedirectUri = redirectUri ?? "\(resolvedRedirectBase)?scheme=\(scheme)"
        
        var comps = URLComponents(string: finalOriginUri)!
        comps.queryItems = [
            URLQueryItem(name: "provider",    value: "google"),
            URLQueryItem(name: "clientId",    value: clientId),
            URLQueryItem(name: "redirectUri", value: finalRedirectUri),
            URLQueryItem(name: "nonce",       value: nonce)
        ]
        
        guard let url = comps.url else {
            throw TurnkeySwiftError.oauthInvalidURL
        }
        
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
                    let idToken = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?
                        .first(where: { $0.name == "id_token" })?.value
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
    
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        oauthAnchor ?? ASPresentationAnchor()
    }
}
