---
bump: major
---

### `organizationId` is now required

**What changed:** `organizationId` is now a required `String` parameter on `TurnkeyClient` and `TurnkeyConfig`. Previously it was optional

All requests made through the client (queries, activities, and activity decisions) automatically fall back to the client's `organizationId` when the request body doesn't include one

#### `TurnkeyClient`

```swift
// before
let client = TurnkeyClient(apiKey: .init(apiPrivateKey: privKey, apiPublicKey: pubKey))
let wallets = try await client.listWallets(.init(organizationId: "org-id-123"))

// after
let client = TurnkeyClient(
  apiKey: .init(apiPrivateKey: privKey, apiPublicKey: pubKey),
  organizationId: "org-id-123"
)
let wallets = try await client.listWallets()
```

#### `TurnkeyConfig`

```swift
// before
TurnkeyConfig( 
  apiBaseUrl: "https://api.turnkey.com",
  // organizationId was optional, often forgotten
)

// after
TurnkeyConfig(
  organizationId: "org-id-123",
  apiBaseUrl: "https://api.turnkey.com"
)
```
