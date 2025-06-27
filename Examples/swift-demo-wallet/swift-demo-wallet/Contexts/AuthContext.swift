import Foundation
import AuthenticationServices
import Combine
import TurnkeyPasskeys
import TurnkeyHttp
import TurnkeyCrypto
import TurnkeySwift

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
    
    enum OtpType: String, Codable {
        case email = "OTP_TYPE_EMAIL"
        case sms = "OTP_TYPE_SMS"
    }
    
    struct CreateSubOrgRequest: Codable {
        var passkey: PasskeyRegistrationResult?
        var apiKeys: [ApiKeyPayload]?
        var oAuthProviders: [OAuthProvider]?

        struct ApiKeyPayload: Codable {
            var apiKeyName: String
            var publicKey: String
            var curveType: Components.Schemas.ApiKeyCurve
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
        let otpType: OtpType
        let contact: String
        let publicKey: String
        let expirationSeconds: String
    }

    struct VerifyOtpResponse: Codable {
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
        otpCode: String,
        filterType: OtpType,
        contact: String,
        publicKey: String
    ) async throws {
        startLoading()
        defer { stopLoading() }

        let body = VerifyOtpRequest(
            otpId: otpId,
            otpCode: otpCode,
            otpType: filterType,
            contact: contact,
            publicKey: publicKey,
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
        try await turnkey.createSession(jwt: result.token, refreshedSessionTTLSeconds: Constants.Turnkey.sessionDuration)
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
            curveType: Components.Schemas.ApiKeyCurve.API_KEY_CURVE_P256,
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

        let publicKey = try turnkey.createKeyPair()
        let nonce = publicKey
            .data(using: .utf8)!
            .sha256()
            .map { String(format: "%02x", $0) }
            .joined()

        let oidcToken = try await turnkey.startGoogleOAuthFlow(
            clientId: Constants.Google.clientId,
            nonce: nonce,
            scheme: Constants.App.scheme,
            anchor: anchor
        )

        let oAuthBody = OAuthLoginRequest(
            publicKey: publicKey,
            providerName: "google",
            oidcToken: oidcToken,
            expirationSeconds: Constants.Turnkey.sessionDuration
        )

        var request = URLRequest(url: backendURL.appendingPathComponent("/auth/oAuth"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(oAuthBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AuthError.serverError
        }

        let result = try JSONDecoder().decode(OAuthLoginResponse.self, from: data)
        try await turnkey.createSession(jwt: result.token, refreshedSessionTTLSeconds: Constants.Turnkey.sessionDuration)
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
                organizationId: organizationId,
                publicKey: publicKey,
                expirationSeconds: expiresInSeconds,
                invalidateExisting: true
            )

            guard
                case let .json(body) = resp.body,
                let jwt = body.activity.result.stampLoginResult?.session
            else {
                throw AuthError.serverError
            }

            try await turnkey.createSession(jwt: jwt, refreshedSessionTTLSeconds: Constants.Turnkey.sessionDuration)

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
