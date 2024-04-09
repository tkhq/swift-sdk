import XCTest
@testable import TurnkeyClient
// API_PUBLIC_KEY="03b0d74b5460c1a039bf26ea9027c38f33cf8feb34843f8373a9e3fbf2d7ce9280"
// API_PRIVATE_KEY="7debdb894403cf923ede0e16129cc0e144e9f1a3430da206aab3a3fd3e421380"
final class TurnkeySDKTests: XCTestCase {
    func testGetWhoamiLive() async throws {
        // Create an instance of TurnkeyClient
        let client = TurnkeyClient(apiPrivateKey: "7debdb894403cf923ede0e16129cc0e144e9f1a3430da206aab3a3fd3e421380", apiPublicKey: "03b0d74b5460c1a039bf26ea9027c38f33cf8feb34843f8373a9e3fbf2d7ce9280")

        // Call the GetWhoami method on the TurnkeyClient instance
        let output = try await client.getWhoami(organizationId: "acd0bc97-2af5-475b-bc34-0fa7ca3bdc75")
        
        // Assert the response
        switch output {
        case .ok(let response):
            switch response.body {
            case .json(let whoamiResponse):
                // Assert the expected properties in the whoamiResponse
                XCTAssertNotNil(whoamiResponse.organizationId)
                XCTAssertEqual(whoamiResponse.organizationName, "SDK E2E")
                XCTAssertEqual(whoamiResponse.userId, "c1fe55f0-28b7-450b-8cb6-47d175cb66f5")
                XCTAssertEqual(whoamiResponse.username, "Root user")
                // Add more assertions based on the expected response
            }
        case .undocumented(let statusCode, let undocumentedPayload):
            // Handle the undocumented response
            if let body = undocumentedPayload.body {
                // Convert the HTTPBody to a string
                let bodyString = try await String(collecting: body, upTo: .max)
                XCTFail("Undocumented response body: \(bodyString)")
            }
            XCTFail("Undocumented response: \(statusCode)")
        }
    }
}
