# Swift Demo Wallet

A minimal iOS/macOS application demonstrating how to build an embedded wallet experience using Turnkey infrastructure and Auth Proxy.

## What this demo shows

A high-level summary of the user experience and what you can see on screen:

- **Authentication**: Log in with passkeys, OTP (email/SMS), or OAuth (Google, Apple, Discord, X)
- **Session Management**: Automatic session handling with secure key storage in Secure Enclave
- **Wallet Operations**: Create, import, and export wallets with mnemonic phrases
- **Message Signing**: Sign messages and raw payloads with wallet accounts
- **User Management**: Update email/phone and view wallet details

## Getting started

### 1/ Cloning the example

Make sure you have Xcode 15+ installed.

```bash
git clone https://github.com/tkhq/swift-sdk
cd swift-sdk/Examples/swift-demo-wallet
```

### 2/ Setting up Turnkey

1. Set up your Turnkey organization and account. You'll need your **parent organization ID**.
2. Enable **Auth Proxy** from your Turnkey dashboard:
   - Choose the user auth methods (Email OTP, SMS OTP, OAuth providers)
   - Configure redirect URLs for OAuth (if using)
   - Copy your **Auth Proxy Config ID** for the next step
3. (Optional) For passkey authentication, set up your **RP ID** domain with associated domains

### 3/ Configure Constants

Edit `swift-demo-wallet/Helpers/Constants.swift` and add your values:

```swift
enum Constants {
    enum App {
        static let appName = "Swift Demo Wallet App"
        static let rpId = "<your_rp_id>"  // required for passkeys
    }

    enum Turnkey {
        static let organizationId = "<your_organization_id>"
        static let apiUrl = "https://api.turnkey.com"
        
        // Auth Proxy Configuration
        static let authProxyUrl = "https://auth.turnkey.com"
        static let authProxyConfigId = "<your_auth_proxy_config_id>"

        // Default accounts to create when using the "Create Wallet" button
        // Customize this array to create wallets with different curves, paths, or address formats
        static let defaultEthereumAccounts: [Components.Schemas.WalletAccountParams] = [
            Components.Schemas.WalletAccountParams(
                curve: .CURVE_SECP256K1,
                pathFormat: .PATH_FORMAT_BIP32,
                path: "m/44'/60'/0'/0/0",
                addressFormat: .ADDRESS_FORMAT_ETHEREUM
            )
        ]
    }

    enum Ethereum {
        static let rpcURL = "https://rpc.sepolia.org"
        static let coingeckoURL = "https://api.coingecko.com"
    }
}
```

### 4/ Running the demo

Open `swift-demo-wallet.xcodeproj` in Xcode and run the app on your device or simulator.

---

## Requirements

- iOS 17+ / macOS 14.0+
- Swift 5.9+
- Xcode 15+

---
