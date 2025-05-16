import XCTest

@testable import TurnkeySDK

final class SecureEnclaveKeyManagerTests: XCTestCase {
  func testStub() throws {
    let manager = SecureEnclaveKeyManager()
    XCTAssertNotNil(manager)
  }

  func testCreateKeypair_andPublicKey() throws {
    let manager = SecureEnclaveKeyManager()
    let tag = try manager.createKeypair()
    XCTAssertFalse(tag.isEmpty)

    let pub = try manager.publicKey(tag: tag)
    XCTAssertEqual(pub.first, 0x04)
    XCTAssertEqual(pub.count, 65)
  }
}
