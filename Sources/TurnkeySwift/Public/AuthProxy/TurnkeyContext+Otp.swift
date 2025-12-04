import AuthenticationServices
import Foundation
import TurnkeyHttp
import TurnkeyStamper
import TurnkeyTypes

extension TurnkeyContext {

    /// Initiates an OTP flow for the given contact and type.
    ///
    /// Sends an OTP to the specified contact using the configured Auth Proxy.
    ///
    /// - Parameters:
    ///   - contact: The user's contact (email or phone) to send the OTP to.
    ///   - otpType: The type of OTP to initiate (`.email` or `.sms`).
    ///
    /// - Returns: An `InitOtpResult` containing the `otpId` that uniquely identifies this OTP request.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.missingAuthProxyConfiguration` if the Auth Proxy client is not configured.
    ///   - `TurnkeySwiftError.failedToInitOtp` if the OTP initiation request fails.
    public func initOtp(contact: String, otpType: OtpType) async throws -> InitOtpResult {

        guard let client = client else {
            throw TurnkeySwiftError.missingAuthProxyConfiguration
        }

        do {
            let resp = try await client.proxyInitOtp(
                ProxyTInitOtpBody(
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
    /// Validates the provided code and returns a verification token for subsequent login or signup.
    ///
    /// - Parameters:
    ///   - otpId: The unique identifier returned from `initOtp`.
    ///   - otpCode: The code entered by the user.
    ///
    /// - Returns: A `VerifyOtpResult` containing the verification token confirming that the OTP was validated.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.missingAuthProxyConfiguration` if the Auth Proxy client is not configured.
    ///   - `TurnkeySwiftError.failedToVerifyOtp` if the verification request fails.
    public func verifyOtp(otpId: String, otpCode: String, publicKey: String? = nil) async throws
        -> VerifyOtpResult
    {
        guard let client = client else {
            throw TurnkeySwiftError.missingAuthProxyConfiguration
        }

        do {
            let resolvedPublicKey = try publicKey ?? createKeyPair()

            let resp = try await client.proxyVerifyOtp(
                ProxyTVerifyOtpBody(
                    otpCode: otpCode,
                    otpId: otpId,
                    publicKey: resolvedPublicKey
                ))

            return VerifyOtpResult(verificationToken: resp.verificationToken)
        } catch {
            throw TurnkeySwiftError.failedToVerifyOtp(underlying: error)
        }
    }

    /// Logs in an existing user using a previously verified OTP.
    ///
    /// Exchanges the verification token for a new session and stores it in the session registry.
    ///
    /// - Parameters:
    ///   - verificationToken: The verification token returned from `verifyOtp`.
    ///   - publicKey: The public key used for the session (optional).
    ///   - organizationId: The ID of the organization associated with the user.
    ///   - invalidateExisting: Whether to invalidate any existing sessions.
    ///   - sessionKey: The key under which to store the new session (optional).
    /// - Returns: A `BaseAuthResult` containing the created session.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.missingAuthProxyConfiguration` if the Auth Proxy client is not configured.
    ///   - `TurnkeySwiftError.failedToLoginWithOtp` if the login request fails.
    @discardableResult
    public func loginWithOtp(
        verificationToken: String,
        publicKey: String?,
        organizationId: String,
        invalidateExisting: Bool,
        sessionKey: String?
    ) async throws -> BaseAuthResult {
        guard let client = client else {
            throw TurnkeySwiftError.missingAuthProxyConfiguration
        }

        let sessionPublicKey = try publicKey ?? createKeyPair()

        do {
            let (message, clientSignaturePublicKey) = try ClientSignature.forLogin(
                verificationToken: verificationToken,
                sessionPublicKey: sessionPublicKey
            )

            let stamper = try Stamper(apiPublicKey: clientSignaturePublicKey)
            let signature = try await stamper.sign(
                payload: message,
                format: .raw
            )

            let clientSignature = v1ClientSignature(message: message, publicKey: clientSignaturePublicKey, scheme: .client_signature_scheme_api_p256, signature: signature)
            let response = try await client.proxyOtpLogin(
                ProxyTOtpLoginBody(
                    clientSignature: clientSignature,
                    invalidateExisting: invalidateExisting,
                    organizationId: organizationId,
                    publicKey: sessionPublicKey,
                    verificationToken: verificationToken
                ))

            let session = response.session

            try await storeSession(jwt: session, sessionKey: sessionKey)

            return BaseAuthResult(session: session)
        } catch {
            throw TurnkeySwiftError.failedToLoginWithOtp(underlying: error)
        }
    }

    /// Signs up a new user using an OTP-based flow.
    ///
    /// Creates a new sub-organization and user using the verified OTP, then performs automatic login.
    ///
    /// - Parameters:
    ///   - verificationToken: The verification token returned from `verifyOtp`.
    ///   - contact: The user’s contact (email or phone).
    ///   - otpType: The OTP type (`.email` or `.sms`).
    ///   - createSubOrgParams: Optional configuration for sub-organization creation.
    ///   - invalidateExisting: Whether to invalidate any existing sessions.
    ///   - sessionKey: Optional key to store the new session.
    ///
    /// - Returns: A `BaseAuthResult` containing the created session.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.missingAuthProxyConfiguration` if the Auth Proxy client is not configured.
    ///   - `TurnkeySwiftError.failedToSignUpWithOtp` if signup fails.
    @discardableResult
    public func signUpWithOtp(
        verificationToken: String,
        publicKey: String? = nil,
        contact: String,
        otpType: OtpType,
        createSubOrgParams: CreateSubOrgParams? = nil,
        invalidateExisting: Bool = false,
        sessionKey: String? = nil
    ) async throws -> BaseAuthResult {
        guard let client = client else {
            throw TurnkeySwiftError.missingAuthProxyConfiguration
        }

        do {
            // merge userEmail / userPhoneNumber into params
            var mergedParams = createSubOrgParams ?? CreateSubOrgParams()
            mergedParams.verificationToken = verificationToken
            if otpType == .email {
                mergedParams.userEmail = contact
            } else {
                mergedParams.userPhoneNumber = contact
            }

            // we build the body without client signature first
            var signupBody = buildSignUpBody(createSubOrgParams: mergedParams)

            let (message, clientSignaturePublicKey) = try ClientSignature.forSignup(
                verificationToken: verificationToken,
                email: signupBody.userEmail,
                phoneNumber: signupBody.userPhoneNumber,
                apiKeys: signupBody.apiKeys,
                authenticators: signupBody.authenticators,
                oauthProviders: signupBody.oauthProviders
            )

            let stamper = try Stamper(apiPublicKey: clientSignaturePublicKey)
            let signature = try await stamper.sign(
                payload: message,
                format: .raw
            )

            let clientSignature = v1ClientSignature(message: message, publicKey: clientSignaturePublicKey, scheme: .client_signature_scheme_api_p256, signature: signature)
            
            // then we add the client signature to the signup body
            signupBody = ProxyTSignupBody(
                apiKeys: signupBody.apiKeys,
                authenticators: signupBody.authenticators,
                clientSignature: clientSignature,
                oauthProviders: signupBody.oauthProviders,
                organizationName: signupBody.organizationName,
                userEmail: signupBody.userEmail,
                userName: signupBody.userName,
                userPhoneNumber: signupBody.userPhoneNumber,
                userTag: signupBody.userTag,
                verificationToken: signupBody.verificationToken,
                wallet: signupBody.wallet
            )

            let response = try await client.proxySignup(signupBody)

            let organizationId = response.organizationId

            return try await loginWithOtp(
                verificationToken: verificationToken,
                publicKey: publicKey,
                organizationId: organizationId,
                invalidateExisting: invalidateExisting,
                sessionKey: sessionKey
            )

        } catch {
            throw TurnkeySwiftError.failedToSignUpWithOtp(underlying: error)
        }
    }

    /// Completes a full OTP-based authentication flow (login or signup).
    ///
    /// Determines whether the user already exists and performs the appropriate action:
    /// logs in if an organization exists, otherwise signs up a new user.
    ///
    /// - Parameters:
    ///   - otpId: The unique identifier for the OTP request.
    ///   - otpCode: The OTP code provided by the user.
    ///   - contact: The contact associated with the OTP (email or phone).
    ///   - otpType: The OTP type (`.email` or `.sms`).
    ///   - publicKey: Optional public key to use during authentication.
    ///   - createSubOrgParams: Optional parameters for sub-organization creation.
    ///   - invalidateExisting: Whether to invalidate any existing sessions.
    ///   - sessionKey: Optional key to store the resulting session.
    ///
    /// - Returns: A `CompleteOtpResult` describing whether a login or signup occurred.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.missingAuthProxyConfiguration` if the Auth Proxy client is not configured.
    ///   - `TurnkeySwiftError.failedToCompleteOtp` if the authentication flow fails.
    @discardableResult
    public func completeOtp(
        otpId: String,
        otpCode: String,
        contact: String,
        otpType: OtpType,
        publicKey: String? = nil,
        createSubOrgParams: CreateSubOrgParams? = nil,
        invalidateExisting: Bool = false,
        sessionKey: String? = nil
    ) async throws -> CompleteOtpResult {
        guard let client = client else {
            throw TurnkeySwiftError.missingAuthProxyConfiguration
        }

        do {
            // we verify the otp code
            let verifyResult = try await verifyOtp(otpId: otpId, otpCode: otpCode)
            let verificationToken = verifyResult.verificationToken

            // we check if org already exists
            let response = try await client.proxyGetAccount(
                ProxyTGetAccountBody(
                    filterType: otpType == .email ? "EMAIL" : "PHONE_NUMBER",
                    filterValue: contact,
                    verificationToken: verificationToken
                ))

            if let organizationId = response.organizationId,
                !organizationId.isEmpty
            {
                // there is an existing org so we login
                let loginResp = try await loginWithOtp(
                    verificationToken: verificationToken,
                    publicKey: publicKey,
                    organizationId: organizationId,
                    invalidateExisting: invalidateExisting,
                    sessionKey: sessionKey
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
            throw TurnkeySwiftError.failedToCompleteOtp(underlying: error)
        }
    }

}
