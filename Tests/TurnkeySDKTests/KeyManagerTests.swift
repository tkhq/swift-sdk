import XCTest

@testable import Shared  // Replace with your actual module name

class KeyManagerTests: XCTestCase {
  var keyManager: KeyManager!

  override func setUp() {
    super.setUp()
    keyManager = KeyManager()
  }

  override func tearDown() {
    keyManager = nil
    super.tearDown()
  }

  func testCreateKeyPair_ReturnsPublicKey() {
    XCTAssertNoThrow(
      try {
        let publicKey = try keyManager.createKeyPair()
        XCTAssertNotNil(publicKey, "Public key should not be nil")
      }())
  }

  func testCreateKeyPair_ThrowsError() {
    // Assuming some condition that would cause an error, e.g., invalid attributes
    // This might require mocking or adjusting the environment to force an error
  }

  func testDecryptBundle_Success() {
    // Prepare a valid encrypted bundle string (this should be a base64 encoded string)
    let encryptedBundle = "ValidBase64EncodedString"  // Replace with actual valid encrypted data
    XCTAssertNoThrow(
      try {
        let decryptedString = try keyManager.decryptBundle(encryptedBundle)
        XCTAssertNotNil(decryptedString, "Decrypted string should not be nil")
      }())
  }

  func testDecryptBundle_InvalidBase64() {
    let encryptedBundle = "InvalidBase64"
    XCTAssertThrowsError(try keyManager.decryptBundle(encryptedBundle)) { error in
      guard let error = error as? NSError else {
        XCTFail("Error should be of type NSError")
        return
      }
      XCTAssertEqual(error.domain, "KeyManager")
      XCTAssertEqual(error.code, 0)
      XCTAssertEqual(
        error.userInfo[NSLocalizedDescriptionKey] as? String,
        "Failed to convert encrypted bundle to Data")
    }
  }

  func testDecryptBundle_FailureToRetrieveKey() {
    // This test would require the environment to be set up in a way that the key retrieval fails
    // Might require mocking or specific setup
  }
}
