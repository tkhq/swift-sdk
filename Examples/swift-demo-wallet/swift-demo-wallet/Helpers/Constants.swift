import Foundation
import TurnkeyHttp

enum Constants {

  enum App {
    static let appName = "Swift Demo Wallet App"
    static let rpId = "passkeyapp.tkhqlabs.xyz"
    static let scheme = "swift-demo-wallet"
    static let backendBaseUrl = "http://localhost:3000"
  }

  enum Turnkey {
    static let organizationId = "7533b2e3-01f2-4573-98c3-2c8bee816cb6"
    static let sessionDuration = "900"
    static let apiUrl = "http://localhost:8081"
    static let authProxyUrl = "http://localhost:8090"
    static let authProxyConfigId = "5889b4b6-ec95-42ca-8551-660e9d50ed09"
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

  enum Google {
    static let clientId = "<your_google_web_client_id>"
  }
}
