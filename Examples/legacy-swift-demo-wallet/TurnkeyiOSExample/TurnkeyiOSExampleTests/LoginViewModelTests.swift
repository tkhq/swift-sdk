import XCTest
@testable import TurnkeyiOSExample

final class LoginViewModelTests: XCTestCase {
    
    var viewModel: LoginViewModel!
    var sessionManager: SessionManager!
    var shouldLoginSucceed: Bool!
    var mockedOrgIds: [String]!

    override func setUpWithError() throws {
        sessionManager = SessionManager()
        shouldLoginSucceed = true
        mockedOrgIds = ["org-123"]
        
        viewModel = LoginViewModel(sessionManager: sessionManager, passkeyLogin: { _ in
            if self.shouldLoginSucceed == false {
                throw NSError(domain: "MockLogin", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication failed"])
            }
        }, fetchSubOrgIds: { _ in
            return GetSubOrgIdsResponse(organizationIds: self.mockedOrgIds)
        })
    }

    override func tearDownWithError() throws {
        viewModel = nil
        sessionManager = nil
        shouldLoginSucceed = nil
        mockedOrgIds = nil
    }

    func testAuthenticateSuccess() async throws {
        // Arrange
        viewModel.email = "test@example.com"
        mockedOrgIds = ["org-123"]
        shouldLoginSucceed = true
        
        // Act
        await viewModel.authenticate(anchor: nil)
        
        // Assert
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testAuthenticateNoAccount() async throws {
        // Arrange
        viewModel.email = "test@example.com"
        mockedOrgIds = [] // Empty array means no account found
        
        // Act
        await viewModel.authenticate(anchor: nil)
        
        // Assert
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "No account found with this email address")
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testAuthenticateFailedLogin() async throws {
        // Arrange
        viewModel.email = "test@example.com"
        mockedOrgIds = ["org-123"]
        shouldLoginSucceed = false // Login will fail
        
        // Act
        await viewModel.authenticate(anchor: nil)
        
        // Assert
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }
}
