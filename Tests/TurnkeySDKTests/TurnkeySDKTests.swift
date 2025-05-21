import CryptoKit
import OpenAPIRuntime
import OpenAPIURLSession
import SwiftDotenv
import Web3
import Web3PromiseKit
import XCTest

@testable import Shared
@testable import TurnkeySDK

final class TurnkeySDKTests: XCTestCase {
  var apiPrivateKey: String?
  var apiPublicKey: String?
  var organizationId: String?
  var privateKeyId: String?
  var walletFromAddress: String?
  var expectedUserId: String?
  var infuraAPIKey: String?

  override func setUp() {
    super.setUp()

    // load in environment variables
    do {
      try Dotenv.configure()
      apiPrivateKey = Dotenv.apiPrivateKey?.stringValue ?? ""
      apiPublicKey = Dotenv.apiPublicKey?.stringValue ?? ""
      organizationId = Dotenv.organizationId?.stringValue ?? ""
      privateKeyId = Dotenv.privateKeyId?.stringValue ?? ""
      infuraAPIKey = Dotenv.infuraAPIKey?.stringValue ?? ""
      walletFromAddress = Dotenv.walletFromAddress?.stringValue ?? ""
      expectedUserId = Dotenv.expectedUserId?.stringValue ?? ""
      // Check if required environment variables are defined
      guard apiPrivateKey != "",
        apiPublicKey != "",
        organizationId != "",
        privateKeyId != "",
        infuraAPIKey != "",
        walletFromAddress != ""
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

    do {
      let ok = try await client.getWhoami(organizationId: organizationId!)
      switch ok.body {
      case let .json(whoamiResponse):
        XCTAssertNotNil(whoamiResponse.organizationId)
        XCTAssertEqual(whoamiResponse.organizationName, "SDK E2E")
        XCTAssertEqual(whoamiResponse.userId, expectedUserId!)
        XCTAssertEqual(whoamiResponse.username, "Root user")
      }
    } catch let error as TurnkeyError {
      switch error {
      case let .apiError(code, payload):
        let msg = payload.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        XCTFail("API error \(code ?? -1): \(msg)")
      default:
        throw error
      }
    }
  }

  func testSetOrganizationFeature() async throws {
    // Create an instance of TurnkeyClient
    let client = TurnkeyClient(apiPrivateKey: apiPrivateKey!, apiPublicKey: apiPublicKey!)

    // Define the test input
    let featureName = Components.Schemas.FeatureName.FEATURE_NAME_WEBHOOK
    let featureValue = "https://example.com"

    do {
      let output = try await client.setOrganizationFeature(
        organizationId: organizationId!,
        name: featureName,
        value: featureValue)
      let activityResponse = try output.ok.body.json
      XCTAssertEqual(activityResponse.activity.organizationId, organizationId)
    } catch let error as TurnkeyError {
      if case let .apiError(code, payload) = error {
        let msg = payload.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        XCTFail("API error \(code ?? -1): \(msg)")
      } else {
        throw error
      }
    }
  }

  func testCreateSubOrganization() async throws {
    // Create an instance of TurnkeyClient
    let client = TurnkeyClient(apiPrivateKey: apiPrivateKey!, apiPublicKey: apiPublicKey!)

    // Define the test input
    let subOrganizationName = "Test Sub Organization"
    let rootUsers: [Components.Schemas.RootUserParamsV4] = [
      .init(
        userName: "user1",
        userEmail: "user1@example.com",
        apiKeys: [
          .init(
            apiKeyName: "turnkey-demo",
            publicKey: apiPublicKey!,
            curveType: .API_KEY_CURVE_P256
          )
        ],
        authenticators: [],
        oauthProviders: []
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
    let disableSmsAuth = false
    let disableOtpEmailAuth = false

    do {
      let output = try await client.createSubOrganization(
        organizationId: organizationId!,
        subOrganizationName: subOrganizationName,
        rootUsers: rootUsers,
        rootQuorumThreshold: rootQuorumThreshold,
        wallet: wallet,
        disableEmailRecovery: disableEmailRecovery,
        disableEmailAuth: disableEmailAuth,
        disableSmsAuth: disableSmsAuth,
        disableOtpEmailAuth: disableOtpEmailAuth
      )
      let activityResponse = try output.ok.body.json
      XCTAssertNotNil(activityResponse.activity)
      XCTAssertEqual(activityResponse.activity.organizationId, organizationId)
      if let result = activityResponse.activity.result.createSubOrganizationResultV7 {
        XCTAssertNotNil(result.subOrganizationId)
        if let rootUserIds = result.rootUserIds {
          XCTAssertEqual(rootUserIds.count, rootUsers.count)
        }
      }
    } catch let error as TurnkeyError {
      if case let .apiError(code, payload) = error {
        let msg = payload.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        XCTFail("API error \(code ?? -1): \(msg)")
      } else {
        throw error
      }
    }
  }

  func bodyToString(body: HTTPBody) -> Promise<String> {
    return Promise { seal in
      Task {
        do {
          let bodyString = try await String(collecting: body, upTo: .max)
          seal.fulfill(bodyString)
        } catch {
          seal.reject(error)
        }
      }
    }
  }

  /*  holesky is no more 😢
   TODO: Add testSignTransactionWithWeb3 with new testnet
  func testSignTransactionWithWeb3() async throws {
    try XCTSkip("Skipping network-dependent testSignTransactionWithWeb3")
    let expectation = XCTestExpectation(description: "Sign transaction and handle response")

    // Setup the Ethereum private key and web3 instance
    let web3 = Web3(rpcURL: "https://holesky.infura.io/v3/\(infuraAPIKey ?? "")")  // Replace with actual URL and project ID
    let from = try! EthereumAddress(hex: walletFromAddress ?? "", eip55: true)

    firstly {
      web3.eth.getTransactionCount(address: from, block: .latest)
    }.then { nonce -> Promise<String> in
      let transaction = EthereumTransaction(
        nonce: nonce,
        maxFeePerGas: EthereumQuantity(quantity: 21.gwei),
        maxPriorityFeePerGas: EthereumQuantity(quantity: 1.gwei),
        gasLimit: 29000,
        to: try! EthereumAddress(hex: "0x518AC04a5Bbc5846F0de774458565Ad5957c9017", eip55: true),
        value: EthereumQuantity(quantity: 1000.gwei),
        transactionType: .eip1559
      )

      let zeroQuantity = EthereumQuantity(integerLiteral: 0).quantity
      let maxPriorityFee = transaction.maxPriorityFeePerGas?.quantity ?? zeroQuantity
      let maxFeePerGas = transaction.maxFeePerGas?.quantity ?? zeroQuantity
      let gasLimit = transaction.gasLimit?.quantity ?? zeroQuantity
      let toAddress = transaction.to?.rawAddress ?? Bytes()
      let transactionValue = transaction.value?.quantity ?? zeroQuantity
      let _ = transaction.transactionType

      // Create an RLPItem representing the transaction for encoding
      // Important: Order matters here:
      let rlpItem: RLPItem = RLPItem.array([
        .bigUInt(EthereumQuantity(integerLiteral: 17000).quantity),
        .bigUInt(nonce.quantity),
        .bigUInt(maxPriorityFee),
        .bigUInt(maxFeePerGas),
        .bigUInt(gasLimit),
        .bytes(toAddress),
        .bigUInt(transactionValue),
        .bytes(Bytes()),  // input data
        .array([]),  // Access list
      ])

      // Serialize the RLPItem
      let serializedTransaction = try RLPEncoder().encode(rlpItem)
      // Append "02" for EIP-1159 transactions
      let transactionHexString =
        "02" + serializedTransaction.map { String(format: "%02x", $0) }.joined()

      return Promise.value(transactionHexString)

    }.then { transactionHexString -> Promise<Operations.SignTransaction.Output> in
      Promise { seal in
        Task {
          do {
            let client = TurnkeyClient(
              apiPrivateKey: self.apiPrivateKey!, apiPublicKey: self.apiPublicKey!)
            let response = try await client.signTransaction(
              organizationId: self.organizationId!,
              signWith: self.privateKeyId!,
              unsignedTransaction: transactionHexString,
              _type: .TRANSACTION_TYPE_ETHEREUM
            )
            seal.fulfill(response)
          } catch {
            seal.reject(error)
          }
        }
      }
    }.then { response -> Promise<String> in
      switch response {
      case let .ok(response):
        switch response.body {
        case let .json(activityResponse):
          if let signedTransaction = activityResponse.activity.result.signTransactionResult?
            .signedTransaction
          {
            return Promise.value(signedTransaction)
          } else {
            return Promise(
              error: NSError(
                domain: "SignTransactionError", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Signed transaction is nil"]))
          }
        }
      case let .undocumented(statusCode, undocumentedPayload):
        if let body = undocumentedPayload.body {
          return self.bodyToString(body: body).then { bodyString in
            XCTFail("Undocumented response body: \(bodyString)")
            return Promise<String>(
              error: NSError(
                domain: "UndocumentedResponseError", code: statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Undocumented response body: \(bodyString)"]))
          }
        }
        XCTFail("Undocumented response with status code: \(statusCode)")
        return Promise(
          error: NSError(
            domain: "UndocumentedResponseError", code: statusCode,
            userInfo: [
              NSLocalizedDescriptionKey: "Undocumented response with status code: \(statusCode)"
            ]))
      }
    }.then { signedTransaction -> Promise<String> in
      let request = BasicRPCRequest(
        id: 0,
        jsonrpc: Web3.jsonrpc,
        method: "eth_sendRawTransaction",
        params: ["0x" + signedTransaction]
      )
      return Promise { seal in
        web3.provider.send(request: request) { (response: Web3Response<EthereumData>) in
          switch response.status {
          case let .success(result):
            seal.fulfill(result.hex())
          case let .failure(error):
            seal.reject(error)
          }
        }
      }
    }
    .done { hash in
      print("Transaction hash - \(hash)")
      XCTAssertNotNil(hash, "Transaction hash should not be nil")
      expectation.fulfill()
    }.catch { error in
      XCTFail("Failed: \(error)")
      expectation.fulfill()
    }

    // Wait for the expectation to be fulfilled, or timeout after 10 seconds
    await fulfillment(of: [expectation], timeout: 10.0)
  }
  */

  func testGetWhoamiInvalidOrgThrowsApiError() async throws {
    let client = TurnkeyClient(apiPrivateKey: apiPrivateKey!, apiPublicKey: apiPublicKey!)

    do {
      _ = try await client.getWhoami(organizationId: "invalid-org-id")
      XCTFail("Expected TurnkeyError.apiError to be thrown for bad org id")
    } catch let error as TurnkeyError {
      guard case let .apiError(status, _) = error else {
        XCTFail("Unexpected error type: \(error)")
        return
      }
      XCTAssertNotEqual(status, 200, "Status should indicate failure")
    }
  }
}
