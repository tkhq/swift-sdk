import HTTPTypes
import XCTest

@testable import TurnkeySDK

final class TurnkeyErrorTests: XCTestCase {
  func testHTTPInitRegistration() throws {
    let response = HTTPResponse(status: .badRequest)
    let err = TurnkeyError(httpResponse: response, body: Data("oops".utf8))
    guard case let .apiError(status, payload) = err else {
      XCTFail("Expected apiError")
      return
    }
    XCTAssertEqual(status, 400)
    XCTAssertEqual(payload, Data("oops".utf8))
  }

  func testHTTPInitApiKey() throws {
    let response = HTTPResponse(status: .unauthorized)
    let err = TurnkeyError(httpResponse: response, body: nil)
    XCTAssertEqual(err, .apiError(statusCode: 401, payload: nil))
  }

  func testEquatable() throws {
    let a = TurnkeyError.apiError(statusCode: 401, payload: nil)
    let b = TurnkeyError.apiError(statusCode: 401, payload: nil)
    XCTAssertEqual(a, b)
  }
}
