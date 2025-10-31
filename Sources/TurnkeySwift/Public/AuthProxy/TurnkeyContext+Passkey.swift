import Foundation
import AuthenticationServices
import TurnkeyTypes
import TurnkeyHttp
import TurnkeyPasskeys
import TurnkeyCrypto

extension TurnkeyContext {
    
    public func loginWithPasskey(
        anchor: ASPresentationAnchor,
        organizationId: String? = nil,
        publicKey: String? = nil,
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
                expirationSeconds: resolvedSessionTTLSeconds(),
                publicKey: resolvedPublicKey
            ))
            
            let session = resp.session
            try await createSession(jwt: session, refreshedSessionTTLSeconds: resolvedSessionTTLSeconds())
            
            // TODO: can we return the credentialId here?
            // from a quick glance this is going to be difficult
            // for now we return an empty string
            return PasskeyAuthResult(session: session, credentialId: "")
        } catch {
            throw TurnkeySwiftError.failedToLoginWithPasskey(underlying: error)
        }
    }
    
    @available(iOS 16.0, macOS 13.0, *)
    public func signUpWithPasskey(
        anchor: ASPresentationAnchor,
        passkeyDisplayName: String? = nil,
        challenge: String? = nil,
        createSubOrgParams: CreateSubOrgParams? = nil,
        sessionKey: String? = nil,
        organizationId: String? = nil
    ) async throws -> PasskeyAuthResult {
        guard let rpId = self.rpId, !rpId.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration("Missing rpId; set via TurnkeyContext.configure(rpId:)")
        }
        let passkeyClient = TurnkeyClient(
            rpId: rpId,
            presentationAnchor: anchor,
            baseUrl: apiUrl
        )
        
        var generatedPublicKey: String?
        do {
            
            let passkeyName = passkeyDisplayName ?? "passkey-\(Int(Date().timeIntervalSince1970))"
            
            // for one-tap passkey sign-up, we generate a temporary API key pair
            // which is added as an authentication method for the new sub-org user
            // this allows us to stamp the session creation request immediately after
            // without prompting the user
            let (_, publicKeyCompressed, privateKey) = TurnkeyCrypto.generateP256KeyPair()
            generatedPublicKey = publicKeyCompressed
            
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
                apiKeyName: "passkey-auth-\(generatedPublicKey!)",
                publicKey: generatedPublicKey!,
                curveType: .api_key_curve_p256,
                expirationSeconds: "60"
            )
            mergedParams.apiKeys = (mergedParams.apiKeys ?? []) + [newApiKey]
            
            let signupBody = buildSignUpBody(createSubOrgParams: mergedParams)
            
            // 4. Proxy signup call
            // Use the Auth Proxy–configured client for signup
            guard let proxyClient = self.client else {
                throw TurnkeySwiftError.invalidSession
            }
            let response = try await proxyClient.proxySignup(signupBody)
            
            let organizationId = response.organizationId
            
            // 5. Generate another key for the session login
            let newKeyPairResult = try createKeyPair()
            
            // 6. Login and create session
            let loginResponse = try await passkeyClient.stampLogin(TStampLoginBody(
                organizationId: organizationId,
                expirationSeconds: resolvedSessionTTLSeconds(),
                invalidateExisting: true,
                publicKey: newKeyPairResult
            ))
            
            let session = loginResponse.session
            try await createSession(jwt: session, refreshedSessionTTLSeconds: resolvedSessionTTLSeconds())
            
            return PasskeyAuthResult(session: session, credentialId: passkey.attestation.credentialId)
            
        } catch {
            throw TurnkeySwiftError.failedToCreateWallet(underlying: error)
        }
    }
}
