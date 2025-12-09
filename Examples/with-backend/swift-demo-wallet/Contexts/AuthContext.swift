import AuthenticationServices
import Combine
import Foundation
import TurnkeyCrypto
import TurnkeyHttp
import TurnkeyPasskeys
import TurnkeySwift
import TurnkeyTypes

enum AuthError: Error {
    case passkeysNotSupported
    case invalidURL
    case serverError
    case missingSubOrgId
    case missingSession
}

@MainActor
final class AuthContext: ObservableObject {
    // ui observable state
    @Published var isLoading = false
    @Published var error: String?

    // private refs
    private let turnkey: TurnkeyContext
    private let backendURL = URL(string: Constants.App.backendBaseUrl)!

    init(turnkey: TurnkeyContext = .shared) {
        self.turnkey = turnkey
    }

    struct CreateSubOrgRequest: Codable {
        var passkey: PasskeyRegistrationResult?
        var apiKeys: [ApiKeyPayload]?
        var oAuthProviders: [OAuthProvider]?

        struct ApiKeyPayload: Codable {
            var apiKeyName: String
            var publicKey: String
            var curveType: v1ApiKeyCurve
            var expirationSeconds: String?
        }

        struct OAuthProvider: Codable {
            let providerName: String
            let oidcToken: String
        }
    }

    struct CreateSubOrgResponse: Codable {
        let subOrganizationId: String
    }

    struct SendOtpRequest: Codable {
        let otpType: OtpType
        let contact: String
        let userIdentifier: String
    }

    struct SendOtpResponse: Codable {
        let otpId: String
    }

    struct VerifyOtpRequest: Codable {
        let otpId: String
        let otpCode: String
        let expirationSeconds: String
    }

    struct VerifyOtpResponse: Codable {
        let verificationToken: String
    }

    struct CompleteOtpRequest: Codable {
        let verificationToken: String
        let otpType: OtpType
        let contact: String
        let publicKey: String
        let expirationSeconds: String
    }

    struct CompleteOtpResponse: Codable {
        let token: String
    }

    struct OAuthLoginRequest: Codable {
        let publicKey: String
        let providerName: String
        let oidcToken: String
        let expirationSeconds: String
    }

    struct OAuthLoginResponse: Codable {
        let token: String
    }

    func sendOtp(contact: String, type: OtpType) async throws -> (otpId: String, publicKey: String) {
        startLoading()
        defer { stopLoading() }

        let publicKey = try turnkey.createKeyPair()

        let body = SendOtpRequest(
            otpType: type,
            contact: contact,
            userIdentifier: publicKey
        )

        var request = URLRequest(url: backendURL.appendingPathComponent("/auth/sendOtp"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AuthError.serverError
        }

        let result = try JSONDecoder().decode(SendOtpResponse.self, from: data)
        return (otpId: result.otpId, publicKey: publicKey)
    }

    func verifyOtp(
        otpId: String,
        otpCode: String
    ) async throws -> String {
        let body = VerifyOtpRequest(
            otpId: otpId,
            otpCode: otpCode,
            expirationSeconds: Constants.Turnkey.sessionDuration
        )

        var request = URLRequest(url: backendURL.appendingPathComponent("/auth/verifyOtp"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AuthError.serverError
        }

        let result = try JSONDecoder().decode(VerifyOtpResponse.self, from: data)
        return result.verificationToken
    }

    func completeOtp(
        otpId: String,
        otpCode: String,
        otpType: OtpType,
        contact: String,
        publicKey: String
    ) async throws {
        let verificationToken = try await verifyOtp(otpId: otpId, otpCode: otpCode)

        let body = CompleteOtpRequest(
            verificationToken: verificationToken,
            otpType: otpType,
            contact: contact,
            publicKey: publicKey,
            expirationSeconds: Constants.Turnkey.sessionDuration
        )

        var request = URLRequest(url: backendURL.appendingPathComponent("/auth/otp"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AuthError.serverError
        }

        let result = try JSONDecoder().decode(CompleteOtpResponse.self, from: data)
        try await turnkey.storeSession(jwt: result.token, refreshedSessionTTLSeconds: Constants.Turnkey.sessionDuration)
    }

    func signUpWithPasskey(anchor: ASPresentationAnchor) async throws {
        guard isPasskeySupported else { throw AuthError.passkeysNotSupported }
        startLoading()
        defer { stopLoading() }

        let registration = try await createPasskey(
            user: PasskeyUser(id: UUID().uuidString, name: "Anonymous User", displayName: "Anonymous User"),
            rp: RelyingParty(id: Constants.App.rpId, name: Constants.App.appName),
            presentationAnchor: anchor
        )

        // for one-tap passkey sign-up, we generate a temporary API key pair
        // which is added as an authentication method for the new sub-org user
        // this allows us to stamp the session creation request immediately after
        // without prompting the user
        let (_, publicKeyCompressed, privateKey) = TurnkeyCrypto.generateP256KeyPair()

        let apiKey = CreateSubOrgRequest.ApiKeyPayload(
            apiKeyName: "Tempoarary API Key",
            publicKey: publicKeyCompressed,
            curveType: v1ApiKeyCurve.api_key_curve_p256,
            expirationSeconds: Constants.Turnkey.sessionDuration
        )

        let requestBody = CreateSubOrgRequest(
            passkey: registration,
            apiKeys: [apiKey]
        )

        let subOrgId = try await createSubOrganization(body: requestBody)

        let ephemeralClient = TurnkeyClient(
            apiPrivateKey: privateKey,
            apiPublicKey: publicKeyCompressed,
            baseUrl: Constants.Turnkey.apiUrl
        )

        try await stampLoginAndCreateSession(
            anchor: anchor,
            organizationId: subOrgId,
            expiresInSeconds: Constants.Turnkey.sessionDuration,
            client: ephemeralClient
        )
    }

    func loginWithPasskey(anchor: ASPresentationAnchor) async throws {
        guard isPasskeySupported else { throw AuthError.passkeysNotSupported }
        startLoading()
        defer { stopLoading() }

        try await stampLoginAndCreateSession(
            anchor: anchor,
            organizationId: Constants.Turnkey.organizationId,
            expiresInSeconds: Constants.Turnkey.sessionDuration
        )
    }

    func loginWithGoogle(anchor: ASPresentationAnchor) async throws {
        startLoading()
        defer { stopLoading() }

        try await turnkey.handleGoogleOAuth(
            anchor: anchor,
            onOAuthSuccess: { [weak self] oauthSuccess in
                guard let self = self else { return }

                Task { @MainActor in
                    do {
                        let oAuthBody = OAuthLoginRequest(
                            publicKey: oauthSuccess.publicKey,
                            providerName: oauthSuccess.providerName,
                            oidcToken: oauthSuccess.oidcToken,
                            expirationSeconds: Constants.Turnkey.sessionDuration
                        )

                        var request = URLRequest(url: self.backendURL.appendingPathComponent("/auth/oAuth"))
                        request.httpMethod = "POST"
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        request.httpBody = try JSONEncoder().encode(oAuthBody)

                        let (data, response) = try await URLSession.shared.data(for: request)
                        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                            throw AuthError.serverError
                        }

                        let result = try JSONDecoder().decode(OAuthLoginResponse.self, from: data)
                        try await self.turnkey.storeSession(jwt: result.token, refreshedSessionTTLSeconds: Constants.Turnkey.sessionDuration)
                    } catch {
                        self.error = error.localizedDescription
                        self.stopLoading()
                    }
                }
            }
        )
    }

    private func createSubOrganization(body: CreateSubOrgRequest) async throws -> String {
        var request = URLRequest(url: backendURL.appendingPathComponent("/auth/createSubOrg"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AuthError.serverError
        }

        return try JSONDecoder().decode(CreateSubOrgResponse.self, from: data).subOrganizationId
    }

    private func stampLoginAndCreateSession(
        anchor: ASPresentationAnchor,
        organizationId: String,
        expiresInSeconds: String,
        client: TurnkeyClient? = nil
    ) async throws {
        let client = client ?? TurnkeyClient(
            rpId: Constants.App.rpId,
            presentationAnchor: anchor,
            baseUrl: Constants.Turnkey.apiUrl
        )

        let publicKey = try turnkey.createKeyPair()

        do {
            let resp = try await client.stampLogin(
                TStampLoginBody(
                    organizationId: organizationId,
                    expirationSeconds: expiresInSeconds,
                    publicKey: publicKey
                )
            )

            let jwt = resp.session
            try await turnkey.storeSession(jwt: jwt, refreshedSessionTTLSeconds: Constants.Turnkey.sessionDuration)
        } catch let error as TurnkeyRequestError {
            throw error
        }
    }

    private func startLoading() {
        isLoading = true
        error = nil
    }

    private func stopLoading() {
        isLoading = false
    }
}
