import Foundation
import TurnkeyTypes
import AuthenticationServices
import TurnkeyHttp
import TurnkeyPasskeys
import TurnkeyCrypto

extension TurnkeyContext {
    // MARK: - OAuth Completion Types

    public enum OAuthAction: String, Codable {
        case login
        case signup
    }

    public struct CompleteOAuthResult: Codable {
        public let session: String
        public let action: OAuthAction
    }

    // MARK: - OAuth (Login/Signup/Complete)

    internal func loginWithOAuth(
        oidcToken: String,
        publicKey: String,
        invalidateExisting: Bool = false,
        sessionKey: String? = nil,
        organizationId: String? = nil
    ) async throws -> String {
        guard let client = client else {
            throw TurnkeySwiftError.invalidSession
        }

        do {
            let response = try await client.proxyOAuthLogin(ProxyTOAuthLoginBody(
                invalidateExisting: invalidateExisting,
                oidcToken: oidcToken,
                organizationId: organizationId,
                publicKey: publicKey
            ))
            let session = response.session
            try await createSession(jwt: session, refreshedSessionTTLSeconds: resolvedSessionTTLSeconds())
            return session
        } catch {
            throw TurnkeySwiftError.failedToCreateSession(underlying: error)
        }
    }

    internal func signUpWithOAuth(
        oidcToken: String,
        publicKey: String,
        providerName: String,
        createSubOrgParams: CreateSubOrgParams? = nil,
        sessionKey: String? = nil
    ) async throws -> String {
        guard let client = client else {
            throw TurnkeySwiftError.invalidSession
        }

        do {
            var merged = createSubOrgParams ?? CreateSubOrgParams()
            var oauthProviders = merged.oauthProviders ?? []
            oauthProviders.append(.init(providerName: providerName, oidcToken: oidcToken))
            merged.oauthProviders = oauthProviders

            let signupBody = buildSignUpBody(createSubOrgParams: merged)
            let res = try await client.proxySignup(signupBody)
            _ = res.organizationId

            // After signup, perform OAuth login using the same public key
            return try await loginWithOAuth(
                oidcToken: oidcToken,
                publicKey: publicKey,
                invalidateExisting: false,
                sessionKey: sessionKey
            )
        } catch {
            throw TurnkeySwiftError.failedToCreateSession(underlying: error)
        }
    }

    public func completeOAuth(
        oidcToken: String,
        publicKey: String,
        providerName: String = "google",
        sessionKey: String? = nil,
        invalidateExisting: Bool = false,
        createSubOrgParams: CreateSubOrgParams? = nil
    ) async throws -> CompleteOAuthResult {
        guard let client = client else {
            throw TurnkeySwiftError.invalidSession
        }

        do {
            // Lookup account by raw OIDC token
            let account = try await client.proxyGetAccount(ProxyTGetAccountBody(
                filterType: "OIDC_TOKEN",
                filterValue: oidcToken
            ))

            if let orgId = account.organizationId, !orgId.isEmpty {
                
                let session = try await loginWithOAuth(
                    oidcToken: oidcToken,
                    publicKey: publicKey,
                    invalidateExisting: invalidateExisting,
                    sessionKey: sessionKey,
                    organizationId: orgId
                )
                return .init(session: session, action: .login)
            } else {
                let session = try await signUpWithOAuth(
                    oidcToken: oidcToken,
                    publicKey: publicKey,
                    providerName: providerName,
                    createSubOrgParams: createSubOrgParams,
                    sessionKey: sessionKey
                )
                return .init(session: session, action: .signup)
            }
        } catch {
            throw TurnkeySwiftError.failedToCreateSession(underlying: error)
        }
    }
    
    /// Initiates an OTP flow for the given contact and type.
    ///
    /// - Parameters:
    ///   - contact: The user’s contact (email or phone) to send the OTP to.
    ///   - otpType: The type of OTP to initiate (e.g., email, SMS).
    ///
    /// - Returns: The `otpId` representing this OTP request.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidSession` if no session is active.
    ///   - `TurnkeySwiftError.failedToInitOtp` if the OTP request fails.
    public func initOtp(contact: String, otpType: OtpType) async throws -> String {
        
        guard let client = client else {
            throw TurnkeySwiftError.invalidSession
        }
        
        do {
            let resp = try await client.proxyInitOtp(ProxyTInitOtpBody(
                contact: contact,
                otpType: otpType.rawValue
            ))
            
            let result = resp.otpId
            
            return result
        } catch {
            throw TurnkeySwiftError.failedToInitOtp(underlying: error)
        }
    }
    
    /// Verifies a user-provided OTP code for a given OTP request.
    ///
    /// - Parameters:
    ///   - otpId: The unique identifier returned from `initOtp`.
    ///   - otpCode: The one-time password entered by the user.
    ///
    /// - Returns: The verification token (`verificationToken`) confirming the OTP was validated.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidSession` if no session is active.
    ///   - `TurnkeySwiftError.failedToInitOtp` if verification fails.
    public func verifyOtp(otpId: String, otpCode: String) async throws -> String {
        
        guard let client = client else {
            throw TurnkeySwiftError.invalidSession
        }
        
        do {
            let resp = try await client.proxyVerifyOtp(ProxyTVerifyOtpBody(
                otpCode: otpCode,
                otpId: otpId
            ))
            
            let result = resp.verificationToken
            
            return result
        } catch {
            throw TurnkeySwiftError.failedToInitOtp(underlying: error)
        }
    }
    
    /// Logs in an existing user using a previously verified OTP.
    ///
    /// - Parameters:
    ///   - verificationToken: The verification token returned from `verifyOtp`.
    ///   - organizationId: The ID of the organization associated with the user.
    ///   - sessionKey: The storage key for the new session (optional).
    ///   - invalidateExisting: Whether to invalidate any existing sessions.
    ///   - publicKey: The public key used for the session (optional).
    ///
    /// - Returns: The session JWT string.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidSession` if no session is active.
    ///   - `TurnkeySwiftError.failedToLoginWithOtp` if the login request fails.
    public func loginWithOtp(
        verificationToken: String,
        organizationId: String,
        sessionKey: String?,
        invalidateExisting: Bool,
        publicKey: String?
    ) async throws -> String {
        guard let client = client else {
            throw TurnkeySwiftError.invalidSession
        }
        
        do {
            let resolvedPublicKey = try publicKey ?? createKeyPair()
            
            let response = try await client.proxyOtpLogin(ProxyTOtpLoginBody(
                invalidateExisting: invalidateExisting,
                organizationId: organizationId,
                publicKey: resolvedPublicKey,
                verificationToken: verificationToken
            ))
            
            let session = response.session
            
            try await createSession(jwt: session, refreshedSessionTTLSeconds: resolvedSessionTTLSeconds())
            
            
            return session
        } catch {
            throw TurnkeySwiftError.failedToLoginWithOtp(underlying: error)
        }
    }
    
    /// Signs up a new user using an OTP flow.
    ///
    /// - Parameters:
    ///   - verificationToken: The verification token returned from `verifyOtp`.
    ///   - contact: The user’s contact (email or phone).
    ///   - otpType: The OTP type (email or SMS).
    ///   - createSubOrgParams: Optional configuration for sub-organization creation.
    ///   - invalidateExisting: Whether to invalidate any existing sessions.
    ///   - sessionKey: The session key to use for storing the new session (optional).
    ///
    /// - Returns: The session JWT string.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidSession` if no session is active.
    ///   - `TurnkeySwiftError.failedToLoginWithOtp` if signup or login fails.
    public func signUpWithOtp(
        verificationToken: String,
        contact: String,
        otpType: OtpType,
        createSubOrgParams: CreateSubOrgParams? = nil,
        invalidateExisting: Bool = false,
        sessionKey: String? = nil
    ) async throws -> String {
        guard let client = client else {
            throw TurnkeySwiftError.invalidSession
        }
        
        do {
            // generate the keypair up front
            let generatedPublicKey = try createKeyPair()
            
            // merge userEmail / userPhoneNumber into params
            var mergedParams = createSubOrgParams ?? CreateSubOrgParams()
            mergedParams.verificationToken = verificationToken
            if otpType == .email {
                mergedParams.userEmail = contact
            } else {
                mergedParams.userPhoneNumber = contact
            }
            
            // we always include at least one API key
            // for the one tap signup
            mergedParams.apiKeys = [
                CreateSubOrgParams.ApiKey(
                    apiKeyName: "api-key-\(Int(Date().timeIntervalSince1970))",
                    publicKey: generatedPublicKey,
                    curveType: .api_key_curve_p256,
                    expirationSeconds: nil
                )
            ]
            
            // build body and call proxySignup
            let signupBody = buildSignUpBody(createSubOrgParams: mergedParams)
            let response = try await client.proxySignup(signupBody)
            
            let organizationId = response.organizationId
            
            let session = try await loginWithOtp(
                verificationToken: verificationToken,
                organizationId: organizationId,
                sessionKey: sessionKey,
                invalidateExisting: invalidateExisting,
                publicKey: generatedPublicKey
            )
            
            try await createSession(jwt: session, refreshedSessionTTLSeconds: resolvedSessionTTLSeconds())
            
            return session
        } catch {
            throw TurnkeySwiftError.failedToLoginWithOtp(underlying: error)
        }
    }
    
    public enum OtpAction: String, Codable {
        case login
        case signup
    }
    
    public struct CompleteOtpResult: Codable {
        public let session: String
        public let verificationToken: String
        public let action: OtpAction
    }
    
    /// Completes a full OTP-based authentication flow (login or signup).
    ///
    /// - Parameters:
    ///   - otpId: The unique identifier for the OTP request.
    ///   - otpCode: The OTP code provided by the user.
    ///   - contact: The contact associated with the OTP (email or phone).
    ///   - otpType: The OTP type (email or SMS).
    ///   - publicKey: Optional public key to use during authentication.
    ///   - invalidateExisting: Whether to invalidate any existing sessions.
    ///   - sessionKey: Optional key to store the resulting session.
    ///   - createSubOrgParams: Optional parameters for sub-organization creation.
    ///
    /// - Returns: A `CompleteOtpResult` indicating whether the action was a login or signup.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidSession` if no session is active.
    ///   - `TurnkeySwiftError.failedToLoginWithOtp` if the flow fails.
    public func completeOtp(
        otpId: String,
        otpCode: String,
        contact: String,
        otpType: OtpType,
        publicKey: String? = nil,
        invalidateExisting: Bool = false,
        sessionKey: String? = nil,
        createSubOrgParams: CreateSubOrgParams? = nil
    ) async throws -> CompleteOtpResult {
        guard let client = client else {
            throw TurnkeySwiftError.invalidSession
        }
        
        do {
            // we verify the otp code
            let verificationToken = try await verifyOtp(otpId: otpId, otpCode: otpCode)
            
            // we check if org already exists
            let response = try await client.proxyGetAccount(ProxyTGetAccountBody(
                filterType: otpType == .email ? "EMAIL" : "PHONE_NUMBER",
                filterValue: contact,
                verificationToken: verificationToken
            ))
            
            if let organizationId = response.organizationId,
               !organizationId.isEmpty {
                // there is an existing org so we login
                let session = try await loginWithOtp(
                    verificationToken: verificationToken,
                    organizationId: organizationId,
                    sessionKey: sessionKey,
                    invalidateExisting: invalidateExisting,
                    publicKey: publicKey
                )
                
                return CompleteOtpResult(
                    session: session,
                    verificationToken: verificationToken,
                    action: .login
                )
            } else {
                // no org so we signup
                let session = try await signUpWithOtp(
                    verificationToken: verificationToken,
                    contact: contact,
                    otpType: otpType,
                    createSubOrgParams: createSubOrgParams,
                    invalidateExisting: invalidateExisting,
                    sessionKey: sessionKey
                )
                
                return CompleteOtpResult(
                    session: session,
                    verificationToken: verificationToken,
                    action: .signup
                )
            }
        } catch {
            throw TurnkeySwiftError.failedToLoginWithOtp(underlying: error)
        }
    }
    
    public func loginWithPasskey(
        anchor: ASPresentationAnchor,
        organizationId: String? = nil,
        publicKey: String? = nil,
        sessionKey: String? = nil
    ) async throws {
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
            
            guard let session = resp.activity.result.stampLoginResult?.session
            else {
                throw TurnkeySwiftError.invalidResponse
            }
            
            try await createSession(jwt: session, refreshedSessionTTLSeconds: resolvedSessionTTLSeconds())
            
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
    ) async throws {
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

          // TODO: how do we make this cleaner?
          mergedParams.authenticators = [
              CreateSubOrgParams.Authenticator(
                  authenticatorName: passkeyName,
                  challenge: passkey.challenge,
                  attestation: v1Attestation(
                      attestationObject: passkey.attestation.attestationObject,
                      clientDataJson: passkey.attestation.clientDataJson,
                      credentialId: passkey.attestation.credentialId,
                      transports: passkey.attestation.transports.compactMap {
                          v1AuthenticatorTransport(rawValue: $0.rawValue)
                      }
                  )
              )
          ]

        mergedParams.apiKeys = [
          CreateSubOrgParams.ApiKey(
            apiKeyName: "passkey-auth-\(generatedPublicKey!)",
            publicKey: generatedPublicKey!,
            curveType: .api_key_curve_p256,
            expirationSeconds: "60"
          )
        ]

        let signupBody = buildSignUpBody(createSubOrgParams: mergedParams)

        // 4. Proxy signup call
        // Use the Auth Proxy–configured client for signup
        guard let proxyClient = self.client else {
          throw TurnkeySwiftError.invalidSession
        }
        let response = try await proxyClient.proxySignup(signupBody)

        let organizationId = response.organizationId

        // 5. Generate another key for the session login
        let newPublicKey = try createKeyPair()

        // 6. Login and create session
        let loginResponse = try await passkeyClient.stampLogin(TStampLoginBody(
          organizationId: organizationId,
          expirationSeconds: resolvedSessionTTLSeconds(),
          invalidateExisting: true,
          publicKey: newPublicKey
        ))

        guard let session = loginResponse.activity.result.stampLoginResult?.session
        else {
          throw TurnkeySwiftError.invalidResponse
        }

          try await createSession(jwt: session, refreshedSessionTTLSeconds: resolvedSessionTTLSeconds())

      } catch {
        throw TurnkeySwiftError.failedToCreateWallet(underlying: error)
      }
    }


}
