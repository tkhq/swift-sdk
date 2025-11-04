import Foundation
import AuthenticationServices
import TurnkeyTypes
import TurnkeyHttp
import TurnkeyPasskeys
import TurnkeyCrypto

extension TurnkeyContext {
    
    /// Logs in an existing user using a registered passkey (WebAuthn).
    ///
    /// Initiates a passkey assertion through the system passkey UI,
    /// then sends the signed assertion to Turnkey to create a new authenticated session.
    ///
    /// - Parameters:
    ///   - anchor: The presentation anchor used to display the system passkey UI.
    ///   - publicKey: Optional public key to bind the session to (auto-generates if not provided).
    ///   - organizationId: Optional organization ID. If not provided, uses the configured value in `TurnkeyContext`.
    ///   - expirationSeconds: Optional duration (in seconds) for the session's lifetime.
    ///   - sessionKey: Optional session storage key for the resulting session.
    ///
    /// - Returns: A `PasskeyAuthResult` containing the created session and credential ID (currently empty).
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidConfiguration` if `rpId` or `organizationId` is missing.
    ///   - `TurnkeySwiftError.failedToLoginWithPasskey` if the login or stamping process fails.
    public func loginWithPasskey(
        anchor: ASPresentationAnchor,
        publicKey: String? = nil,
        organizationId: String? = nil,
        expirationSeconds: String? = nil,
        sessionKey: String? = nil
    ) async throws -> PasskeyAuthResult {
        guard let rpId = self.rpId, !rpId.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration("Missing rpId; set via TurnkeyContext.configure(rpId:)")
        }
        let resolvedOrganizationId = organizationId ?? self.organizationId
        guard let orgId = resolvedOrganizationId, !orgId.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration("Missing organizationId; pass as parameter or set via TurnkeyContext.configure(organizationId:)")
        }
        let client = TurnkeyClient(
            rpId: rpId,
            presentationAnchor: anchor,
            baseUrl: apiUrl
        )
        
        let resolvedPublicKey = try publicKey ?? createKeyPair()
        
        do {
            let resp = try await client.stampLogin(TStampLoginBody(
                organizationId: orgId,
                expirationSeconds:  resolvedSessionExpirationSeconds(expirationSeconds: expirationSeconds),
                publicKey: resolvedPublicKey
            ))
            
            let resolvedRefreshedSessionTTLSeconds = runtimeConfig?.auth.autoRefreshSession == true
                ? expirationSeconds
                : nil
            
            let session = resp.session
            try await storeSession(jwt: session, refreshedSessionTTLSeconds: resolvedRefreshedSessionTTLSeconds)
            
            // TODO: can we return the credentialId here?
            // from a quick glance this is going to be difficult
            // for now we return an empty string
            return PasskeyAuthResult(session: session, credentialId: "")
        } catch {
            throw TurnkeySwiftError.failedToLoginWithPasskey(underlying: error)
        }
    }
    
    /// Signs up a new user and sub-organization using a passkey (WebAuthn).
    ///
    /// Creates a new passkey via the system UI, registers it with Turnkey as an authenticator,
    /// and performs a one-tap login using a temporary API key generated during signup.
    ///
    /// - Parameters:
    ///   - anchor: The presentation anchor used to display the system passkey UI.
    ///   - passkeyDisplayName: Optional display name for the passkey (defaults to `"passkey-<timestamp>"`).
    ///   - challenge: Optional custom challenge string to use during passkey creation.
    ///   - expirationSeconds: Optional duration (in seconds) for the session's lifetime.
    ///   - createSubOrgParams: Optional configuration for sub-organization creation (merged with passkey and API key data).
    ///   - sessionKey: Optional session storage key for the resulting session.
    ///   - organizationId: Optional organization ID override (not typically required for sign-up).
    ///
    /// - Returns: A `PasskeyAuthResult` containing the new session and the registered passkey's credential ID.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.missingAuthProxyConfiguration` if the Auth Proxy client is not initialized.
    ///   - `TurnkeySwiftError.invalidConfiguration` if `rpId` is missing.
    ///   - `TurnkeySwiftError.failedToSignUpWithPasskey` if signup or stamping fails.
    @available(iOS 16.0, macOS 13.0, *)
    public func signUpWithPasskey(
        anchor: ASPresentationAnchor,
        passkeyDisplayName: String? = nil,
        challenge: String? = nil,
        expirationSeconds: String? = nil,
        createSubOrgParams: CreateSubOrgParams? = nil,
        sessionKey: String? = nil
    ) async throws -> PasskeyAuthResult {
        guard let client = client else {
            throw TurnkeySwiftError.missingAuthProxyConfiguration
        }
        
        guard let rpId = self.rpId, !rpId.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration("Missing rpId; set via TurnkeyContext.configure(rpId:)")
        }
        
        do {
            
            let passkeyName = passkeyDisplayName ?? "passkey-\(Int(Date().timeIntervalSince1970))"
            
            // for one-tap passkey sign-up, we generate a temporary API key pair
            // which is added as an authentication method for the new sub-org user
            // this allows us to stamp the session creation request immediately after
            // without prompting the user
            let (_, publicKeyCompressed: generatedPublicKey, privateKey) = TurnkeyCrypto.generateP256KeyPair()
            
            let passkey = try await createPasskey(
                user: PasskeyUser(id: UUID().uuidString, name: passkeyName, displayName: passkeyName),
                rp: RelyingParty(id: rpId, name: ""),
                presentationAnchor: anchor
            )
            
            
            // we build the signup body
            var mergedParams = createSubOrgParams ?? CreateSubOrgParams()
            
            // Add the passkey authenticator (append to existing or create new array)
            let newAuthenticator = CreateSubOrgParams.Authenticator(
                authenticatorName: passkeyName,
                challenge: passkey.challenge,
                attestation: passkey.attestation
            )
            mergedParams.authenticators = (mergedParams.authenticators ?? []) + [newAuthenticator]
            
            // Add the API key for session authentication (append to existing or create new array)
            let newApiKey = CreateSubOrgParams.ApiKey(
                apiKeyName: "passkey-auth-\(generatedPublicKey)",
                publicKey: generatedPublicKey,
                curveType: .api_key_curve_p256,
                expirationSeconds: "60"
            )
            mergedParams.apiKeys = (mergedParams.apiKeys ?? []) + [newApiKey]
            
            let signupBody = buildSignUpBody(createSubOrgParams: mergedParams)
            let response = try await client.proxySignup(signupBody)
            
            let organizationId = response.organizationId
            
            let temporaryClient = TurnkeyClient(
                apiPrivateKey: privateKey,
                apiPublicKey: generatedPublicKey,
                baseUrl: apiUrl
            )
            
            let newKeyPairResult = try createKeyPair()
            
            let loginResponse = try await temporaryClient.stampLogin(TStampLoginBody(
                organizationId: organizationId,
                expirationSeconds:  resolvedSessionExpirationSeconds(expirationSeconds: expirationSeconds),
                invalidateExisting: true,
                publicKey: newKeyPairResult
            ))
            
            let resolvedRefreshedSessionTTLSeconds = runtimeConfig?.auth.autoRefreshSession == true
                ? expirationSeconds
                : nil
            
            let session = loginResponse.session
            try await storeSession(jwt: session, refreshedSessionTTLSeconds: resolvedRefreshedSessionTTLSeconds)
            
            return PasskeyAuthResult(session: session, credentialId: passkey.attestation.credentialId)
            
        } catch {
            throw TurnkeySwiftError.failedToSignUpWithPasskey(underlying: error)
        }
    }
}
