import XCTest

@testable import Shared
@testable import TurnkeySDK

final class SessionManagerTests: XCTestCase {

    func testEnsureActiveSessionCreatesAndReuses() throws {
        let mock = InMemoryKeyManagerMock()
        let manager = SessionManager(keyManager: mock)

        let first = try manager.ensureActiveSession()
        XCTAssertFalse(first.keyTag.isEmpty)

        // Second call should reuse the same unexpired session
        let second = try manager.ensureActiveSession()
        XCTAssertEqual(first, second)
    }

    func testSignRequestProducesSignature() throws {
        let mock = InMemoryKeyManagerMock()
        let manager = SessionManager(keyManager: mock)

        let data = "hello".data(using: .utf8)!
        let result = try manager.signRequest(data)

        XCTAssertEqual(result.signature.count, 64)
        XCTAssertEqual(result.publicKey.first, 0x04) // uncompressed pubkey prefix
    }

    func testSessionExpiryReturnsNil() throws {
        let mock = InMemoryKeyManagerMock()
        let manager = SessionManager(keyManager: mock)

        let tag = try mock.createKeypair()
        // Save an already-expired session
        let expired = Session(keyTag: tag, expiresAt: Date().addingTimeInterval(-3600))
        try manager.save(session: expired)

        XCTAssertNil(manager.activeSession())
    }
}
