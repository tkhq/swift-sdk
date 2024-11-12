# Email Authentication

This guide provides a walkthrough for implementing email authentication in a Swift application using the [TurnkeyClient](../Sources/TurnkeySDK/TurnkeyClient.generated.swift). This process involves handling encrypted bundles and verifying user identity.

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

## Step 2: Define Authentication Parameters

```swift
let organizationId = "your_organization_id"
let email = "user@example.com"
let expirationSeconds = "3600"
let emailCustomization = Components.Schemas.EmailCustomizationParams() // Customize as needed
```

## Step 3: Send Email Authentication Request

With the TurnkeyClient initialized, you can now send an email authentication request. This involves using the `emailAuth` method of the TurnkeyClient, passing in the necessary parameters.

### Detailed Explanation

- **Ephemeral Key Generation**: The `emailAuth` method generates an ephemeral private key, which is used to create a public key for the authentication process. This ephemeral key is stored in memory and is used to decrypt the encrypted bundle sent to the user's email.

- **Tuple Response**: The `emailAuth` method returns a tuple containing two elements:
  1. `Operations.EmailAuth.Output`: This is the output of the email authentication operation, which includes the response from the Turnkey API.
  2. `verify`: A closure function that takes an encrypted bundle as input and returns an `AuthResult`. This closure uses the ephemeral private key to decrypt the bundle and verify the authentication.

```swift
let (output, verify) = try await client.emailAuth(
    organizationId: organizationId,
    email: email,
    apiKeyName: "your_api_key_name",
    expirationSeconds: expirationSeconds,
    emailCustomization: emailCustomization
)

// Assert the response
switch output {
case let .ok(response):
    switch response.body {
    case let .json(emailAuthResponse):
        print(emailAuthResponse.activity.organizationId)
        // We successfully initiated the email authentication request
        // We'll use the verify function to verify the encrypted bundle in the next step
    }
case let .undocumented(statusCode, undocumentedPayload):
    // Handle the undocumented response
    if let body = undocumentedPayload.body {
        let bodyString = try await String(collecting: body, upTo: .max)
        print("Undocumented response body: \(bodyString)")
    }
    print("Undocumented response: \(statusCode)")
}
```

## Step 4: Verify Encrypted Bundle

After your user receives the encrypted bundle from Turnkey, via email, you need to verify this bundle to retrieve the necessary keys for further authentication steps. We'll use the `verify` function returned from the previous step.

### Detailed Explanation

- **AuthResult**: The `verify` function returns an `AuthResult` object, which contains:

  - `whoamiResponse`: The result of calling `getWhoami`, which verifies the authentication and retrieves user details.
  - `apiPublicKey` and `apiPrivateKey`: The keys obtained from the decrypted bundle, used for further authenticated requests.

- **getWhoami Call**: The `verify` function internally calls the `getWhoami` method to ensure the credentials are valid and to fetch user details from the Turnkey API.

```swift
do {
    let authResult = try await verify(bundle)
    print("Verification successful: \(authResult)")
} catch {
    print("Error occurred during verification: \(error)")
}
```

This method will verify the encrypted bundle and provide you with the necessary authentication result.

## Step 5: Initialize the TurnkeyClient with API Keys

After successfully verifying the encrypted bundle and retrieving the private and public API keys, you can initialize a TurnkeyClient instance using these keys for further authenticated requests:

```swift
// Use the apiPublicKey and apiPrivateKey from the authResult
let apiPublicKey = authResult.apiPublicKey
let apiPrivateKey = authResult.apiPrivateKey

// Initialize a new TurnkeyClient instance with the provided privateKey and publicKey
let turnkeyClient = TurnkeyClient(apiPrivateKey: apiPrivateKey, apiPublicKey: apiPublicKey)
```

## Step 6: Create Read Only Session

### Extract API Keys and Sub-Organization ID

First, get the `apiPublicKey` and `apiPrivateKey` from the `authResult`, and retrieve the `organizationId` from the `whoamiResponse`. Then, instantiate the `TurnkeyClient`.

```swift
// Use the apiPublicKey and apiPrivateKey from the authResult
let apiPublicKey = authResult.apiPublicKey
let apiPrivateKey = authResult.apiPrivateKey

// Get the organizationId from the whoamiResponse
let whoamiResponse = authResult.whoamiResponse
var subOrganizationId: String?

switch whoamiResponse {
case let .ok(response):
    switch response.body {
    case let .json(whoamiResponse):
        subOrganizationId = whoamiResponse.organizationId
        print("Sub-Organization ID: \(subOrganizationId ?? "N/A")")
    }
case let .undocumented(statusCode, undocumentedPayload):
    if let body = undocumentedPayload.body {
        let bodyString = try await String(collecting: body, upTo: .max)
        print("Undocumented response body: \(bodyString)")
    }
    print("Undocumented response: \(statusCode)")
}

// Initialize a new TurnkeyClient instance with the provided privateKey and publicKey
let turnkeyClient = TurnkeyClient(apiPrivateKey: apiPrivateKey, apiPublicKey: apiPublicKey)
```

### Create Read Only Session

Next, use the `subOrganizationId` to call the `createReadOnlySession` method on the `TurnkeyClient`.

```swift
do {
    // Use the user's sub-organization ID to create a read-only session
    if let orgId = subOrganizationId {
        let readOnlySessionOutput = try await turnkeyClient.createReadOnlySession(organizationId: orgId)
        print("Read-only session created successfully: \(readOnlySessionOutput)")
    } else {
        print("Failed to extract organization ID.")
    }
} catch {
    print("Error occurred while creating read-only session: \(error)")
}
```
