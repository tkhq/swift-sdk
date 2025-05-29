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
    private let backendURL = URL(string: "http://localhost:3000")!
    
    init(turnkey: TurnkeyContext = .shared) {
        self.turnkey = turnkey
    }
    
    enum OtpType: String, Codable {
        case email = "OTP_TYPE_EMAIL"
        case sms   = "OTP_TYPE_SMS"
    }
    
    struct CreateSubOrgRequest: Codable {
        let passkey: PasskeyRegistrationResult?
        init(registration: PasskeyRegistrationResult) {
            self.passkey = registration
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
    
    func sendOtp(contact: String, type: OtpType) async throws -> (otpId: String, publicKey: String) {
        startLoading()
        defer { stopLoading() }
        
        let publicKey = try turnkey.createKeyPair()
        
        let body = SendOtpRequest(otpType: type, contact: contact, userIdentifier: publicKey)
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
            expirationSeconds: "120"
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
        try await turnkey.createSession(jwt: result.token)
    }
    
    func signUpWithPasskey(anchor: ASPresentationAnchor) async throws {
        guard isPasskeySupported else { throw AuthError.passkeysNotSupported }
        startLoading()
        defer { stopLoading() }
        
        let registration = try await createPasskey(
            user: PasskeyUser(id: UUID().uuidString,
                              name: "Anonymous User",
                              displayName: "Anonymous User"),
            rp: RelyingParty(id: "passkeyapp.tkhqlabs.xyz", name: "Your App"),
            presentationAnchor: anchor
        )
        
        let subOrgId = try await createSubOrganization(registration: registration)
        
        try await stampLoginAndCreateSession(
            anchor: anchor,
            organizationId: subOrgId,
            expiresInSeconds: "15"
        )
    }
    
    func loginWithPasskey(anchor: ASPresentationAnchor) async throws {
        guard isPasskeySupported else { throw AuthError.passkeysNotSupported }
        startLoading()
        defer { stopLoading() }
        
        try await stampLoginAndCreateSession(
            anchor: anchor,
            
            // parent orgId
            organizationId: "957f6bbe-2f29-4057-8fc6-c8db0070f608",
            expiresInSeconds: "180"
        )
    }
    
    private func createSubOrganization(registration: PasskeyRegistrationResult) async throws -> String {
        let body = CreateSubOrgRequest(registration: registration)
        
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
        expiresInSeconds: String
    ) async throws {
        let turnkeyClient = TurnkeyClient(
            rpId: "passkeyapp.tkhqlabs.xyz",
            presentationAnchor: anchor,
            baseUrl: "http://localhost:8081"
        )
        
        let publicKey = try turnkey.createKeyPair()
        
        let sessionResponse = try await turnkeyClient.stampLogin(
            organizationId: organizationId,
            publicKey: publicKey,
            expirationSeconds: expiresInSeconds,
            invalidateExisting: true
        )
        
        guard case let .json(body) = try sessionResponse.ok.body,
              let jwt = body.activity.result.stampLoginResult?.session
        else {
            throw AuthError.serverError
        }
        
        try await turnkey.createSession(jwt: jwt)
    }
    
    private func startLoading() {
        isLoading = true
        error = nil
    }
    
    private func stopLoading() {
        isLoading = false
    }
}
