import Foundation
import TurnkeySDK
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
    
    /// Proxy client for email lookup
    private let proxyClient: TurnkeyClient
    
    /// Passkey client for authentication
    private let passkeyClient: TurnkeyClient
    
    /// Session manager to store authenticated client
    var sessionManager: SessionManager
    
    /// Initialize with required dependencies
    /// - Parameters:
    ///   - proxyClient: Client for proxy operations
    ///   - passkeyClient: Client for passkey authentication
    ///   - sessionManager: Session manager to store authenticated client
    init(proxyClient: TurnkeyClient, passkeyClient: TurnkeyClient, sessionManager: SessionManager) {
        self.proxyClient = proxyClient
        self.passkeyClient = passkeyClient
        self.sessionManager = sessionManager
    }
    
    /// Authenticate the user
    func authenticate() async {
        // Reset error message
        errorMessage = nil
        
        // Set loading state
        isLoading = true
        
        do {
            // 1. Look up sub-org IDs via proxy
            let response = try await getSubOrgIds(email: email)
            
            // 2. Check if any organizations were found
            guard let organizationId = response.organizationIds.first else {
                throw LoginError.noAccount
            }
            
            // 3. Perform passkey login
            let loggedInClient = try await passkeyClient.login(organizationId: organizationId)
            
            // 4. Save the authenticated client to session
            sessionManager.client = loggedInClient
            
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
    
    /// Get sub-organization IDs for an email
    /// - Parameter email: User's email address
    /// - Returns: Response with matching organization IDs
    private func getSubOrgIds(email: String) async throws -> GetSubOrgIdsResponse {
        // This would typically call the proxy client's getSubOrgIds method
        // For now, we'll simulate the API call
        
        // Create URL for the request
        guard let url = URL(string: "http://localhost:3000/proxy/sub-org-ids?filterType=EMAIL&filterValue=\(email)") else {
            throw LoginError.networkError(NSError(domain: "LoginViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
        }
        
        // Create and configure the request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Perform the request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check for valid response
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw LoginError.networkError(NSError(domain: "LoginViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Server returned an error"]))
        }
        
        // Decode the response
        return try JSONDecoder().decode(GetSubOrgIdsResponse.self, from: data)
    }
}
