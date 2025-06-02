# Turnkey Swift SDK

The Turnkey Swift SDK includes functionality to interact with Turnkey in native Apple environments. It provides everything you need to develop a fully working iOS or macOS app powered by Turnkey.

---

## Packages

| Package Name                                 | Description                                                                                       |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| [TurnkeySwift](./Sources/TurnkeySwift)       | An all-in-one package that simplifies the integration of the Turnkey API into Swift applications. |
| [TurnkeyStamper](./Sources/TurnkeyStamper)   | Provides functionality for signing payloads using API keys or passkeys.                           |
| [TurnkeyPasskeys](./Sources/TurnkeyPasskeys) | A passkey-focused package built on top of Apple's AuthenticationServices framework.               |
| [TurnkeyCrypto](./Sources/TurnkeyCrypto)     | Common cryptographic utilities, including key generation and signing algorithms.                  |
| [TurnkeyHttp](./Sources/TurnkeyHttp)         | A lower-level HTTP client for communicating with the Turnkey API.                                 |
| [TurnkeyEncoding](./Sources/TurnkeyEncoding) | A shared utility package for encoding and decoding used across the SDK.                           |

---

## Example App

We provide a fully functional SwiftUI demo app to showcase real-world usage of the Turnkey Swift SDK. This app includes passkey registration, wallet creation/import, and message signing flows.

You can find it at:

**Path:** `Examples/swift-demo-wallet`

For setup instructions, refer to the [demo app README](./Examples/swift-demo-wallet/README.md).

---
