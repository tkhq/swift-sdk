//
//  AccountManager.swift
//  TurnkeyiOSExample
//
//  Created by Taylor Dawson on 4/19/24.
//

import AuthenticationServices
import Foundation
import Shared
import TurnkeySDK
import os

extension NSNotification.Name {
  static let UserSignedIn = Notification.Name("UserSignedInNotification")
  static let ModalSignInSheetCanceled = Notification.Name("ModalSignInSheetCanceledNotification")
  static let PasskeyRegistrationCompleted = Notification.Name(
    "PasskeyRegistrationCompletedNotification")
  static let PasskeyRegistrationFailed = Notification.Name("PasskeyRegistrationFailedNotification")
  static let PasskeyRegistrationCanceled = Notification.Name(
    "PasskeyRegistrationCanceledNotification")
  static let InitEmailAuth = Notification.Name("InitEmailAuthNotification")
}

class AccountManager: NSObject, ASAuthorizationControllerPresentationContextProviding,
  ASAuthorizationControllerDelegate
{
  let domain = "turnkey-nextjs-demo-weld.vercel.app"
  let parentOrgId = "70189536-9086-4810-a9f0-990d4e7cd622"
  var authenticationAnchor: ASPresentationAnchor?
  var isPerformingModalRequest = false
  private var passkeyRegistration: PasskeyManager?
  private let authKeyManager: AuthKeyManager

  override init() {

    self.authKeyManager = AuthKeyManager(domain: domain)
    super.init()
    // Add observers for passkey registration notifications
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handlePasskeyRegistrationCompleted),
      name: .PasskeyRegistrationCompleted,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handlePasskeyRegistrationFailed),
      name: .PasskeyRegistrationFailed,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handlePasskeyRegistrationCanceled),
      name: .PasskeyRegistrationCanceled,
      object: nil
    )
  }

  deinit {
    // Remove observers when the AccountManager instance is deallocated
    NotificationCenter.default.removeObserver(self)
  }
  // func signIn(anchor: ASPresentationAnchor, preferImmediatelyAvailableCredentials: Bool) {
  func signIn(email: String, anchor: ASPresentationAnchor) async {
    let turnkeyClient = TurnkeyClient(rpId: domain, presentationAnchor: anchor)

    //        let organizationId = "acd0bc97-2af5-475b-bc34-0fa7ca3bdc75"

    do {
      // Call the GetWhoami method on the TurnkeyClient instance
      let output = try await turnkeyClient.getWhoami(organizationId: parentOrgId)

      // Assert the response
      switch output {
      case .ok(let response):
        switch response.body {
        case .json(let whoamiResponse):
          print(whoamiResponse)
        }
      case .undocumented(let statusCode, let undocumentedPayload):
        // Handle the undocumented response
        if let body = undocumentedPayload.body {
          // Convert the HTTPBody to a string
          let bodyString = try await String(collecting: body, upTo: .max)
          print("Undocumented response body: \(bodyString)")
        }
        print("Undocumented response: \(statusCode)")
      }
    } catch {
      print("Error occurred: \(error)")
    }

    isPerformingModalRequest = true
  }

  func signInEmailAuth(email: String, anchor: ASPresentationAnchor) async {

    // For email auth we need to proxy the request to a backend that can stamp it
    let proxyURL = "http://localhost:3000/api/email-auth"
    // We create a proxied instance of the Turnkey Client that can proxy requests to the backend
    let turnkeyClient = TurnkeyClient(proxyURL: proxyURL)

    do {
      let publicKey = try authKeyManager.createKeyPair()

      var targetPublicKey = Data([0x04])
      let rawRepresentation = publicKey.rawRepresentation
      targetPublicKey.append(rawRepresentation)

      let output = try await turnkeyClient.emailAuth(
        organizationId: parentOrgId,
        email: email,
        targetPublicKey: targetPublicKey.map { String(format: "%02x", $0) }.joined(),
        apiKeyName: "test-api-key-swift-sdk",
        expirationSeconds: "3600",
        emailCustomization: Components.Schemas.EmailCustomizationParams()
      )

      // Assert the response
      switch output {
      case .ok(let response):
        switch response.body {
        case .json(let emailAuthResponse):
          print(emailAuthResponse)
          DispatchQueue.main.async {
            self.initEmailAuth()
          }
        }
      case .undocumented(let statusCode, let undocumentedPayload):
        // Handle the undocumented response
        if let body = undocumentedPayload.body {
          let bodyString = try await String(collecting: body, upTo: .max)
          print("Undocumented response body: \(bodyString)")
        }
        print("Undocumented response: \(statusCode)")
      }
    } catch {
      print("Error occurred: \(error)")
    }
  }

  func verifyEncryptedBundle(bundle: String) async {
    do {
      let (privateKey, publicKey) = try authKeyManager.decryptBundle(bundle)

      let apiPublicKey = try publicKey.toString(representation: .compressed)
      let apiPrivateKey = try privateKey.toString(representation: .raw)

      print("apiPrivateKey: \(apiPrivateKey) - apiPublicKey:\(apiPublicKey)")
      // Initialize a new TurnkeyClient instance with the provided privateKey and publicKey
      let turnkeyClient = TurnkeyClient(apiPrivateKey: apiPrivateKey, apiPublicKey: apiPublicKey)
      let response = try await turnkeyClient.getWhoami(organizationId: parentOrgId)

      // Assert the response
      switch response {
      case .ok(let response):
        switch response.body {
        case .json(let emailAuthResponse):
          print(emailAuthResponse)
        }
      case .undocumented(let statusCode, let undocumentedPayload):
        // Handle the undocumented response
        if let body = undocumentedPayload.body {
          let bodyString = try await String(collecting: body, upTo: .max)
          print("Undocumented response body: \(bodyString)")
        }
        print("Undocumented response: \(statusCode)")
      }
    } catch {
      print("Error occurred: \(error)")
    }
  }

  func beginAutoFillAssistedPasskeySignIn(anchor: ASPresentationAnchor) {
    self.authenticationAnchor = anchor

    let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(
      relyingPartyIdentifier: domain)

    // Fetch the challenge from the server. The challenge needs to be unique for each request.
    let challenge = Data()
    let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(
      challenge: challenge)

    // AutoFill-assisted requests only support ASAuthorizationPlatformPublicKeyCredentialAssertionRequest.
    let authController = ASAuthorizationController(authorizationRequests: [assertionRequest])
    authController.delegate = self
    authController.presentationContextProvider = self
    authController.performAutoFillAssistedRequests()
  }

  func signUp(email: String, anchor: ASPresentationAnchor) {
    self.authenticationAnchor = anchor

    passkeyRegistration = PasskeyManager(rpId: domain, presentationAnchor: anchor)
    passkeyRegistration?.registerPasskey(email: email)

    isPerformingModalRequest = true
  }

  func sendCreateSubOrgRequest(passkeyRegistrationResult: PasskeyRegistrationResult) async throws {
    // For email auth we need to proxy the request to a backend that can stamp it
    let proxyURL = "http://localhost:3001/api/sign-up"

    // Create an instance of TurnkeyClient
    let client = TurnkeyClient(proxyURL: proxyURL)
      
      
      let attestation: Components.Schemas.Attestation = .init(credentialId: passkeyRegistrationResult.attestation.credentialId, clientDataJson: passkeyRegistrationResult.attestation.clientDataJson, attestationObject: passkeyRegistrationResult.attestation.attestationObject, transports: [.AUTHENTICATOR_TRANSPORT_BLE])

    // Define the test input
    let subOrganizationName = "Test Sub Organization"
    let rootUsers: [Components.Schemas.RootUserParams] = [
      .init(
        userName: "user1",
        userEmail: "user1@example.com",
        apiKeys: [],
        authenticators: [
            .init(authenticatorName: "Tuide - Simulator", challenge: passkeyRegistrationResult.challenge, attestation: attestation)
        ]
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
      organizationId: parentOrgId,
      subOrganizationName: subOrganizationName,
      rootUsers: rootUsers,
      rootQuorumThreshold: rootQuorumThreshold,
      wallet: wallet,
      disableEmailRecovery: disableEmailRecovery,
      disableEmailAuth: disableEmailAuth
    )

    // Assert the response
    switch output {
    case .ok(let response):
      switch response.body {
      case .json(let activityResponse):
        print(activityResponse)
      // Print the activity as JSON
      //           let encoder = JSONEncoder()
      //           encoder.outputFormatting = .prettyPrinted
      //           let jsonData = try encoder.encode(activityResponse.activity.result)
      //           if let jsonString = String(data: jsonData, encoding: .utf8) {
      //             print(jsonString)
      //           }

      }
    case .undocumented(let statusCode, let undocumentedPayload):
      // Handle the undocumented response
      if let body = undocumentedPayload.body {
        // Convert the HTTPBody to a string
        let bodyString = try await String(collecting: body, upTo: .max)
        print("Undocumented response body: \(bodyString)")
      }
      print("Undocumented response: \(statusCode)")
    }
  }

  @objc private func handlePasskeyRegistrationCompleted(_ notification: Notification) {
    guard let result = notification.userInfo?["result"] as? PasskeyRegistrationResult else {
      return
    }

    print("handlePasskeyRegistrationCompleted \(result)")
    Task {
      try await sendCreateSubOrgRequest(passkeyRegistrationResult: result)
      didFinishSignIn()
    }
    
  }

  @objc private func handlePasskeyRegistrationFailed(_ notification: Notification) {
    guard let error = notification.userInfo?["error"] as? PasskeyRegistrationError else {
      return
    }

    // Handle passkey registration failure
    // ...

    isPerformingModalRequest = false
  }

  @objc private func handlePasskeyRegistrationCanceled(_ notification: Notification) {
    // Handle passkey registration cancellation
    // ...

    didCancelModalSheet()
  }

  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    let logger = Logger()
    switch authorization.credential {
    case let credentialRegistration as ASAuthorizationPlatformPublicKeyCredentialRegistration:
      logger.log("A new passkey was registered: \(credentialRegistration)")
      // Verify the attestationObject and clientDataJSON with your service.
      // The attestationObject contains the user's new public key to store and use for subsequent sign-ins.
      // let attestationObject = credentialRegistration.rawAttestationObject
      // let clientDataJSON = credentialRegistration.rawClientDataJSON

      // After the server verifies the registration and creates the user account, sign in the user with the new account.
      didFinishSignIn()
    case let credentialAssertion as ASAuthorizationPlatformPublicKeyCredentialAssertion:
      logger.log("A passkey was used to sign in: \(credentialAssertion)")

      // Verify the below signature and clientDataJSON with your service for the given userID.
      // let signature = credentialAssertion.signature
      // let clientDataJSON = credentialAssertion.rawClientDataJSON
      // let userID = credentialAssertion.userID

      // After the server verifies the assertion, sign in the user.
      didFinishSignIn()
    case let passwordCredential as ASPasswordCredential:
      logger.log("A password was provided: \(passwordCredential)")
      // Verify the userName and password with your service.
      // let userName = passwordCredential.user
      // let password = passwordCredential.password

      // After the server verifies the userName and password, sign in the user.
      didFinishSignIn()
    default:
      fatalError("Received unknown authorization type.")
    }

    isPerformingModalRequest = false
  }

  func authorizationController(
    controller: ASAuthorizationController, didCompleteWithError error: Error
  ) {
    let logger = Logger()
    guard let authorizationError = error as? ASAuthorizationError else {
      isPerformingModalRequest = false
      logger.error("Unexpected authorization error: \(error.localizedDescription)")
      return
    }

    if authorizationError.code == .canceled {
      // Either the system doesn't find any credentials and the request ends silently, or the user cancels the request.
      // This is a good time to show a traditional login form, or ask the user to create an account.
      logger.log("Request canceled. isPerformingModalReqest: \(self.isPerformingModalRequest)")

      if isPerformingModalRequest {
        logger.log("didCancelModalSheet.")
        didCancelModalSheet()
      }
    } else {
      // Another ASAuthorization error.
      // Note: The userInfo dictionary contains useful information.
      logger.error("Error: \((error as NSError).userInfo)")
    }

    isPerformingModalRequest = false
  }

  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    return authenticationAnchor!
  }

  func didFinishSignIn() {
    NotificationCenter.default.post(name: .UserSignedIn, object: nil)
  }

  func didCancelModalSheet() {
    NotificationCenter.default.post(name: .ModalSignInSheetCanceled, object: nil)
  }

  func initEmailAuth() {
    NotificationCenter.default.post(name: .InitEmailAuth, object: nil)
  }
}
