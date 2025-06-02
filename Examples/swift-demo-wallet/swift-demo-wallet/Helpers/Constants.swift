import Foundation
import TurnkeyHttp

enum Constants {
    
    enum App {
        static let appName = "Swift Demo Wallet App"
        static let rpId = "<your_rp_id>"
        static let backendBaseUrl = "http://localhost:3000"
    }

    enum Turnkey {
        static let organizationId = "<your_organization_id>"
        static let sessionDuration = "900"
        static let apiUrl = "https://api.turnkey.com"
        static let defaultEthereumAccounts: [Components.Schemas.WalletAccountParams] = [
            Components.Schemas.WalletAccountParams(
                curve: Components.Schemas.Curve.CURVE_SECP256K1,
                pathFormat: Components.Schemas.PathFormat.PATH_FORMAT_BIP32,
                path: "m/44'/60'/0'/0/0",
                addressFormat: Components.Schemas.AddressFormat.ADDRESS_FORMAT_ETHEREUM
            )
        ]
    }
    
    enum Ethereum {
        static let rpcURL = "https://rpc.sepolia.org"
        static let coingeckoURL = "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd"
    }
}
