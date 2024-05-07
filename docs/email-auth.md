# Email Authentication

This guide provides a walkthrough for implementing email authentication in a Swift application using the [TurnkeyClient](../Sources/TurnkeySDK/TurnkeyClient.generated.swift) and [AuthKeyManager](../Sources/Shared/AuthKeyManager.swift). This process involves generating key pairs, handling encrypted bundles, and verifying user identity.

For a more detailed explanation of the email authentication process, please refer to the [Turnkey API documentation](https://docs.turnkey.com/features/email-auth).

## Prerequisites

- A proxy server set up to handle authentication requests.
- Organization ID and API key name from your Turnkey account.

## Step 1: Initialize the TurnkeyClient

Create an instance of TurnkeyClient using a proxy URL to handle the authentication.
As a convenience, we've provided a [ProxyMiddleware](../Sources/Shared/ProxyMiddleware.swift) class that can be used to set up a proxy server to handle the authentication request.
We are using a proxy URL because an authenticated user is required to initiate the email authentication request.

Note: The proxy server must be set up to handle the authentication request and return the exact payload received from the Turnkey API. If the response doesn't match exactly you'll see an undocumented response error in the logs.

```swift
let proxyURL = "http://localhost:3000/api/email-auth"
let client = TurnkeyClient(proxyURL: proxyURL)
```

You may also forgo the use of the provided proxy middleware and make the request yourself.

## Step 2: Generate Ephemeral Key Pair

Use AuthKeyManager to generate a new ephemeral key pair for the email authentication flow.
This key pair is not persisted and is used temporarily during the authentication process.
Note: The 'domain' is used for scoping the key storage specific to an app and is optional for persisting the key.

```swift
let authKeyManager = AuthKeyManager(domain: "your_domain")
let publicKey = try authKeyManager.createKeyPair()
```

## Step 3: Define Authentication Parameters

```swift
let organizationId = "your_organization_id"
let email = "user@example.com"
let targetPublicKey = publicKey.toString(representation: .raw)
let expirationSeconds = "3600"
let emailCustomization = Components.Schemas.EmailCustomizationParams() // Customize as needed
```

## Step 4: Send Email Authentication Request

With the TurnkeyClient initialized and the ephemeral key pair generated, you can now send an email authentication request. This involves using the emailAuth method of the TurnkeyClient, passing the necessary parameters.

```swift
let emailAuthResult = try await client.emailAuth(
    organizationId: organizationId,
    email: email,
    targetPublicKey: targetPublicKey,
    apiKeyName: "your_api_key_name",
    expirationSeconds: expirationSeconds,
    emailCustomization: emailCustomization
)
```

After sending the email authentication request, it's important to handle the response appropriately.If the authentication is successful, you should save the user's sub-organizationId from the response for future use. You'll need this organizationId later to verify the user's keys.

```swift
switch emailAuthResult {
case .ok(let response):
    // The user's sub-organizationId:
    let organizationId = response.activity.organizationId
    // Proceed with user session creation or update
case .undocumented(let statusCode, let undocumentedPayload):
    // Handle error, possibly retry or log
}
```

## Step 6: Verify Encrypted Bundle

After your user receives the encrypted bundle from Turnkey, via email, you need to decrypt this bundle to retrieve the necessary keys for further authentication steps. Use the [`decryptBundle`](../Sources/Shared/AuthKeyManager.swift?plain=1#L160) method from the `AuthKeyManager` to handle this.

```swift
let (privateKey, publicKey) = try authManager.decryptBundle(encryptedBundle)
```

This method will decrypt the encrypted bundle and provide you with the private and public keys needed for the session.
At this point in the authentication process, you have two options:

1. Prompt the user for passkey authentication (using the `PasskeyManager`) and add a passkey as an authenticator.
2. Save the API private key in the keychain and use that for subsequent authentication requests.

Note: Since the decrypted API key is similar to a session key, it should be handled with the same level of security as authentication tokens.

## Step 7: Initializing the TurnkeyClient and Verify the user

After successfully decrypting the encrypted bundle and retrieving the private and public API keys, you can initialize a TurnkeyClient instance using these keys for further authenticated requests:

```swift
// ...

let apiPublicKey = try publicKey.toString(representation: .compressed)
let apiPrivateKey = try privateKey.toString(representation: .raw)

// Initialize a new TurnkeyClient instance with the provided privateKey and publicKey
let turnkeyClient = TurnkeyClient(apiPrivateKey: apiPrivateKey, apiPublicKey: apiPublicKey)
```

### Verifying User Credentials with getWhoami

After initializing the TurnkeyClient with the decrypted API keys, it is recommended to verify the validity of these credentials. This can be done using the `getWhoami` method, which checks the active status of the credentials against the Turnkey API.

```swift
do {
    let whoamiResponse = try await turnkeyClient.getWhoami(organizationId: organizationId /* from emailAuthResult */)

    switch whoamiResponse {
    case .ok(let response):
        print("Credential verification successful: \(whoamiResponse)")
    case .undocumented(let statusCode, let undocumentedPayload):
        print("Error during credential verification: \(error)")
    }
} catch {
    print("Error during credential verification: \(error)")
}


```
