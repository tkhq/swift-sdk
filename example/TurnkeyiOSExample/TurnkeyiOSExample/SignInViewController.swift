//
//  SignInViewController.swift
//  TurnkeyiOSExample
//
//  Created by Taylor Dawson on 4/15/24.
//

import AuthenticationServices
import UIKit
import os

class SignInViewController: UIViewController {
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var emailField: UITextField!

    private var signInObserver: NSObjectProtocol?
    private var signInErrorObserver: NSObjectProtocol?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        signInObserver = NotificationCenter.default.addObserver(forName: .UserSignedIn, object: nil, queue: nil) {_ in
            self.didFinishSignIn()
        }

//        signInErrorObserver = NotificationCenter.default.addObserver(forName: .ModalSignInSheetCanceled, object: nil, queue: nil) { _ in
//            self.showSignInForm()
//        }

//        guard let window = self.view.window else { fatalError("The view was not in the app's view hierarchy!") }
//        (UIApplication.shared.delegate as? AppDelegate)?.accountManager.signIn(anchor: window, preferImmediatelyAvailableCredentials: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        if let signInObserver = signInObserver {
            NotificationCenter.default.removeObserver(signInObserver)
        }

        if let signInErrorObserver = signInErrorObserver {
            NotificationCenter.default.removeObserver(signInErrorObserver)
        }
        
        super.viewDidDisappear(animated)
    }

    @IBAction func createAccount(_ sender: Any) {
        guard let email = emailField.text else {
            Logger().log("No email provided")
            return
        }
        Logger().log("createAccount: email provided: \(email)")
        guard let window = self.view.window else { fatalError("The view was not in the app's view hierarchy!") }
        (UIApplication.shared.delegate as? AppDelegate)?.accountManager.signUp(email: email, anchor: window)
    }
    
    @IBAction func signIn(_ sender: Any) {
        guard let email = emailField.text else {
            Logger().log("No email provided")
            return
        }
        Logger().log("signIn: email provided: \(email)")
        guard let window = self.view.window else { fatalError("The view was not in the app's view hierarchy!") }
        
        // Using Task to handle the asynchronous signIn method
        Task {
            do {
                try await (UIApplication.shared.delegate as? AppDelegate)?.accountManager.signIn(email: email, anchor: window)
            } catch {
                // Handle errors that might be thrown by the signIn method
                DispatchQueue.main.async {
                    // Ensure UI updates are on the main thread
                    Logger().log("Failed to sign in: \(error)")
                }
            }
        }
    }

//    func showSignInForm() {
//        emailLabel.isHidden = false
//        emailField.isHidden = false
//
//        guard let window = self.view.window else { fatalError("The view was not in the app's view hierarchy!") }
//        (UIApplication.shared.delegate as? AppDelegate)?.accountManager.signIn(anchor: window, preferImmediatelyAvailableCredentials: <#T##Bool#>)
////        (UIApplication.shared.delegate as? AppDelegate)?.accountManager.beginAutoFillAssistedPasskeySignIn(anchor: window)
//    }

    func didFinishSignIn() {
        self.view.window?.rootViewController = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "UserHomeViewController")
    }

    @IBAction func tappedBackground(_ sender: Any) {
        self.view.endEditing(true)
    }
}


