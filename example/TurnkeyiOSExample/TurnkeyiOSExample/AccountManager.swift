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
import SwiftData
import TurnkeySDK

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
    ASAuthorizationControllerDelegate {
    let domain = "turnkey-nextjs-demo-weld.vercel.app"
    let parentOrgId = "70189536-9086-4810-a9f0-990d4e7cd622"
    var authenticationAnchor: ASPresentationAnchor?
    var isPerformingModalRequest = false
    private var passkeyRegistration: PasskeyManager?
    private var currentEmail: String?
    private var modelContext: ModelContext {
        return AppDelegate.userModelContext
    }

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
        let turnkeyClient = TurnkeyClient(rpId: domain, presentationAnchor: anchor)
        guard let user = getUser(email: email) else {
        
            return
        }

        guard let organizationId = user.subOrgId else {
            print("no suborg id found on device")
            return
        }

        do {
            // Call the GetWhoami method on the TurnkeyClient instance
            let output = try await turnkeyClient.getWhoami(organizationId: organizationId)

            // Assert the response
            switch output {
            case let .ok(response):
                switch response.body {
                case let .json(whoamiResponse):
                    print(whoamiResponse)
                }
            case let .undocumented(statusCode, undocumentedPayload):
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

    /// A closure that verifies an encrypted bundle.
    /// This closure is set when the `emailAuth` method is called and is used to verify
    /// the encrypted bundle received during the email authentication process.
    /// It takes a `String` representing the encrypted bundle and returns an `AuthResult` asynchronously.
    private var verifyClosure: ((String) async throws -> AuthResult)?

    func signInEmailAuth(email: String, anchor: ASPresentationAnchor) async {
        // For email auth we need to proxy the request to a backend that can stamp it
        let proxyURL = "http://localhost:3000/api/email-auth"
        // We create a proxied instance of the Turnkey Client that can proxy requests to the backend
        let turnkeyClient = TurnkeyClient(proxyURL: proxyURL)

        do {

        let (output, verify) = try await turnkeyClient.emailAuth(
                organizationId: parentOrgId,
                email: email,
                apiKeyName: "test-api-key-swift-sdk",
                expirationSeconds: "3600",
                emailCustomization: Components.Schemas.EmailCustomizationParams()
            )

            // Store the verify closure for later use
            self.verifyClosure = verify

            // Assert the response
            switch output {
            case let .ok(response):
                switch response.body {
                case let .json(emailAuthResponse):
                    print(emailAuthResponse.activity.organizationId)
                    DispatchQueue.main.async {
                        self.initEmailAuth()
                    }
                }
            case let .undocumented(statusCode, undocumentedPayload):
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
            case let .ok(response):
                switch response.body {
                case let .json(emailAuthResponse):
                    print(emailAuthResponse)
                }
            case let .undocumented(statusCode, undocumentedPayload):
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
        authenticationAnchor = anchor

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
        authenticationAnchor = anchor
        SessionManager.shared.setCurrentUser(user: User(email: email))

        passkeyRegistration = PasskeyManager(rpId: domain, presentationAnchor: anchor)
        passkeyRegistration?.registerPasskey(email: email)
        print("\(email) signup")
        isPerformingModalRequest = true
    }

    func sendCreateSubOrgRequest(passkeyRegistrationResult: PasskeyRegistrationResult, email: String) async throws -> Components.Schemas.CreateSubOrganizationResultV4? {
//        guard let email else {
//            throw NSError(domain: "AccountManagerError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Email not set"])
//        }

        // For email auth we need to proxy the request to a backend that can stamp it
        let proxyURL = "http://localhost:3000/api/sign-up"

        // Create an instance of TurnkeyClient
        let client = TurnkeyClient(proxyURL: proxyURL)

        let attestation: Components.Schemas.Attestation = .init(credentialId: passkeyRegistrationResult.attestation.credentialId, clientDataJson: passkeyRegistrationResult.attestation.clientDataJson, attestationObject: passkeyRegistrationResult.attestation.attestationObject, transports: [.AUTHENTICATOR_TRANSPORT_BLE])

        // Define the test input
        let subOrganizationName = "Test Sub Organization"
        let rootUsers: [Components.Schemas.RootUserParams] = [
            .init(
                userName: "user1",
                userEmail: email,
                apiKeys: [],
                authenticators: [
                    .init(authenticatorName: "Tuide - Simulator", challenge: passkeyRegistrationResult.challenge, attestation: attestation),
                ]
            ),
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
                ),
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
        case let .ok(response):
            switch response.body {
            case let .json(activityResponse):
                let result = activityResponse.activity.result.createSubOrganizationResultV4
                return result
                // Print the activity as JSON
                //           let encoder = JSONEncoder()
                //           encoder.outputFormatting = .prettyPrinted
                //           let jsonData = try encoder.encode(activityResponse.activity.result)
                //           if let jsonString = String(data: jsonData, encoding: .utf8) {
                //             print(jsonString)
                //           }
            }
        case let .undocumented(statusCode, undocumentedPayload):
            // Handle the undocumented response
            if let body = undocumentedPayload.body {
                // Convert the HTTPBody to a string
                let bodyString = try await String(collecting: body, upTo: .max)
                print("Undocumented response body: \(bodyString)")
            }
            print("Undocumented response: \(statusCode)")
        }
        return nil
    }

    @objc private func handlePasskeyRegistrationCompleted(_ notification: Notification) {
        guard let result = notification.userInfo?["result"] as? PasskeyRegistrationResult else {
            return
        }

        Task {
            let user = SessionManager.shared.getCurrentUser()
            guard let email = user?.email else {
                print("no email")
                return
            }
            let result = try await sendCreateSubOrgRequest(passkeyRegistrationResult: result, email: email)
            
            user?.walletAddress = result?.wallet?.addresses[0]
            user?.subOrgId = result?.subOrganizationId
            if(user != nil) {
                modelContext.insert(user!)
                try modelContext.save()
            }
            
            DispatchQueue.main.async {
                self.didFinishSignIn()
            }
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
    
    func getUser(email: String) -> User? {
        let fetchDescriptor = FetchDescriptor<User>(predicate: nil) // No predicate means fetch all users
        do {
            let users = try modelContext.fetch(fetchDescriptor)
            // Now 'users' contains all user instances
            for user in users {
                print(user) // or handle each user as needed
            }
            print("No USERS ATALL")
        } catch {
            print("Failed to fetch users: \(error)")
        }
        
        let userPredicate = #Predicate<User> {
            $0.email == email
        }

        // Assuming you have a way to identify the specific User, e.g., by a stored userID or currentEmail
        let request = FetchDescriptor<User>(predicate: userPredicate)
        
        do {
            let users = try modelContext.fetch(request)
            guard let user = users.first else {
                print("no user found for email \(email)")
                return nil
            }
            return user
        } catch {
            print("error getting user \(error)")
            return nil
        }
    }

    func updateUser(email: String, walletAddress: String?, subOrgId: String?, userName: String?) {
        let context = modelContext

        let userPredicate = #Predicate<User> {
            $0.email == email
        }

        // Assuming you have a way to identify the specific User, e.g., by a stored userID or currentEmail
        let request = FetchDescriptor<User>(predicate: userPredicate)
        do {
            let users = try context.fetch(request)
            if let user = users.first {
                user.email = email
                
                try context.save()
                SessionManager.shared.setCurrentUser(user: user)
                print("Email updated successfully")
            } else {
                // Handle case where user is not found, possibly create a new user
                let newUser = User(email: email, userName: userName,  subOrgId: subOrgId, walletAddress: walletAddress)
                context.insert(newUser)
                try context.save()
                print("New user created with email")
            }
        } catch {
            print("Failed to update or create user: \(error)")
        }
    }
}
