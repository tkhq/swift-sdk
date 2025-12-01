//
//  SendTransactionViewController.swift
//  TurnkeyiOSExample
//
//  Created by Taylor Dawson on 5/3/24.
//

import Foundation
import SwiftData
import UIKit
//import Web3Core
//import web3swift

class SendTransactionViewController: UIViewController {
    // Domain constant no longer needed here; use authenticated client from AccountManager
    // let domain = "turnkey-nextjs-demo-weld.vercel.app"
    
    @IBOutlet var value: UILabel!
    @IBOutlet var to: UITextField!
    @IBOutlet var sendButton: UIButton!
    private var modelContext: ModelContext {
        return AppDelegate.userModelContext
    }
    private var user: User?

    override func viewDidLoad() {
        guard let user = SessionManager.shared.currentUser else {
            return
        }
     
        self.user = user
        super.viewDidLoad()
    }

    @IBAction func numberButtonPressed(_ sender: UIButton) {
        print("numberButtonPressed\(sender)")
        // Optional chaining in case the button title is nil
//        guard let numberValue = sender.title else { return }
        print("numberButtonPressed no value")
        // Append the value to the current text in the text field
//        guard let currentValue = value.text else  {
//            return
//        }
//        value.text = currentValue.text + sender.title
    }

    @IBAction func send(_ sender: UIButton) {
        // Using Task to handle the asynchronous signIn method
        Task {
            do {
                try await sendTransaction()
            } catch {
                // Handle errors that might be thrown by the signIn method
                DispatchQueue.main.async {
                    // Ensure UI updates are on the main thread
                    print("Failed to sign in: \(error)")
                }
            }
        }
    }

    func sendTransaction() async throws {
        
        guard let walletAddress = SessionManager.shared.currentUser?.walletAddress else {
            print("no user with wallet address")
            return
        }
        guard let url = URL(string: "https://sepolia.infura.io/v3/aff750133b264927afc97184a9ead71b") else {
            print("Invalid URL")
            return
        }
        
//        let web3 = try await Web3.new(url, network: Networks.Custom(networkID: 11155111))
//        let address = EthereumAddress(walletAddress)!
//        var transaction: CodableTransaction = .emptyTransaction
//        transaction.from = address ?? transaction.sender // `sender` one is if you have private key of your wallet address, so public key e.g. your wallet address could be interpreted
//        transaction.value = 0
//        transaction.gasLimitPolicy =  .manual(78423)
//        transaction.gasPricePolicy = .manual(20000000000)
//        var transaction = CodableTransaction(
//            to: address,
//            nonce: 9, value: 1000000000000000000, data: Data(),
//            gasLimit: 21000, gasPrice: 20000000000,
//            // FIXME: Return parameters here
//            v: 0, r: 0, s: 0)
//        
//        try await web3.eth.send(transaction)
    }
}
