//
//  AccountManager.swift
//  TurnkeyiOSExample
//
//  Created by Taylor Dawson on 4/19/24.
//

import AuthenticationServices
import Foundation
import os
import SwiftData
import TurnkeySwift

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
    var authenticationAnchor: ASPresentationAnchor?
    var isPerformingModalRequest = false
    private var currentEmail: String?
    private var registrationEmail: String?
    private var registrationChallenge: Data?
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

    func signIn(email: String, anchor: ASPresentationAnchor) async {
        do {
            print("Calling login")
            // Perform passkey-based login using TurnkeyContext (stores session on success)
            try await TurnkeyContext.shared.loginWithPasskey(anchor: anchor)
            print("After calling login")

            // Notify listeners that sign-in completed
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .UserSignedIn, object: nil)
            }
        } catch {
            print("Passkey login failed: \(error)")
        }

        isPerformingModalRequest = true
    }

    func verifyEncryptedBundle(bundle: String) async {
        // Email auth via proxy has been removed in favor of backend-driven flows.
        print("verifyEncryptedBundle is no longer supported; use your backend to verify and return a session token, then store it via TurnkeyContext.shared.storeSession(jwt:).")
    }

    func beginAutoFillAssistedPasskeySignIn(anchor: ASPresentationAnchor) {
        authenticationAnchor = anchor

        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: Constants.domain)

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

    private struct AttestationPayload: Codable {
        let credentialId: String
        let clientDataJson: String
        let attestationObject: String
        let transports: [String]?
    }
    private struct PasskeyPayload: Codable {
        let challenge: String
        let attestation: AttestationPayload
    }
    private struct CreateSubOrgRequestBody: Codable {
        let email: String?
        let phone: String?
        let passkey: PasskeyPayload?
    }
    private struct CreateSubOrgResponse: Codable { let subOrganizationId: String }

    private func base64URLEncode(_ data: Data) -> String {
        var encoded = data.base64EncodedString()
        encoded = encoded.replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return encoded
    }

    private func base64URLDecode(_ string: String) -> Data? {
        var s = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = (4 - s.count % 4) % 4
        s += String(repeating: "=", count: padding)
        return Data(base64Encoded: s)
    }

    private func startPasskeyRegistration(email: String, anchor: ASPresentationAnchor) async {
        do {
            self.registrationEmail = email
            self.authenticationAnchor = anchor
            // 1) Generate a registration challenge on-device (base64url)
            let randomBytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
            let challengeData = Data(randomBytes)
            self.registrationChallenge = challengeData

            // 2) Create passkey registration request
            let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: Constants.domain)
            let userId = UUID().uuidString.data(using: .utf8) ?? Data()
            let request = provider.createCredentialRegistrationRequest(
                challenge: challengeData,
                name: email,
                userID: userId
            )
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        } catch {
            print("Failed to start passkey registration: \(error)")
            self.isPerformingModalRequest = false
        }
    }

    func signUp(email: String, anchor: ASPresentationAnchor) {
        authenticationAnchor = anchor
        SessionManager.shared.setCurrentUser(user: User(email: email))
        print("\(email) signup")
        isPerformingModalRequest = true
        Task {
            await startPasskeyRegistration(email: email, anchor: anchor)
        }
    }

    @objc private func handlePasskeyRegistrationCompleted(_ notification: Notification) {
        Task {
            print("Passkey registration completed notification received.")

            DispatchQueue.main.async {
                self.didFinishSignIn()
            }
        }
    }

    @objc private func handlePasskeyRegistrationFailed(_ notification: Notification) {
        let error = notification.userInfo?["error"] ?? "Unknown error"
        print("Passkey registration failed: \(error)")

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
            // Send attestation to backend /signup
            Task {
                do {
                    guard let email = self.registrationEmail,
                          let challenge = self.registrationChallenge else {
                        throw NSError(domain: "Signup", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing registration context"])
                    }
                    let attestation = AttestationPayload(
                        credentialId: base64URLEncode(credentialRegistration.credentialID),
                        clientDataJson: base64URLEncode(credentialRegistration.rawClientDataJSON),
                        attestationObject: base64URLEncode(credentialRegistration.rawAttestationObject ?? Data()),
                        transports: nil
                    )
                    let body = CreateSubOrgRequestBody(
                        email: email,
                        phone: nil,
                        passkey: PasskeyPayload(
                            challenge: base64URLEncode(challenge),
                            attestation: attestation
                        )
                    )
                    guard let url = URL(string: "\(Constants.backendAuthUrl)/auth/createSubOrg") else {
                        throw NSError(domain: "Signup", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid createSubOrg URL"])
                    }
                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.httpBody = try JSONEncoder().encode(body)
                    let (data, resp) = try await URLSession.shared.data(for: req)
                    if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                        let bodyText = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
                        throw NSError(domain: "Signup", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "createSubOrg failed (\(http.statusCode)): \(bodyText)"])
                    }
                    // Try decoding expected response; if it fails, surface raw body to aid debugging
                    do {
                        _ = try JSONDecoder().decode(CreateSubOrgResponse.self, from: data)
                    } catch {
                        let bodyText = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
                        throw NSError(domain: "Signup", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unexpected createSubOrg response: \(bodyText)"])
                    }
                    // Server does not return a session; log in with passkey now
                    if let anchor = self.authenticationAnchor {
                        try await TurnkeyContext.shared.loginWithPasskey(anchor: anchor)
                    }
                    DispatchQueue.main.async {
                        self.didFinishSignIn()
                    }
                } catch {
                    print("Signup (attestation upload) failed: \(error)")
                    self.isPerformingModalRequest = false
                }
            }
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
