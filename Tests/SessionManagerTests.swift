import XCTest
@testable import TurnkeySDK

final class SessionManagerTests: XCTestCase {
    func testStub() throws {
        let session = Session(keyTag: "stub", expiresAt: .distantFuture)
        XCTAssertEqual(session.keyTag, "stub")
    }
}