import XCTest
@testable import TurnkeySDK

final class SigningTests: XCTestCase {
    // func testSignWithApiKey() async throws {
    //     // Given
    //     let content = "Hello, World!"
    //     let publicKey = "04d03c9d9c5e63f7504381e953d7c29bef1e6b2d6e9a4218a79a7cd1fdf1c1db04b1f8befd365cb3e0678a0b8e4c40c5a1e7a1f0e9d1c1f1c1db04b1f8befd365"
    //     let privateKey = "3c8e8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8"
        
    //     // When
    //     let signature = try await signWithApiKey(content: content, publicKey: publicKey, privateKey: privateKey)
        
    //     // Then
    //     XCTAssertEqual(signature.count, 128)
    // }
    
    // func testSignWithApiKey_InvalidPrivateKey() async throws {
    //     // Given
    //     let content = "Hello, World!"
    //     let publicKey = "04d03c9d9c5e63f7504381e953d7c29bef1e6b2d6e9a4218a79a7cd1fdf1c1db04b1f8befd365cb3e0678a0b8e4c40c5a1e7a1f0e9d1c1f1c1db04b1f8befd365"
    //     let privateKey = "invalid_private_key"
        
    //     // When & Then
    //     do {
    //         _ = try await signWithApiKey(content: content, publicKey: publicKey, privateKey: privateKey)
    //         XCTFail("Expected SigningError.invalidPrivateKey to be thrown")
    //     } catch SigningError.invalidPrivateKey {
    //         // Expected error
    //     } catch {
    //         XCTFail("Unexpected error: \(error)")
    //     }
    // }
    
    // func testSignWithApiKey_MismatchedPublicKey() async throws {
    //     // Given
    //     let content = "Hello, World!"
    //     let publicKey = "04d03c9d9c5e63f7504381e953d7c29bef1e6b2d6e9a4218a79a7cd1fdf1c1db04b1f8befd365cb3e0678a0b8e4c40c5a1e7a1f0e9d1c1f1c1db04b1f8befd365"
    //     let privateKey = "3c8e8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8"
    //     let mismatchedPublicKey = "04d03c9d9c5e63f7504381e953d7c29bef1e6b2d6e9a4218a79a7cd1fdf1c1db04b1f8befd365cb3e0678a0b8e4c40c5a1e7a1f0e9d1c1f1c1db04b1f8befd366"
        
    //     // When & Then
    //     do {
    //         _ = try await signWithApiKey(content: content, publicKey: mismatchedPublicKey, privateKey: privateKey)
    //         XCTFail("Expected SigningError.mismatchedPublicKey to be thrown")
    //     } catch
    //                 XCTFail("Expected SigningError.mismatchedPublicKey to be thrown")
    //     } catch SigningError.mismatchedPublicKey(let expected, let actual) {
    //         XCTAssertEqual(expected, publicKey)
    //         XCTAssertEqual(actual, mismatchedPublicKey)
    //     } catch {
    //         XCTFail("Unexpected error: \(error)")
    //     }
    // }
    
    // func testDecodeHex() throws {
    //     // Given
    //     let hex = "48656c6c6f2c20576f726c6421"
    //     let expectedData = Data("Hello, World!".utf8)
        
    //     // When
    //     let decodedData = try decodeHex(hex)
        
    //     // Then
    //     XCTAssertEqual(decodedData, expectedData)
    // }
    
    // func testDecodeHex_OddLengthString() throws {
    //     // Given
    //     let hex = "48656c6c6f2c20576f726c642"
        
    //     // When & Then
    //     XCTAssertThrowsError(try decodeHex(hex)) { error in
    //         XCTAssertEqual(error as? DecodingError, DecodingError.oddLengthString)
    //     }
    // }
    
    // func testDecodeHex_InvalidHexCharacter() throws {
    //     // Given
    //     let hex = "48656c6c6f2c20576f726c64xx"
        
    //     // When & Then
    //     XCTAssertThrowsError(try decodeHex(hex)) { error in
    //         XCTAssertEqual(error as? DecodingError, DecodingError.invalidHexCharacter)
    //     }
    // }
}