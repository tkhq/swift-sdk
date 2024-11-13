# Swift SDK

Swift SDK, named "TurnkeySDK", is a comprehensive toolkit designed to facilitate the development of applications using the Turnkey platform. It provides a robust set of functionalities to interact with the Turnkey API, handling everything from authentication to API calls.

## Overview

The TurnkeySDK is built to support macOS, iOS, tvOS, watchOS, and visionOS, making it versatile for various Apple platform developments. It leverages modern Swift features and integrates seamlessly with your projects, ensuring a smooth development experience.

## Installation

To integrate the TurnkeySDK into your Swift project, you need to add it as a dependency in your Package.swift file:

```swift
.package(url: "https://github.com/tkhq/swift-sdk", from: "1.2.0")
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

While we are actively working on providing more comprehensive usage guides and detailed examples for the TurnkeySDK, you can currently find additional information on how to use the SDK by exploring the tests and the codebase. These resources can offer practical insights and demonstrate the SDK's capabilities in action. Additionally, you can refer to the example iOS app included in the repository, which serves as a practical reference for implementing features using the Swift SDK.

## Contributing

For guidelines on how to contribute to the Swift SDK, please refer to the [contributing guide](CONTRIBUTING.md).

## License

Please review the project's license as specified in the LICENSE file.

For any additional questions or issues, please refer to the project's issue tracker or contact the maintainers.
