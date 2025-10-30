import Foundation
import AuthenticationServices
import Combine
import TurnkeyTypes
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

        try await turnkey.signUpWithPasskey(
            anchor: anchor,
            passkeyDisplayName: "Demo App"
        )
    }

    func loginWithPasskey(anchor: ASPresentationAnchor) async throws {
        guard isPasskeySupported else { throw AuthError.passkeysNotSupported }
        startLoading()
        defer { stopLoading() }

        try await turnkey.loginWithPasskey(
            anchor: anchor,
            organizationId: Constants.Turnkey.organizationId
        )
    }

    func loginWithGoogle(anchor: ASPresentationAnchor) async throws {
        startLoading()
        defer { stopLoading() }

        _ = try await turnkey.handleGoogleOAuth(
            anchor: anchor,
            params: .init(clientId: Constants.Google.clientId)
        )
    }

    func loginWithApple(anchor: ASPresentationAnchor) async throws {
        startLoading()
        defer { stopLoading() }

        _ = try await turnkey.handleAppleOAuth(
            anchor: anchor,
            params: .init(clientId: Constants.Apple.clientId)
        )
    }

    func loginWithX(anchor: ASPresentationAnchor) async throws {
        startLoading()
        defer { stopLoading() }

        _ = try await turnkey.handleXOauth(
            anchor: anchor,
            params: .init(clientId: Constants.X.clientId)
        )
    }

    func loginWithDiscord(anchor: ASPresentationAnchor) async throws {
        startLoading()
        defer { stopLoading() }

        _ = try await turnkey.handleDiscordOAuth(
            anchor: anchor,
            params: .init(clientId: Constants.Discord.clientId)
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

    private func startLoading() {
        isLoading = true
        error = nil
    }

    private func stopLoading() {
        isLoading = false
    }
}
