# Turnkey iOS Example

This example demonstrates how to implement a two-step authentication flow using the Turnkey SDK in an iOS app.

## Features

- Email-based account lookup
- Passkey authentication
- Session management
- SwiftUI interface

## Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.5+
- Local proxy server for email lookup

## Setup

1. Clone the repository
2. Open the project in Xcode
3. Start the local proxy server (see below)
4. Build and run the app

## Two-Step Login Flow

The app implements a two-step authentication flow:

1. **Email Lookup**: User enters their email, which is sent to a proxy server to check if an account exists
2. **Passkey Authentication**: If an account exists, the user authenticates with their passkey

This approach provides a seamless user experience while maintaining security.

### Detailed Flow Explanation

#### Step 1: Email Lookup
When a user enters their email address and taps "Continue":

1. The app validates the email format
2. The `LoginViewModel` sends a request to the proxy server
3. The proxy server checks if any Turnkey sub-organizations exist for this email
4. If found, the proxy returns the organization IDs associated with the email
5. If no organizations are found, an error is displayed to the user

#### Step 2: Passkey Authentication
After a successful email lookup:

1. The app initiates a passkey authentication challenge via WebAuthn
2. The user is prompted to authenticate with their device's biometrics or passcode
3. The `passkeyClient` handles the WebAuthn protocol and communication with the Turnkey API
4. Upon successful authentication, a session is established
5. The authenticated client is stored in the `SessionManager`

#### Security Benefits

- **Privacy**: Email verification happens before any authentication attempt
- **Phishing Resistance**: Passkeys are bound to the app's domain, preventing credential theft
- **No Password Storage**: The system never stores passwords, eliminating password-related vulnerabilities
- **Seamless UX**: Users enjoy a smooth login experience with minimal friction

### Implementation Details

The app uses two instances of `TurnkeyClient`:

```swift
// For email lookup via proxy
let proxyClient = TurnkeyClient(proxyURL: "http://localhost:3000/proxy")

// For passkey authentication
let passkeyClient = TurnkeyClient(
    rpId: "com.example.domain", 
    presentationAnchor: presentationAnchor
)
```

The authentication flow is managed by the `LoginViewModel`, which:
1. Calls `proxyClient.getSubOrgIds(filterType: "EMAIL", filterValue: email)`
2. If organization IDs are returned, calls `passkeyClient.login(organizationId: orgId)`
3. On successful login, stores the authenticated client in the `SessionManager`

#### Key Components

**SessionManager.swift**
```swift
final class SessionManager: ObservableObject {
    /// The currently authenticated TurnkeyClient instance
    @Published var client: TurnkeyClient?
    
    /// Clears the current session
    func logout() {
        client = nil
    }
}
```

**LoginViewModel.swift (Core Authentication Logic)**
```swift
func authenticate() async {
    isLoading = true
    
    do {
        // 1. Look up sub-org IDs via proxy
        let response = try await getSubOrgIds(email: email)
        
        // 2. Check if any organizations were found
        guard let organizationId = response.organizationIds.first else {
            throw LoginError.noAccount
        }
        
        // 3. Perform passkey login
        let loggedInClient = try await passkeyClient.login(organizationId: organizationId)
        
        // 4. Save the authenticated client to session
        sessionManager.client = loggedInClient
        
    } catch let error as LoginError {
        errorMessage = error.localizedDescription
    } catch {
        errorMessage = LoginError.networkError(error).localizedDescription
    }
    
    isLoading = false
}
```

**ContentView.swift (Conditional Rendering)**
```swift
var body: some View {
    ZStack {
        // Show HomeView if authenticated, otherwise show LoginView
        if sessionManager.client != nil {
            HomeView()
        } else {
            LoginView(proxyClient: proxyClient, passkeyClient: passkeyClient)
        }
    }
}
```

## Running the Local Proxy

The app requires a local proxy server to handle email lookups. The proxy server should implement the following endpoint:

```
GET /proxy/sub-org-ids?filterType=EMAIL&filterValue={email}
```

The response should be in the format:

```json
{
  "organizationIds": ["org-id-1", "org-id-2"]
}
```

To start the proxy server:

1. Navigate to the proxy server directory
2. Install dependencies: `npm install`
3. Start the server: `npm start`

The server should be running at `http://localhost:3000`.

## Architecture

The app follows the MVVM (Model-View-ViewModel) architecture:

- **Models**: `SessionManager` manages the authenticated client
- **ViewModels**: `LoginViewModel` handles the authentication logic
- **Views**: `LoginView`, `HomeView`, and `ContentView` provide the user interface

### Data Flow

1. **User Input** → User enters email in `LoginView`
2. **View to ViewModel** → Email is bound to `LoginViewModel.email`
3. **ViewModel to Model** → `LoginViewModel` calls proxy API and authentication methods
4. **Model Update** → `SessionManager.client` is updated with authenticated client
5. **UI Update** → `ContentView` observes `SessionManager` and shows `HomeView`

### Dependency Injection

The app uses dependency injection to provide the required components:

- `SessionManager` is injected via SwiftUI's environment
- `TurnkeyClient` instances are created in `ContentView` and passed to `LoginView`
- `LoginViewModel` receives both clients and the session manager

This approach makes the components testable and decoupled.

## Testing

Unit tests for the `LoginViewModel` are included to verify the authentication flow. Run the tests in Xcode using Cmd+U.
