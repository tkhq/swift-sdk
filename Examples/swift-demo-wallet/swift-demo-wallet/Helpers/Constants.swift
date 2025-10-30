import Foundation
import TurnkeyHttp
import TurnkeyTypes

enum Constants {

  enum App {
    static let appName = "Swift Demo Wallet App"
    static let rpId = "passkeyapp.tkhqlabs.xyz"
    static let scheme = "swift-demo-wallet"
    static let backendBaseUrl = "http://localhost:3000"
  }

  enum Turnkey {
    static let organizationId = "cd473579-efee-4cb1-8a23-734bd1b4be31" // "7533b2e3-01f2-4573-98c3-2c8bee816cb6"
    static let sessionDuration = "900"
    static let apiUrl = "https://api.turnkey.com" // "http://localhost:8081"
    static let authProxyUrl = "https://authproxy.turnkey.com" // http://localhost:8090"
    static let authProxyConfigId = "544e423d-f5c9-4dfb-947e-8cf726e3922e" // 5889b4b6-ec95-42ca-8551-660e9d50ed09"
    static let defaultEthereumAccounts: [v1WalletAccountParams] = [
      v1WalletAccountParams(
        addressFormat: v1AddressFormat.address_format_ethereum,
        curve: v1Curve.curve_secp256k1,
        path: "m/44'/60'/0'/0/0",
        pathFormat: v1PathFormat.path_format_bip32,
      )
    ]
  }

  enum Ethereum {
    static let rpcURL = "https://rpc.sepolia.org"
    static let coingeckoURL = "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd"
  }

  enum Google {
    static let clientId = "776352896366-07enngvt22l7cnq1ctf5a9ddcm1pv1sc.apps.googleusercontent.com"
  }

  enum Apple {
    static let clientId = "withreactnativewalletkit" // Fill with your Apple Services ID (client ID)
  }

  enum X {
    static let clientId = "d1dFWkNfVk1kdG12SlUxZ3k3NG86MTpjaQ"
  }

  enum Discord {
    static let clientId = "1422294103890067536"
  }
}
