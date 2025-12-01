import Foundation
import TurnkeySwift
import SwiftUI
import AuthenticationServices
import Combine

/// Error types for login process
enum LoginError: LocalizedError {
    case noAccount
    case authenticationFailed
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noAccount:
            return "No account found with this email address"
        case .authenticationFailed:
            return "Authentication failed"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

/// Response type for getSubOrgIds API call
struct GetSubOrgIdsResponse: Codable {
    let organizationIds: [String]
}

/// View model for the login screen
@MainActor
final class LoginViewModel: ObservableObject {
    /// User's email address
    @Published var email = ""
    
    /// Loading state
    @Published var isLoading = false
    
    /// Error message to display
    @Published var errorMessage: String?
    
    /// Injectable passkey login for testing/decoupling
    typealias PasskeyLogin = (_ anchor: ASPresentationAnchor?) async throws -> Void
    private let passkeyLogin: PasskeyLogin
    typealias GetSubOrgIds = (_ email: String) async throws -> GetSubOrgIdsResponse
    private let fetchSubOrgIds: GetSubOrgIds
    
    /// Session manager to store authenticated client
    var sessionManager: SessionManager
    
    /// Initialize with required dependencies
    /// - Parameters:
    ///   - sessionManager: Session manager to store authenticated client
    ///   - passkeyLogin: Optional injected login closure (defaults to TurnkeyContext.loginWithPasskey)
    init(sessionManager: SessionManager, passkeyLogin: PasskeyLogin? = nil, fetchSubOrgIds: GetSubOrgIds? = nil) {
        self.sessionManager = sessionManager
        self.passkeyLogin = passkeyLogin ?? { anchor in
            guard let anchor else { return }
            try await TurnkeyContext.shared.loginWithPasskey(anchor: anchor)
        }
        self.fetchSubOrgIds = fetchSubOrgIds ?? { email in
            // Default network implementation
            guard let url = URL(string: "http://localhost:3000/proxy/sub-org-ids?filterType=EMAIL&filterValue=\(email)") else {
                throw LoginError.networkError(NSError(domain: "LoginViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw LoginError.networkError(NSError(domain: "LoginViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Server returned an error"]))
            }
            return try JSONDecoder().decode(GetSubOrgIdsResponse.self, from: data)
        }
    }
    
    /// Authenticate the user
    func authenticate(anchor: ASPresentationAnchor?) async {
        // Reset error message
        errorMessage = nil
        
        // Set loading state
        isLoading = true
        
        do {
            // 1. Look up sub-org IDs via proxy
            let response = try await fetchSubOrgIds(email)
            
            // 2. Check if any organizations were found
            guard let _ = response.organizationIds.first else {
                throw LoginError.noAccount
            }
            
            // 3. Perform passkey login (stores session internally)
            try await passkeyLogin(anchor)
            
        } catch let error as LoginError {
            // Handle known login errors
            errorMessage = error.localizedDescription
        } catch {
            // Handle other errors
            errorMessage = LoginError.networkError(error).localizedDescription
        }
        
        // Reset loading state
        isLoading = false
    }
    
}
