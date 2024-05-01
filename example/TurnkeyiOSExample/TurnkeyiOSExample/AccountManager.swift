//
//  AccountManager.swift
//  TurnkeyiOSExample
//
//  Created by Taylor Dawson on 4/19/24.
//

import AuthenticationServices
import Foundation
import os
import Shared
import TurnkeySDK

extension NSNotification.Name {
    static let UserSignedIn = Notification.Name("UserSignedInNotification")
    static let ModalSignInSheetCanceled = Notification.Name("ModalSignInSheetCanceledNotification")
    static let PasskeyRegistrationCompleted = Notification.Name("PasskeyRegistrationCompletedNotification")
    static let PasskeyRegistrationFailed = Notification.Name("PasskeyRegistrationFailedNotification")
    static let PasskeyRegistrationCanceled = Notification.Name("PasskeyRegistrationCanceledNotification")
    static let InitEmailAuth = Notification.Name("InitEmailAuthNotification")
}

class AccountManager: NSObject, ASAuthorizationControllerPresentationContextProviding, ASAuthorizationControllerDelegate {
    let domain = "turnkey-nextjs-demo-weld.vercel.app"
    var authenticationAnchor: ASPresentationAnchor?
    var isPerformingModalRequest = false
    private var passkeyRegistration: PasskeyManager?
    private var keyManager = KeyManager()
    
    override init() {
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
        let proxyURL = URL(string: "http://localhost:3000/api/email-auth")
        let turnkeyClient = TurnkeyClient(rpId: domain, presentationAnchor: anchor, proxyURL: proxyURL)
        
        let organizationId = "acd0bc97-2af5-475b-bc34-0fa7ca3bdc75"
        
        do {
            // Call the GetWhoami method on the TurnkeyClient instance
            let output = try await turnkeyClient.getWhoami(organizationId: "acd0bc97-2af5-475b-bc34-0fa7ca3bdc75")
            
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
        let proxyURL = URL(string: "http://localhost:3000/api/email-auth")
        // We create a proxied instance of the Turnkey Client that can proxy requests to the backend
        let turnkeyClient = TurnkeyClient(rpId: domain, presentationAnchor: anchor, proxyURL: proxyURL)
        let organizationId = "70189536-9086-4810-a9f0-990d4e7cd622"

        do {
            let publicKey = try keyManager.createKeyPair()
//            guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey as! SecKey, nil) as Data? else {
//                throw NSError(domain: "KeyConversionError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Unable to extract the public key data"])
//            }

            var targetPublicKey = Data([0x04])
            let rawRepresentation = publicKey.rawRepresentation
            targetPublicKey.append(rawRepresentation)
            
            print("targetPublicKey", targetPublicKey.map{ String(format: "%02x", $0) }.joined())

            let output = try await turnkeyClient.emailAuth(
                organizationId: organizationId,
                email: email,
                targetPublicKey: targetPublicKey.map{ String(format: "%02x", $0) }.joined(),
                apiKeyName: "test-api-key-swift-sdk",
                expirationSeconds: "3600",
                emailCustomization: nil,
                useProxy: true
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
    
    func verifyEncryptedBundle(bundle: String) {
        do {
            let decryptedString = try keyManager.decryptBundle(bundle)
            print("decryptedString", decryptedString)
        } catch {
            print("Error occurred: \(error)")
        }
    }

    func beginAutoFillAssistedPasskeySignIn(anchor: ASPresentationAnchor) {
        self.authenticationAnchor = anchor

        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)

        // Fetch the challenge from the server. The challenge needs to be unique for each request.
        let challenge = Data()
        let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)

        // AutoFill-assisted requests only support ASAuthorizationPlatformPublicKeyCredentialAssertionRequest.
        let authController = ASAuthorizationController(authorizationRequests: [ assertionRequest ] )
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
    
    
    @objc private func handlePasskeyRegistrationCompleted(_ notification: Notification) {
        guard let result = notification.userInfo?["result"] as? PasskeyRegistrationResult else {
            return
        }
        
        // Handle passkey registration completion
        // ...
        
        didFinishSignIn()
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
    
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
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

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
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

