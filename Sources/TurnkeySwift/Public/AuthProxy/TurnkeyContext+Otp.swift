import Foundation
import AuthenticationServices
import TurnkeyTypes
import TurnkeyHttp

extension TurnkeyContext {
    /// Initiates an OTP flow for the given contact and type.
    ///
    /// - Parameters:
    ///   - contact: The user's contact (email or phone) to send the OTP to.
    ///   - otpType: The type of OTP to initiate (e.g., email, SMS).
    ///
    /// - Returns: An `InitOtpResult` containing the `otpId` representing this OTP request.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidSession` if no session is active.
    ///   - `TurnkeySwiftError.failedToInitOtp` if the OTP request fails.
    public func initOtp(contact: String, otpType: OtpType) async throws -> InitOtpResult {
        
        guard let client = client else {
            throw TurnkeySwiftError.invalidSession
        }
        
        do {
            let resp = try await client.proxyInitOtp(ProxyTInitOtpBody(
                contact: contact,
                otpType: otpType.rawValue
            ))
            
            return InitOtpResult(otpId: resp.otpId)
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
    /// - Returns: A `VerifyOtpResult` containing the verification token confirming the OTP was validated.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidSession` if no session is active.
    ///   - `TurnkeySwiftError.failedToInitOtp` if verification fails.
    public func verifyOtp(otpId: String, otpCode: String) async throws -> VerifyOtpResult {
        
        guard let client = client else {
            throw TurnkeySwiftError.invalidSession
        }
        
        do {
            let resp = try await client.proxyVerifyOtp(ProxyTVerifyOtpBody(
                otpCode: otpCode,
                otpId: otpId
            ))
            
            return VerifyOtpResult(credentialBundle: resp.verificationToken)
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
    ) async throws -> BaseAuthResult {
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
            
            
            return BaseAuthResult(session: session)
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
    ) async throws -> BaseAuthResult {
        guard let client = client else {
            throw TurnkeySwiftError.invalidSession
        }
        
        do {
            // generate the keypair up front
            let publicKey = try createKeyPair()
            
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
            let newApiKey = CreateSubOrgParams.ApiKey(
                apiKeyName: "api-key-\(Int(Date().timeIntervalSince1970))",
                publicKey: publicKey,
                curveType: .api_key_curve_p256,
                expirationSeconds: nil
            )
            
            // Append to existing apiKeys or create new array if nil
            mergedParams.apiKeys = (mergedParams.apiKeys ?? []) + [newApiKey]
            
            // build body and call proxySignup
            let signupBody = buildSignUpBody(createSubOrgParams: mergedParams)
            let response = try await client.proxySignup(signupBody)
            
            let organizationId = response.organizationId
            
            let loginResp = try await loginWithOtp(
                verificationToken: verificationToken,
                organizationId: organizationId,
                sessionKey: sessionKey,
                invalidateExisting: invalidateExisting,
                publicKey: publicKey
            )
            
            try await createSession(jwt: loginResp.session, refreshedSessionTTLSeconds: resolvedSessionTTLSeconds())
            
            return loginResp
        } catch {
            throw TurnkeySwiftError.failedToLoginWithOtp(underlying: error)
        }
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
            let verifyResult = try await verifyOtp(otpId: otpId, otpCode: otpCode)
            let verificationToken = verifyResult.credentialBundle
            
            // we check if org already exists
            let response = try await client.proxyGetAccount(ProxyTGetAccountBody(
                filterType: otpType == .email ? "EMAIL" : "PHONE_NUMBER",
                filterValue: contact,
                verificationToken: verificationToken
            ))
            
            if let organizationId = response.organizationId,
               !organizationId.isEmpty {
                // there is an existing org so we login
                let loginResp = try await loginWithOtp(
                    verificationToken: verificationToken,
                    organizationId: organizationId,
                    sessionKey: sessionKey,
                    invalidateExisting: invalidateExisting,
                    publicKey: publicKey
                )
                
                return CompleteOtpResult(
                    session: loginResp.session,
                    verificationToken: verificationToken,
                    action: .login
                )
            } else {
                // no org so we signup
                let signUpResp = try await signUpWithOtp(
                    verificationToken: verificationToken,
                    contact: contact,
                    otpType: otpType,
                    createSubOrgParams: createSubOrgParams,
                    invalidateExisting: invalidateExisting,
                    sessionKey: sessionKey
                )
                
                return CompleteOtpResult(
                    session: signUpResp.session,
                    verificationToken: verificationToken,
                    action: .signup
                )
            }
        } catch {
            throw TurnkeySwiftError.failedToLoginWithOtp(underlying: error)
        }
    }
    
}
