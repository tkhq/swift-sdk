import Foundation
import ScopedRecoveryExample
import TurnkeyStamper
import TurnkeyTypes
import XCTest

@testable import TurnkeyHttp

private final class MockProtocol: URLProtocol {
  static var handler: ((URLRequest) throws -> (Int, Data))?
  override class func canInit(with request: URLRequest) -> Bool {
    request.url?.host == "recovery.test"
  }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    do {
      let (status, data) = try Self.handler!(request)
      client?.urlProtocol(
        self,
        didReceive: HTTPURLResponse(
          url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil
        )!, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }
  override func stopLoading() {}
}

private actor RecordingStamper: StampProvider {
  var payloads: [[String: Any]] = []
  var cancelStatusLookup = false
  func cancelNextStatusLookup() { cancelStatusLookup = true }
  func stamp(payload: String) async throws -> (stampHeaderName: String, stampHeaderValue: String) {
    let json = try JSONSerialization.jsonObject(with: Data(payload.utf8)) as! [String: Any]
    payloads.append(json)
    if cancelStatusLookup && json["activityId"] != nil { throw CancellationError() }
    return ("X-Stamp", "test-stamp")
  }
}

final class RecoveryRequestTests: XCTestCase {
  override func setUp() {
    super.setUp()
    URLProtocol.registerClass(MockProtocol.self)
  }
  override func tearDown() {
    URLProtocol.unregisterClass(MockProtocol.self)
    MockProtocol.handler = nil
    super.tearDown()
  }

  private func response(status: String, result: Any = NSNull()) throws -> Data {
    try JSONSerialization.data(withJSONObject: [
      "activity": [
        "id": "held-login", "fingerprint": "held-fingerprint", "organizationId": "suborg",
        "status": status, "type": "ACTIVITY_TYPE_OTP_LOGIN_V2", "intent": [:], "result": result,
        "canApprove": true, "canReject": true, "votes": [],
        "createdAt": ["seconds": "1", "nanos": "0"],
        "updatedAt": ["seconds": "1", "nanos": "0"],
      ]
    ])
  }

  func testApproveAndRejectUseActivityEnvelope() async throws {
    let data = try response(status: "ACTIVITY_STATUS_COMPLETED")
    MockProtocol.handler = { _ in (200, data) }
    let stamper = RecordingStamper()
    let client = TurnkeyClient(
      organizationId: "suborg", baseUrl: "https://recovery.test", stamper: stamper)
    let approval = try await client.approveActivity(
      TApproveActivityBody(
        timestampMs: "123", organizationId: "explicit-org", fingerprint: "held-fingerprint"
      ))
    XCTAssertEqual(approval.activity.fingerprint, "held-fingerprint")
    _ = try await client.rejectActivity(TRejectActivityBody(fingerprint: "held-fingerprint"))
    let payloads = await stamper.payloads
    XCTAssertEqual(payloads.count, 2)
    for (index, payload) in payloads.enumerated() {
      XCTAssertEqual(
        payload["type"] as? String,
        index == 0 ? "ACTIVITY_TYPE_APPROVE_ACTIVITY" : "ACTIVITY_TYPE_REJECT_ACTIVITY")
      XCTAssertEqual(payload["organizationId"] as? String, index == 0 ? "explicit-org" : "suborg")
      XCTAssertNotNil(payload["timestampMs"] as? String)
      XCTAssertEqual(
        (payload["parameters"] as? [String: String])?["fingerprint"], "held-fingerprint")
      XCTAssertNil(payload["fingerprint"])
    }
    XCTAssertEqual(payloads[0]["timestampMs"] as? String, "123")
  }

  func testHeldQueriesAndDecisionsDecodeNullResults() async throws {
    let held = try response(status: "ACTIVITY_STATUS_AUTHENTICATORS_NEEDED")
    MockProtocol.handler = { _ in (200, held) }
    let client = TurnkeyClient(
      organizationId: "suborg", baseUrl: "https://recovery.test", stamper: RecordingStamper())
    let queried = try await client.getActivity(TGetActivityBody(activityId: "held-login"))
    let approved = try await client.approveActivity(
      TApproveActivityBody(fingerprint: "held-fingerprint"))
    let rejected = try await client.rejectActivity(
      TRejectActivityBody(fingerprint: "held-fingerprint"))
    for activity in [queried.activity, approved.activity, rejected.activity] {
      XCTAssertEqual(activity.status, .activity_status_authenticators_needed)
      XCTAssertNil(activity.result.otpLoginResult)
    }
    var json = try JSONSerialization.jsonObject(with: held) as! [String: Any]
    var activity = json["activity"] as! [String: Any]
    activity.removeValue(forKey: "result")
    json["activity"] = activity
    let missing = try JSONDecoder().decode(
      TGetActivityResponse.self, from: JSONSerialization.data(withJSONObject: json))
    XCTAssertNil(missing.activity.result.otpLoginResult)
    activity["result"] = ["otpLoginResult": ["session": 123]]
    json["activity"] = activity
    XCTAssertThrowsError(
      try JSONDecoder().decode(
        TGetActivityResponse.self, from: JSONSerialization.data(withJSONObject: json)))
  }

  func testResumeHeldLoginDecodesNullResult() async throws {
    let held = try response(status: "ACTIVITY_STATUS_AUTHENTICATORS_NEEDED")
    let requirements = Data("{\"mfaStatuses\":[]}".utf8)
    MockProtocol.handler = { request in
      (200, request.url!.path.hasSuffix("get_mfa_status") ? requirements : held)
    }
    let key = try Stamper.createOnDeviceKeyPair()
    defer { try? Stamper.deleteOnDeviceKeyPair(publicKeyHex: key) }
    do {
      _ = try await ScopedRecovery.resumeOtpLogin(
        activityId: "held-login", attestedIdentity: "token", attestedPublicKey: key,
        scheme: .p256VerificationToken,
        configuration: .init(
          organizationId: "suborg", sessionProfileId: "recovery", apiUrl: "https://recovery.test"),
        maxAttempts: 1
      )
      XCTFail("Expected MFA hold")
    } catch let error as MfaRequiredError {
      XCTAssertEqual(error.activity.fingerprint, "held-fingerprint")
      XCTAssertNil(error.activity.result.otpLoginResult)
    }
  }

  func testValidateTvcImageUsesQueryTypes() async throws {
    MockProtocol.handler = { _ in (200, Data("{\"resolvedImageDigest\":\"sha256:test\"}".utf8)) }
    let stamper = RecordingStamper()
    let client = TurnkeyClient(
      organizationId: "suborg", baseUrl: "https://recovery.test", stamper: stamper)
    let result = try await client.validateTvcImage(
      TValidateTvcImageBody(pivotContainerImageUrl: "registry.test/image:tag"))
    XCTAssertEqual(result.resolvedImageDigest, "sha256:test")
    let payloads = await stamper.payloads
    XCTAssertEqual(payloads[0]["pivotContainerImageUrl"] as? String, "registry.test/image:tag")
    XCTAssertNil(payloads[0]["type"])
    XCTAssertNil(payloads[0]["parameters"])
  }

  func testPollingAndMfaStatusUseActivityOrganization() async throws {
    let pending = try response(status: "ACTIVITY_STATUS_PENDING")
    let held = try response(status: "ACTIVITY_STATUS_AUTHENTICATORS_NEEDED")
    MockProtocol.handler = { request in
      if request.url!.path.hasSuffix("get_activity") { return (200, held) }
      if request.url!.path.hasSuffix("get_mfa_status") {
        return (200, Data("{\"mfaStatuses\":[]}".utf8))
      }
      return (200, pending)
    }
    let stamper = RecordingStamper()
    let client = TurnkeyClient(
      organizationId: "parent", baseUrl: "https://recovery.test", stamper: stamper,
      activityPoller: .init(intervalMs: 0))
    do {
      let _: TOtpLoginResponse = try await client.activity(
        "/login", body: TApproveActivityBody(organizationId: "suborg", fingerprint: "test"),
        activityType: "ACTIVITY_TYPE_OTP_LOGIN_V2", resultKey: "otpLoginResult")
      XCTFail("Expected MFA hold")
    } catch let error as MfaRequiredError {
      XCTAssertEqual(error.activity.organizationId, "suborg")
    }
    let payloads = await stamper.payloads
    XCTAssertEqual(payloads.count, 3)
    for payload in payloads { XCTAssertEqual(payload["organizationId"] as? String, "suborg") }
  }

  func testGeneratedEthereumMappings() async throws {
    let sent = try response(
      status: "ACTIVITY_STATUS_COMPLETED",
      result: [
        "ethSendTransactionResult": ["sendTransactionStatusId": "status-id"]
      ])
    let undelegated = try response(
      status: "ACTIVITY_STATUS_COMPLETED",
      result: [
        "ethUndelegate7702Result": ["sendTransactionStatusId": "undelegation-status"]
      ])
    MockProtocol.handler = { request in
      (200, request.url!.path.hasSuffix("eth_send_transaction") ? sent : undelegated)
    }
    let stamper = RecordingStamper()
    let client = TurnkeyClient(
      organizationId: "suborg", baseUrl: "https://recovery.test", stamper: stamper)
    let result = try await client.ethSendTransaction(
      TEthSendTransactionBody(
        caip2: "eip155:1", from: "0x123", to: "0x456"
      ))
    XCTAssertEqual(result.sendTransactionStatusId, "status-id")
    _ = try await client.ethUndelegate7702(TEthUndelegate7702Body(caip2: "eip155:1", from: "0x123"))
    let payloads = await stamper.payloads
    XCTAssertEqual(payloads[0]["type"] as? String, "ACTIVITY_TYPE_ETH_SEND_TRANSACTION")
    XCTAssertEqual(payloads[1]["type"] as? String, "ACTIVITY_TYPE_ETH_UNDELEGATE_7702")
  }

  func testMfaStopsInitialResponseAndReturnsRequirements() async throws {
    let held = try response(status: "ACTIVITY_STATUS_AUTHENTICATORS_NEEDED")
    let requirements = try JSONSerialization.data(withJSONObject: [
      "mfaStatuses": [
        [
          "mfaPolicyId": "policy", "requiredMethods": [], "satisfied": false,
          "satisfiedMethods": [], "userId": "same-user",
        ]
      ]
    ])
    MockProtocol.handler = { request in
      (200, request.url!.path.hasSuffix("get_mfa_status") ? requirements : held)
    }
    let stamper = RecordingStamper()
    let client = TurnkeyClient(
      organizationId: "suborg", baseUrl: "https://recovery.test", stamper: stamper)
    do {
      let _: TOtpLoginResponse = try await client.activity(
        "/login", body: TApproveActivityBody(fingerprint: "test"),
        activityType: "ACTIVITY_TYPE_OTP_LOGIN_V2", resultKey: "otpLoginResult")
      XCTFail("Expected MFA hold")
    } catch let error as MfaRequiredError {
      XCTAssertEqual(error.activity.fingerprint, "held-fingerprint")
      XCTAssertEqual(error.mfaStatuses.first?.mfaPolicyId, "policy")
    }
    let count = await stamper.payloads.count
    XCTAssertEqual(count, 2)
  }

  func testMfaHoldSurvivesFailedStatusLookupAfterPolling() async throws {
    let pending = try response(status: "ACTIVITY_STATUS_PENDING")
    let held = try response(status: "ACTIVITY_STATUS_AUTHENTICATORS_NEEDED")
    MockProtocol.handler = { request in
      if request.url!.path.hasSuffix("get_activity") { return (200, held) }
      if request.url!.path.hasSuffix("get_mfa_status") { return (403, Data()) }
      return (200, pending)
    }
    let stamper = RecordingStamper()
    let client = TurnkeyClient(
      organizationId: "suborg", baseUrl: "https://recovery.test", stamper: stamper,
      activityPoller: ActivityPollerConfig(intervalMs: 0))
    do {
      let _: TOtpLoginResponse = try await client.activity(
        "/login", body: TApproveActivityBody(fingerprint: "test"),
        activityType: "ACTIVITY_TYPE_OTP_LOGIN_V2", resultKey: "otpLoginResult")
      XCTFail("Expected MFA hold")
    } catch let error as MfaRequiredError {
      XCTAssertEqual(error.activity.id, "held-login")
      XCTAssertEqual(error.activity.fingerprint, "held-fingerprint")
      XCTAssertTrue(error.mfaStatuses.isEmpty)
    }
    let payloads = await stamper.payloads
    XCTAssertEqual(payloads.count, 3)
    XCTAssertEqual(payloads[1]["organizationId"] as? String, "suborg")
  }

  func testMfaHoldSurvivesCancelledStatusStamp() async throws {
    let held = try response(status: "ACTIVITY_STATUS_AUTHENTICATORS_NEEDED")
    MockProtocol.handler = { _ in (200, held) }
    let stamper = RecordingStamper()
    await stamper.cancelNextStatusLookup()
    let client = TurnkeyClient(
      organizationId: "suborg", baseUrl: "https://recovery.test", stamper: stamper)
    do {
      let _: TOtpLoginResponse = try await client.activity(
        "/login", body: TApproveActivityBody(fingerprint: "test"),
        activityType: "ACTIVITY_TYPE_OTP_LOGIN_V2", resultKey: "otpLoginResult")
      XCTFail("Expected MFA hold")
    } catch let error as MfaRequiredError {
      XCTAssertEqual(error.activity.fingerprint, "held-fingerprint")
      XCTAssertTrue(error.mfaStatuses.isEmpty)
    }
  }
}
