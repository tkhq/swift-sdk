# Swift SDK

Swift SDK, named "TurnkeySDK", is a comprehensive toolkit designed to facilitate the development of applications using the Turnkey platform. It provides a robust set of functionalities to interact with the Turnkey API, handling everything from authentication to API calls.

## Overview

The TurnkeySDK is built to support macOS, iOS, tvOS, watchOS, and visionOS, making it versatile for various Apple platform developments. It leverages modern Swift features and integrates seamlessly with your projects, ensuring a smooth development experience.

## Installation

To integrate the TurnkeySDK into your Swift project, you need to add it as a dependency in your Package.swift file:

```swift
.package(url: "https://github.com/tkhq/swift-sdk", from: "1.3.0")
```

## Usage

### Initialize: API Keys

To initialize the TurnkeyClient using API keys, you need the API public key and API private key. This method is generally suitable for server-side applications where you can securely store these keys or when using email authentication to verify the user's identity.

```swift
let apiPublicKey = "your_api_public_key"
let apiPrivateKey = "your_api_private_key"
let client = TurnkeyClient(apiPrivateKey: apiPrivateKey, apiPublicKey: apiPublicKey)
```

### Initialize: Passkeys

For client-side applications, particularly those that involve user interactions, initializing the TurnkeyClient with passkeys might be more appropriate. This requires a relying party identifier and a presentation anchor.

```swift
let rpId = "com.example.domain"
let presentationAnchor = ASPresentationAnchor()
let client = TurnkeyClient(rpId: rpId, presentationAnchor: presentationAnchor)
```

When using passkeys, the user will be prompted through a user interface that is anchored by the `presentationAnchor` provided during the initialization of the `PasskeyManager`. This anchor is typically a window or a view controller that serves as the parent for the authorization interface. This ensures that the passkey operations, such as registration and sign-in, are presented in a context that is familiar and secure for the user.

For more details on how the `presentationAnchor` is used and how the `PasskeyManager` handles passkey operations, refer to the implementation in the [PasskeyManager.swift](./Sources/Shared/PasskeyManager.swift) file.

### Example: Get Whoami

To retrieve the current user's identity information using the `getWhoami` method, you first need to initialize the `TurnkeyClient` with your API keys. Here is an example of how you can do this:

```swift
// Example of retrieving Whoami information using API keys
let apiPublicKey = "your_api_public_key"
let apiPrivateKey = "your_api_private_key"
let client = TurnkeyClient(apiPrivateKey: apiPrivateKey, apiPublicKey: apiPublicKey)
// Create an instance of TurnkeyClient
let client = TurnkeyClient(apiPrivateKey: apiPrivateKey!, apiPublicKey: apiPublicKey!)

// Call the GetWhoami method on the TurnkeyClient instance
let output = try await client.getWhoami(organizationId: organizationId!)

// Assert the response
switch output {
case let .ok(response):
    switch response.body {
    case let .json(whoamiResponse):
    print(whoamiResponse.organizationId)
    }
case let .undocumented(statusCode, undocumentedPayload):
    // Handle the undocumented response
    if let body = undocumentedPayload.body {
    // Convert the HTTPBody to a string
    let bodyString = try await String(collecting: body, upTo: .max)
    print("Undocumented response body: \(bodyString)")
    }
    print("Undocumented response: \(statusCode)")
}
```

## Two-Step Authentication Flow

The TurnkeySDK supports a secure two-step authentication flow that combines email verification with passkey authentication. This approach provides enhanced security while maintaining a smooth user experience. The example iOS app demonstrates this implementation.

### How It Works

1. **Email Lookup**: First, verify if an account exists for the provided email
2. **Passkey Authentication**: If an account exists, authenticate using WebAuthn/passkeys

### Implementation Guide

#### 1. Create Two Client Instances

```swift
// For email lookup via proxy server to be stamped by the parent organization's API key
let proxyClient = TurnkeyClient(proxyURL: "http://localhost:3000/proxy")

// For passkey authentication
let presentationAnchor = ASPresentationAnchor()
let passkeyClient = TurnkeyClient(
    rpId: "com.example.domain",
    presentationAnchor: presentationAnchor
)
```

#### 2. Create a Session Manager

```swift
final class SessionManager: ObservableObject {
    // The authenticated client instance
    @Published var client: TurnkeyClient?

    // Clear the session
    func logout() {
        client = nil
    }
}
```

#### 3. Implement the Authentication Logic

```swift
async func authenticate(email: String) {
    do {
        // Step 1: Look up sub-organization IDs by email
        let response = try await getSubOrgIds(email: email)

        // Step 2: Check if any organizations were found
        guard let organizationId = response.organizationIds.first else {
            throw LoginError.noAccount
        }

        // Step 3: Perform passkey authentication
        let loggedInClient = try await passkeyClient.login(organizationId: organizationId)

        // Step 4: Save the authenticated client
        sessionManager.client = loggedInClient

    } catch {
        // Handle authentication errors
    }
}

// Helper function to get organization IDs by email
async func getSubOrgIds(email: String) -> GetSubOrgIdsResponse {
    // Make request to proxy server
    // Return response containing organization IDs
}
```

#### 4. Handle UI State Based on Authentication

```swift
var body: some View {
    if sessionManager.client != nil {
        // User is authenticated - show main content
        AuthenticatedView()
    } else {
        // User is not authenticated - show login
        LoginView()
    }
}
```

### Proxy Server Requirements

When initializing a TurnkeyClient with a proxy URL, the `ProxyMiddleware` intercepts all requests and routes them through your proxy server. The middleware adds a special header `X-Turnkey-Request-Url` containing the original Turnkey API URL that the request was intended for.

Your proxy server should:

1. Extract the original Turnkey API URL from the `X-Turnkey-Request-Url` header
2. Forward the request to that URL with appropriate authentication
3. Return the response exactly as received from Turnkey's API

For the email lookup example in our authentication flow, your proxy server would handle a request to get sub-organization IDs by email, authenticate it with your organization's API key, and return the response.

For a complete implementation, refer to the example iOS app in the repository, which demonstrates this authentication flow in a SwiftUI application.

While we are actively working on providing more comprehensive usage guides and detailed examples for the TurnkeySDK, you can currently find additional information on how to use the SDK by exploring the tests and the codebase. These resources can offer practical insights and demonstrate the SDK's capabilities in action.

## Contributing

For guidelines on how to contribute to the Swift SDK, please refer to the [contributing guide](CONTRIBUTING.md).

## License

Please review the project's license as specified in the LICENSE file.

For any additional questions or issues, please refer to the project's issue tracker or contact the maintainers.
