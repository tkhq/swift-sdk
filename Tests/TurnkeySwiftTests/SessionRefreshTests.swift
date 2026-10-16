import Foundation
import TurnkeyHttp
import XCTest

@testable import TurnkeySwift

private final class RefreshProtocol: URLProtocol {
  static var handler: ((URLRequest) throws -> Data)?
  override class func canInit(with request: URLRequest) -> Bool {
    request.url?.host == "refresh.test"
  }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    do {
      let data = try Self.handler!(request)
      client?.urlProtocol(
        self,
        didReceive: HTTPURLResponse(
          url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
        cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch { client?.urlProtocol(self, didFailWithError: error) }
  }
  override func stopLoading() {}
}

private func sessionJwt(publicKey: String, profile: String?) throws -> String {
  var claims: [String: Any] = [
    "exp": Date().timeIntervalSince1970 + 3600,
    "public_key": publicKey, "session_type": "SESSION_TYPE_READ_WRITE",
    "user_id": "same-user", "organization_id": "suborg",
  ]
  if let profile {
    claims["session_type"] = "Recovery"
    claims["session_profile_id"] = profile
    claims["scope"] = "authenticator-enrollment"
  }
  let payload = try JSONSerialization.data(withJSONObject: claims).base64EncodedString()
    .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
    .replacingOccurrences(of: "=", with: "")
  return "e30.\(payload).signature"
}

private func refreshResponse(
  _ request: URLRequest, expectedProfile: String?, onRequest: (() -> Void)? = nil
) throws -> Data {
  var data = request.httpBody ?? Data()
  if let stream = request.httpBodyStream {
    stream.open()
    defer { stream.close() }
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
      let count = stream.read(&buffer, maxLength: buffer.count)
      if count <= 0 { break }
      data.append(contentsOf: buffer.prefix(count))
    }
  }
  let payload = try JSONSerialization.jsonObject(with: data) as! [String: Any]
  let parameters = payload["parameters"] as! [String: Any]
  XCTAssertEqual(payload["organizationId"] as? String, "suborg")
  XCTAssertEqual(parameters["sessionProfileId"] as? String, expectedProfile)
  let key = try XCTUnwrap(parameters["publicKey"] as? String)
  let jwt = try sessionJwt(publicKey: key, profile: parameters["sessionProfileId"] as? String)
  return try JSONSerialization.data(withJSONObject: [
    "activity": [
      "id": "refresh", "fingerprint": "refresh-fingerprint", "organizationId": "suborg",
      "status": "ACTIVITY_STATUS_COMPLETED", "type": "ACTIVITY_TYPE_STAMP_LOGIN",
      "intent": [:], "result": ["stampLoginResult": ["session": jwt]],
      "canApprove": false, "canReject": false, "votes": [],
      "createdAt": ["seconds": "1", "nanos": "0"], "updatedAt": ["seconds": "1", "nanos": "0"],
    ]
  ])
}

final class SessionRefreshTests: XCTestCase {
  override func setUp() {
    super.setUp()
    URLProtocol.registerClass(RefreshProtocol.self)
  }
  override func tearDown() {
    URLProtocol.unregisterClass(RefreshProtocol.self)
    RefreshProtocol.handler = nil
    super.tearDown()
  }

  @MainActor
  private func exerciseRefresh(selected: Bool, profile: String?, automatic: Bool = false)
    async throws
  {
    let context = TurnkeyContext(
      config: .init(organizationId: "parent", apiUrl: "https://refresh.test"),
      startBackgroundTasks: false)
    let sessionKey = "refresh-test-\(UUID().uuidString)"
    let oldKey = try context.createKeyPair()
    let jwt = try sessionJwt(publicKey: oldKey, profile: profile)
    let decoded = try JWTDecoder.decode(jwt, as: TurnkeySession.self)
    try context.persistSession(
      stored: decoded, jwt: jwt, sessionKey: sessionKey,
      refreshedSessionTTLSeconds: automatic ? "3600" : nil)
    defer { try? context.purgeStoredSession(for: sessionKey, keepAutoRefresh: false) }
    if selected {
      context.selectedSessionKey = sessionKey
      context.authState = .authenticated
      context.session = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(decoded))
      context.client = try TurnkeyClient(
        apiPublicKey: oldKey, organizationId: "suborg", baseUrl: "https://refresh.test")
    }
    RefreshProtocol.handler = { request in try refreshResponse(request, expectedProfile: profile) }
    if automatic {
      context.scheduleExpiryTimer(
        for: sessionKey, expTimestamp: Date().timeIntervalSince1970 + 60, buffer: 59.9)
      for _ in 0..<500 {
        if let refreshed = try JwtSessionStore.load(key: sessionKey)?.decoded,
          refreshed.publicKey != oldKey,
          !selected || context.session?.publicKey == refreshed.publicKey
        {
          break
        }
        try await Task.sleep(nanoseconds: 10_000_000)
      }
    } else {
      try await context.refreshSession(sessionKey: sessionKey)
    }
    let refreshed = try XCTUnwrap(JwtSessionStore.load(key: sessionKey)?.decoded)
    XCTAssertNotEqual(refreshed.publicKey, oldKey)
    XCTAssertEqual(refreshed.sessionProfileId, profile)
    XCTAssertEqual(refreshed.scope, profile == nil ? nil : "authenticator-enrollment")
    if selected {
      XCTAssertEqual(context.session?.sessionProfileId, profile)
      XCTAssertEqual(context.session?.scope, refreshed.scope)
    }
  }

  @MainActor
  func testSelectedAndBackgroundRefreshPreserveProfile() async throws {
    for selected in [true, false] {
      for profile in [nil, "recovery-profile"] {
        try await exerciseRefresh(selected: selected, profile: profile)
      }
    }
  }

  @MainActor
  func testAutomaticRefreshPreservesProfile() async throws {
    try await exerciseRefresh(selected: true, profile: "recovery-profile", automatic: true)
    try await exerciseRefresh(selected: false, profile: "recovery-profile", automatic: true)
  }
}
