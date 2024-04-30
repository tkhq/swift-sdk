//
//  EmailAuthViewController.swift
//  TurnkeyiOSExample
//
//  Created by Taylor Dawson on 4/26/24.
//

import UIKit

class EmailAuthViewController: UIViewController {
    @IBOutlet weak var encryptedBundleField: UITextField!
    @IBOutlet weak var verifyButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func verify(_ sender: UIButton) {
        let encryptedBundle = encryptedBundleField.text ?? ""
        // Process the input text here
        print("Verifying: \(encryptedBundle)")
        (UIApplication.shared.delegate as? AppDelegate)?.accountManager.verifyEncryptedBundle(bundle: encryptedBundle)
        
        // Using Task to handle the asynchronous signIn method
//        Task {
//            do {
//                try  (UIApplication.shared.delegate as? AppDelegate)?.accountManager.verifyEncryptedBundle(bundle: encryptedBundle)
//            } catch {
//                // Handle errors that might be thrown by the signIn method
//                DispatchQueue.main.async {
//                    // Ensure UI updates are on the main thread
//                    print("Failed to sign in: \(error)")
//                }
//            }
//        }
    }
}
