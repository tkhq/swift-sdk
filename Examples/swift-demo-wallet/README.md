# Swift Demo Wallet&#x20;

The Swift Demo Wallet is a sample iOS/macOS application that demonstrates how to build a simple wallet experience using Turnkey infrastructure. It showcases session handling, wallet creation/import, and transaction signing in a native SwiftUI application.

---

## Quick Start

### 1. Clone the Repository

```
git clone https://github.com/tkhq/swift-sdk
cd Examples/swift-demo-wallet
```

### 2. Open the Project

Open the `Examples/swift-demo-wallet` folder and build the project in Xcode.

### 3. Configure Constants

Edit `Helpers/Constants.swift` and fill in the required values:

```swift
enum Constants {
    enum App {
        static let appName = "Swift Demo Wallet App"
        static let rpId = "<your_rp_id>"                     // e.g. passkeyapp.tkhqlabs.xyz
        static let backendBaseUrl = "<your_backend_url>"     // e.g. http://localhost:3000
    }

    enum Turnkey {
        static let organizationId = "<your_organization_id>"
        static let sessionDuration = "900"                   // session duration in seconds
        static let apiUrl = "https://api.turnkey.com"

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

---

## Backend Setup

### Why Do We Need a Backend?

Turnkey requires authentication requests (sign-up/login) to be validated (stamped) using your root user API key-pair. Since this key-pair must remain private, it cannot be used directly in the frontend. Instead, authentication requests must be processed and stamped through a backend server before being forwarded to Turnkey.

### 1. Configure Environment Variables

Create a `.env` file inside the `example-server` folder:

```
PORT="3000"

TURNKEY_API_URL="https://api.turnkey.com"
TURNKEY_ORGANIZATION_ID="<your_turnkey_organization_id>"

TURNKEY_API_PUBLIC_KEY="<your_turnkey_api_public_key>"
TURNKEY_API_PRIVATE_KEY="<your_turnkey_api_private_key>"
```

### 2. Start the Server

```
cd example-server
npm install
npm run start
```

---

## Passkey Setup

To enable passkey authentication, you must configure your domain and app settings correctly:

### Associated Domains

1. In your app's `Signing & Capabilities` tab, add the `Associated Domains` capability.
2. Add your domain:

```
webcredentials:<your_rpid_domain>
```

3. Host an `apple-app-site-association` file at `https://<your_rpid_domain>/.well-known/apple-app-site-association`

4. Ensure your `rpId` in Constants.swift matches the domain:

```swift
static let rpId = "<your_rpid_domain>"
```

---

## Requirements

- iOS 17+ / macOS 13.0+
- Swift 5.7+
- Xcode 15+

---
