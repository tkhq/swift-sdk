import XCTest
import TurnkeySDK
@testable import TurnkeyiOSExample

// Mock TurnkeyClient for testing
class MockTurnkeyClient: TurnkeyClient {
    var shouldSucceed = true
    var subOrgIds: [String] = []
    
    override func login(organizationId: String) async throws -> TurnkeyClient {
        if shouldSucceed {
            return self
        } else {
            throw NSError(domain: "MockTurnkeyClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication failed"])
        }
    }
    
    // Mock implementation for getSubOrgIds
    func getSubOrgIds(filterType: String, filterValue: String) async throws -> GetSubOrgIdsResponse {
        if shouldSucceed {
            return GetSubOrgIdsResponse(organizationIds: subOrgIds)
        } else {
            throw NSError(domain: "MockTurnkeyClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server error"])
        }
    }
}

final class LoginViewModelTests: XCTestCase {
    
    var viewModel: LoginViewModel!
    var mockProxyClient: MockTurnkeyClient!
    var mockPasskeyClient: MockTurnkeyClient!
    var sessionManager: SessionManager!

    override func setUpWithError() throws {
        mockProxyClient = MockTurnkeyClient()
        mockPasskeyClient = MockTurnkeyClient()
        sessionManager = SessionManager()
        
        viewModel = LoginViewModel(
            proxyClient: mockProxyClient,
            passkeyClient: mockPasskeyClient,
            sessionManager: sessionManager
        )
    }

    override func tearDownWithError() throws {
        viewModel = nil
        mockProxyClient = nil
        mockPasskeyClient = nil
        sessionManager = nil
    }

    func testAuthenticateSuccess() async throws {
        // Arrange
        viewModel.email = "test@example.com"
        mockProxyClient.shouldSucceed = true
        mockProxyClient.subOrgIds = ["org-123"]
        mockPasskeyClient.shouldSucceed = true
        
        // Act
        await viewModel.authenticate()
        
        // Assert
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNotNil(sessionManager.client)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testAuthenticateNoAccount() async throws {
        // Arrange
        viewModel.email = "test@example.com"
        mockProxyClient.shouldSucceed = true
        mockProxyClient.subOrgIds = [] // Empty array means no account found
        
        // Act
        await viewModel.authenticate()
        
        // Assert
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "No account found with this email address")
        XCTAssertNil(sessionManager.client)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testAuthenticateFailedLogin() async throws {
        // Arrange
        viewModel.email = "test@example.com"
        mockProxyClient.shouldSucceed = true
        mockProxyClient.subOrgIds = ["org-123"]
        mockPasskeyClient.shouldSucceed = false // Login will fail
        
        // Act
        await viewModel.authenticate()
        
        // Assert
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNil(sessionManager.client)
        XCTAssertFalse(viewModel.isLoading)
    }
}
