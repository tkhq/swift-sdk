import Foundation
import TurnkeyHttp
import TurnkeyTypes

enum Constants {
    enum App {
        static let appName = "Swift Demo Wallet App"
        static let rpId = "<your_rp_id>"
        static let scheme = "swift-demo-wallet"
        static let backendBaseUrl = "http://localhost:3000"
    }

    enum Turnkey {
        static let organizationId = "<your_organization_id>"
        static let sessionDuration = "900"

        static let apiUrl = "https://api.turnkey.com"

        static let defaultEthereumAccounts: [v1WalletAccountParams] = [
            v1WalletAccountParams(
                addressFormat: v1AddressFormat.address_format_ethereum,
                curve: v1Curve.curve_secp256k1,
                path: "m/44'/60'/0'/0/0",
                pathFormat: v1PathFormat.path_format_bip32
            ),
        ]
    }

    enum Ethereum {
        static let rpcURL = "https://rpc.sepolia.org"
        static let coingeckoURL = "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd"
    }

    enum Google {
        static let clientId = "<your_google_client_id>"
    }
}
