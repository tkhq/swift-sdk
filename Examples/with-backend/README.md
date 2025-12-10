# Swift Demo Wallet (with Backend)

A minimal iOS/macOS application demonstrating how to build an embedded wallet experience using Turnkey infrastructure with a backend server.

## What this demo shows

A high-level summary of the user experience and what you can see on screen:

- **Authentication**: Log in/sign up with passkeys, OTP (email/SMS), or OAuth (Google)
- **Session Management**: Automatic session handling with secure key storage in Secure Enclave
- **Wallet Operations**: Create, import, and export wallets with mnemonic phrases
- **Message Signing**: Sign messages and raw payloads with wallet accounts
- **User Management**: Update email/phone and view wallet details

## Architecture

This example uses a backend server to handle authentication and session creation with Turnkey:
- **Swift App**: Handles UI, session management, and uses Turnkey sessions for signing and wallet operations
- **Node.js Backend**: An example server that manages authentication flows (OTP, OAuth, passkey sub-organization creation) and creates Turnkey sessions

## Getting started

### 1/ Cloning the example

Make sure you have Xcode 15+ and Node.js 18+ installed.

```bash
git clone https://github.com/tkhq/swift-sdk
cd swift-sdk/Examples/with-backend
```

### 2/ Setting up Turnkey

1. Create a Turnkey organization at [dashboard.turnkey.com](https://dashboard.turnkey.com)
2. Create an API key pair for your backend server
3. Note your **organization ID**, **API public key**, and **API private key**

### 3/ Configure and run the backend server

Navigate to the backend directory:

```bash
cd example-server
```

Copy the example environment file and edit it with your Turnkey credentials:

```bash
cp .env.example .env
```

Edit `.env` and add your Turnkey credentials from step 2:

```bash
PORT="3000"

TURNKEY_API_URL="https://api.turnkey.com"
TURNKEY_ORGANIZATION_ID="<your_organization_id>"

TURNKEY_API_PUBLIC_KEY="<your_api_public_key>"  
TURNKEY_API_PRIVATE_KEY="<your_api_private_key>"
```

Install dependencies:

```bash
npm install
```

Start the server:

```bash
npm run start
```

You should see:
```
✅ Server running on http://localhost:3000
```

### 4/ Configure the Swift app

Edit `swift-demo-wallet/Helpers/Constants.swift` and update the values:

```swift
enum Constants {
    enum App {
        static let appName = "Swift Demo Wallet App"
        static let rpId = "<your_rp_id>"  // required for passkeys (e.g., "passkeyapp.example.com")
        static let scheme = "swift-demo-wallet"  // URL scheme for OAuth redirects
        static let backendBaseUrl = "http://localhost:3000"  // Your backend server URL
    }

    enum Turnkey {
        static let organizationId = "<your_organization_id>"
        static let sessionDuration = "900"  // Session duration in seconds (15 minutes)
        static let apiUrl = "https://api.turnkey.com"
        
        // Default accounts created with new wallets
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
        static let clientId = "<your_google_oauth_client_id>"  // Optional: for Google OAuth
    }
}
```

### 5/ Running the demo

1. Open `swift-demo-wallet.xcodeproj` in Xcode
2. Run the app on your device or simulator

---

## Requirements

- iOS 17+ / macOS 14.0+
- Swift 5.9+
- Xcode 15+
- Node.js 18+

---
