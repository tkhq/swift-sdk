# TurnkeyClient

A lower-level, fully-typed HTTP client for interacting with the Turnkey API, written in Swift using `OpenAPIURLSession`.

> For high-level abstractions like signing transactions or managing wallets, see [TurnkeySwift](../TurnkeySwift/).

Official Turnkey API documentation: [https://docs.turnkey.com](https://docs.turnkey.com)

---

## HTTP Fetchers

This package provides fully-typed HTTP fetchers auto-generated from our OpenAPI schema.

Each endpoint maps to a Swift method on the `TurnkeyClient`, and all request/response types are available for type-safe consumption.

---

## Getting Started

### Initialize: API Keys

To initialize the `TurnkeyClient` using API keys, you need the API public key and API private key. This method is generally suitable for server-side applications where you can securely store these keys or when using email authentication to verify the user's identity.

```swift
let apiPublicKey = "your_api_public_key"
let apiPrivateKey = "your_api_private_key"
let client = TurnkeyClient(apiPrivateKey: apiPrivateKey, apiPublicKey: apiPublicKey)
```

### Initialize: Passkeys

For client-side applications, particularly those that involve user interactions, initializing the `TurnkeyClient` with passkeys might be more appropriate. This requires a relying party identifier and a presentation anchor.

```swift
let rpId = "com.example.domain"
let presentationAnchor = ASPresentationAnchor()
let client = TurnkeyClient(rpId: rpId, presentationAnchor: presentationAnchor)
```

### Initialize: Proxy

To forward all requests through a proxy server:

```swift
let proxyClient = TurnkeyClient(proxyURL: "http://localhost:3000/proxy")
```

---

## Code Generation

Client methods are auto-generated from Swagger specifications. To regenerate:

```bash
cd Scripts && make generate
```

See [Scripts README](../../Scripts/README.md) for details.

---

## Requirements

* iOS 17+ / macOS 14+
* Swift 5.9+
* OpenAPIURLSession
* HTTPTypes

---
