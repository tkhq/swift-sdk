import Foundation
import TurnkeyHttp

enum Constants {
    
    enum App {
        static let appName = "Passkey App"
        static let rpId = "passkeyapp.tkhqlabs.xyz"
        static let backendBaseUrl = "http://localhost:3000"
    }

    enum Turnkey {
        static let organizationId = "957f6bbe-2f29-4057-8fc6-c8db0070f608"
        static let sessionDuration = "120"
        static let apiUrl = "http://localhost:8081"
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
