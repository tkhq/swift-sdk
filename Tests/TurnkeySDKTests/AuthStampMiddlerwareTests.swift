import XCTest
import HTTPTypes
import OpenAPIRuntime
import CryptoKit

@testable import AuthStampMiddleware

final class AuthStampMiddlewareTests: XCTestCase {
    // func testTurnkeyStamp() async throws {
    //     // Given
    //     let apiPrivateKey = "7debdb894403cf923ede0e16129cc0e144e9f1a3430da206aab3a3fd3e421380"
    //     let apiPublicKey = "03b0d74b5460c1a039bf26ea9027c38f33cf8feb34843f8373a9e3fbf2d7ce9280"
    //     let middleware = AuthStampMiddleware(apiPrivateKey: apiPrivateKey, apiPublicKey: apiPublicKey)
    //     let data = "{\"organizationId\":\"70189536-9086-4810-a9f0-990d4e7cd622\"}"
        
    //     // When
    //     let stamp = try await middleware.turnkeyStamp(data: data)
    //     print(stamp)
    //     // Then
    //     XCTAssertNotNil(stamp)
    //     // Add more assertions based on your expected stamp format and values
    // }

    // func testStampSignatureValidation() async throws {
        // Create an instance of AuthStampMiddleware with test keys
        // let apiPrivateKey = "7debdb894403cf923ede0e16129cc0e144e9f1a3430da206aab3a3fd3e421380"
        // let apiPublicKey = "03b0d74b5460c1a039bf26ea9027c38f33cf8feb34843f8373a9e3fbf2d7ce9280"
        // let middleware = AuthStampMiddleware(apiPrivateKey: apiPrivateKey, apiPublicKey: apiPublicKey)
        // let data = "{\"organizationId\":\"70189536-9086-4810-a9f0-990d4e7cd622\"}"

        // Create a test request and body
        // var request = HTTPRequest(method: .post, scheme: nil, authority: nil, path: "/", headerFields: [:])
        // let body = "test_body"

        // // Intercept the request and add the stamp
        // let (response, _) = try await middleware.intercept(request, body: HTTPBody(body.data(using: .utf8)!), baseURL: URL(string: "https://api.turnkey.com")!, operationID: "testOperation", next: { req, body, url in
        //     return (HTTPResponse(status: .ok), nil)
        // })

        // // Extract the stamp from the response headers
        // let stampHeader = response.headerFields[.xStamp]
        // XCTAssertNotNil(stampHeader, "Stamp header should be present")

    //     let stamp = try await middleware.turnkeyStamp(data: data)

    //     // Decode the stamp and verify the signature
    //     let decodedStamp = try XCTUnwrap(Data(base64Encoded: stamp))
    //     let stampDict = try JSONSerialization.jsonObject(with: decodedStamp, options: []) as? [String: Any]
        
    //     let signature = try XCTUnwrap(stampDict?["signature"] as? String)
    //     let publicKeyHex = try XCTUnwrap(stampDict?["publicKey"] as? String)

    //     let publicKeyData = try XCTUnwrap(Data(hexString: publicKeyHex))
    //     let publicKey = try P256.Signing.PublicKey(compressedRepresentation: publicKeyData)

    //     let dataHash = SHA256.hash(data: data.data(using: .utf8)!)
    //     let signatureData = try XCTUnwrap(Data(hexString: signature))
        
    //     // Convert the signatureData from Data to P256.Signing.ECDSASignature
    //     let ecdsaSignature = try P256.Signing.ECDSASignature(derRepresentation: signatureData)
        
    //     XCTAssertTrue(publicKey.isValidSignature(ecdsaSignature, for: dataHash))
    // }

    // func testTurnkeyStampWithInvalidPrivateKey() async throws {
    //     // Given
    //     let apiPrivateKey = "invalid_private_key"
    //     let apiPublicKey = "your_public_key_here"
    //     let middleware = AuthStampMiddleware(apiPrivateKey: apiPrivateKey, apiPublicKey: apiPublicKey)
    //     let data = "test_data"
        
    //     // When & Then
    //     do {
    //         _ = try await middleware.turnkeyStamp(data: data)
    //         XCTFail("Expected TurnkeyError.invalidPrivateKey to be thrown")
    //     } catch TurnkeyError.invalidPrivateKey {
    //         // Expected error thrown
    //     } catch {
    //         XCTFail("Unexpected error thrown: \(error)")
    //     }
    // }
    
    // func testTurnkeyStampWithMismatchedPublicKey() async throws {
    //     // Given
    //     let apiPrivateKey = "your_private_key_here"
    //     let apiPublicKey = "mismatched_public_key"
    //     let middleware = AuthStampMiddleware(apiPrivateKey: apiPrivateKey, apiPublicKey: apiPublicKey)
    //     let data = "test_data"
        
    //     // When & Then
    //     do {
    //         _ = try await middleware.turnkeyStamp(data: data)
    //         XCTFail("Expected TurnkeyError.mismatchedPublicKey to be thrown")
    //     } catch TurnkeyError.mismatchedPublicKey {
    //         // Expected error thrown
    //     } catch {
    //         XCTFail("Unexpected error thrown: \(error)")
    //     }
    // }
}

// extension AuthStampMiddleware {
//     func turnkeyStamp(data: String) async throws -> String {
//         try await self.turnkeyStamp(data: data)
//     }
// }

// extension HTTPField.Name {
//     static let xStamp = HTTPField.Name("X-Stamp")!
// }
