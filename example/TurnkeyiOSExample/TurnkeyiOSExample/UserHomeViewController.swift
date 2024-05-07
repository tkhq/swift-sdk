//
//  UserHomeViewController.swift
//  TurnkeyiOSExample
//
//  Created by Taylor Dawson on 4/15/24.
//


import UIKit
import Web3Core
import web3swift
import SwiftData

class UserHomeViewController: UIViewController {
    private var modelContext: ModelContext {
        return AppDelegate.userModelContext
    }

    @IBOutlet var balanceLabel: UILabel!
    @IBOutlet var walletAddress: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        let user = SessionManager.shared.currentUser
        let walletAddress = user?.walletAddress ?? ""
        self.walletAddress.text = walletAddress
        fetchAndDisplayBalance(walletAddress)
    }

    func fetchAndDisplayBalance(_ walletAddress: String) {
        Task {
            do {
                guard let url = URL(string: "https://sepolia.infura.io/v3/aff750133b264927afc97184a9ead71b") else {
                    print("Invalid URL")
                    return
                }

                let web3 = try await Web3.new(url, network: Networks.Custom(networkID: 11155111))
                let address = EthereumAddress(walletAddress)!
                let balance = try await web3.eth.getBalance(for: address)
                let balString = Utilities.formatToPrecision(balance, units: .ether, formattingDecimals: 3)
                print(balString)
                DispatchQueue.main.async {
                    self.balanceLabel.text = balString
                }

            } catch {
                print("Failed to fetch balance: \(error)")
            }
        }
    }

    @IBAction func signOut(_ sender: Any) {
        SessionManager.shared.clearUser()

        view.window?.rootViewController = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "SignInViewController")
    }
}

func truncateAddress(_ address: String, prefixLength: Int, suffixLength: Int) -> String {
    guard address.count > prefixLength + suffixLength else { return address }
    let prefix = address.prefix(prefixLength)
    let suffix = address.suffix(suffixLength)
    return "\(prefix)...\(suffix)"
}
