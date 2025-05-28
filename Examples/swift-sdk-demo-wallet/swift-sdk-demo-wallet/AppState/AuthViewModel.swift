import Foundation
import AuthenticationServices

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
    
    private let authService: AuthService
    
    init(authService: AuthService) {
        self.authService = authService
    }
    
    func signUpWithPasskey(anchor: ASPresentationAnchor) async {
        isLoading = true
        error = nil
        do {
            try await authService.signUpWithPasskey(anchor: anchor)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    func loginWithPasskey(anchor: ASPresentationAnchor) async {
        isLoading = true
        error = nil
        do {
            try await authService.loginWithPasskey(anchor: anchor)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    func sendOtp(contact: String, type: AuthService.OtpType) async -> (otpId: String, publicKey: String)? {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            return try await authService.sendOtp(contact: contact, type: type)
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    
    func verifyOtp(
        otpId: String,
        otpCode: String,
        filterType: AuthService.OtpType,
        contact: String,
        publicKey: String
    ) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            try await authService.verifyOtp(
                otpId: otpId,
                otpCode: otpCode,
                filterType: filterType,
                contact: contact,
                publicKey: publicKey
            )
        } catch {
            self.error = error.localizedDescription
        }
    }
}
