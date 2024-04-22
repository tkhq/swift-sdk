//
//  UserHomeViewController.swift
//  TurnkeyiOSExample
//
//  Created by Taylor Dawson on 4/15/24.
//

import UIKit

class UserHomeViewController: UIViewController {
    @IBAction func signOut(_ sender: Any) {
        self.view.window?.rootViewController = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "SignInViewController")
    }
}
