import CryptoKit
import SwiftDotenv
import XCTest

@testable import Shared
@testable import TurnkeySDK

final class TurnkeySDKTests: XCTestCase {
  var apiPrivateKey: String?
  var apiPublicKey: String?
  var organizationId: String?

  override func setUp() {
    super.setUp()

    // load in environment variables
    do {
      try Dotenv.configure()
      apiPrivateKey = Dotenv.apiPrivateKey?.stringValue ?? ""
      apiPublicKey = Dotenv.apiPublicKey?.stringValue ?? ""
      organizationId = Dotenv.organizationId?.stringValue ?? ""
      // Check if required environment variables are defined
      guard apiPrivateKey != "",
        apiPublicKey != "",
        organizationId != ""
      else {
        XCTFail("Required environment variables are not defined.")
        return
      }
    } catch {
      XCTFail("Failed to load environment variables: \(error)")
    }
  }

  func testGetWhoami() async throws {
    // Create an instance of TurnkeyClient
    let client = TurnkeyClient(apiPrivateKey: apiPrivateKey!, apiPublicKey: apiPublicKey!)

    // Call the GetWhoami method on the TurnkeyClient instance
    let output = try await client.getWhoami(organizationId: organizationId!)

    // Assert the response
    switch output {
    case let .ok(response):
      switch response.body {
      case let .json(whoamiResponse):
        // Assert the expected properties in the whoamiResponse
        XCTAssertNotNil(whoamiResponse.organizationId)
        XCTAssertEqual(whoamiResponse.organizationName, "SDK E2E")
        XCTAssertEqual(whoamiResponse.userId, "c1fe55f0-28b7-450b-8cb6-47d175cb66f5")
        XCTAssertEqual(whoamiResponse.username, "Root user")
      // Add more assertions based on the expected response
      }
    case let .undocumented(statusCode, undocumentedPayload):
      // Handle the undocumented response
      if let body = undocumentedPayload.body {
        // Convert the HTTPBody to a string
        let bodyString = try await String(collecting: body, upTo: .max)
        XCTFail("Undocumented response body: \(bodyString)")
      }
      XCTFail("Undocumented response: \(statusCode)")
    }
  }

  func testSetOrganizationFeature() async throws {
    // Create an instance of TurnkeyClient
    let client = TurnkeyClient(apiPrivateKey: apiPrivateKey!, apiPublicKey: apiPublicKey!)

    // Define the test input
    let featureName = Components.Schemas.FeatureName.FEATURE_NAME_WEBHOOK
    let featureValue = "https://example.com"

    // Call the setOrganizationFeature method on the TurnkeyClient instance
    let output = try await client.setOrganizationFeature(
      organizationId: organizationId!,
      name: featureName,
      value: featureValue
    )

    // Assert the response
    switch output {
    case let .ok(response):
      switch response.body {
      case let .json(activityResponse):
        // Assert the expected properties in the activityResponse
        XCTAssertEqual(activityResponse.activity.organizationId, organizationId)
      }
    case let .undocumented(statusCode, undocumentedPayload):
      // Handle the undocumented response
      if let body = undocumentedPayload.body {
        // Convert the HTTPBody to a string
        let bodyString = try await String(collecting: body, upTo: .max)
        XCTFail("Undocumented response body: \(bodyString)")
      }
      XCTFail("Undocumented response: \(statusCode)")
    }
  }

  func testCreateSubOrganization() async throws {
    // Create an instance of TurnkeyClient
    let client = TurnkeyClient(apiPrivateKey: apiPrivateKey!, apiPublicKey: apiPublicKey!)

    // Define the test input
    let subOrganizationName = "Test Sub Organization"
    let rootUsers: [Components.Schemas.RootUserParams] = [
      .init(
        userName: "user1",
        userEmail: "user1@example.com",
        apiKeys: [
          .init(
            apiKeyName: "turnkey-demo",
            publicKey: apiPublicKey!
          )
        ],
        authenticators: []
      )
    ]
    let rootQuorumThreshold: Int32 = 1
    let wallet: Components.Schemas.WalletParams = .init(
      walletName: "Test Wallet",
      accounts: [
        .init(
          curve: .CURVE_SECP256K1,
          pathFormat: .PATH_FORMAT_BIP32,
          path: "m/44'/60'/0'/0/0",
          addressFormat: .ADDRESS_FORMAT_ETHEREUM
        )
      ]
    )
    let disableEmailRecovery = false
    let disableEmailAuth = false

    // Call the createSubOrganization method on the TurnkeyClient instance
    let output = try await client.createSubOrganization(
      organizationId: organizationId!,
      subOrganizationName: subOrganizationName,
      rootUsers: rootUsers,
      rootQuorumThreshold: rootQuorumThreshold,
      wallet: wallet,
      disableEmailRecovery: disableEmailRecovery,
      disableEmailAuth: disableEmailAuth
    )

    // Assert the response
    switch output {
    case let .ok(response):
      switch response.body {
      case let .json(activityResponse):
        // Assert the expected properties in the activityResponse
        XCTAssertEqual(activityResponse.activity.organizationId, organizationId)

        // Assert that the result is not nil
        XCTAssertNotNil(activityResponse.activity.result)

        // Assert that the subOrganizationId is not nil
        XCTAssertNotNil(
          activityResponse.activity.result.createSubOrganizationResultV4?.subOrganizationId)

        // Assert that the rootUserIds is not nil
        XCTAssertNotNil(activityResponse.activity.result.createSubOrganizationResultV4?.rootUserIds)

        // Assert that the rootUserIds count matches the expected count
        XCTAssertEqual(
          activityResponse.activity.result.createSubOrganizationResultV4?.rootUserIds?.count,
          rootUsers.count)
      }
    case let .undocumented(statusCode, undocumentedPayload):
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
