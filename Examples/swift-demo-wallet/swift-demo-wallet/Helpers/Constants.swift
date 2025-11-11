import Foundation
import TurnkeyHttp
import TurnkeyTypes

enum Constants {

  enum App {
    static let rpId = "passkeyapp.tkhqlabs.xyz"
    static let scheme = "swift-demo-wallet"
  }

  enum Turnkey {
    static let organizationId = "cd473579-efee-4cb1-8a23-734bd1b4be31"
    static let apiUrl = "https://api.turnkey.com" 

    static let authProxyUrl = "https://authproxy.turnkey.com"
    static let authProxyConfigId = "544e423d-f5c9-4dfb-947e-8cf726e3922e"
    
    static let defaultEthereumAccounts: [v1WalletAccountParams] = [
      v1WalletAccountParams(
        addressFormat: v1AddressFormat.address_format_ethereum,
        curve: v1Curve.curve_secp256k1,
        path: "m/44'/60'/0'/0/0",
        pathFormat: v1PathFormat.path_format_bip32
      )
    ]
  }

  enum Ethereum {
    static let rpcURL = "https://rpc.sepolia.org"
    static let coingeckoURL = "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd"
  }

  enum Google {
    static let clientId = "<your_google_client_id>"
  }

  enum Apple {
    static let clientId = "<your_apple_client_id>"
  }

  enum X {
    static let clientId = "<your_x_client_id>"
  }

  enum Discord {
    static let clientId = "<your_discord_client_id>"
  }
}
