# Two-Step Login Flow Implementation Plan

A checklist of tasks to complete as we update the Turnkey iOS example:

## 1. TurnkeyClient Setup
- [x] Ensure `TurnkeyClient` has initializers:
  - `init(proxyURL: String)`
  - `init(rpId: String, presentationAnchor: ASPresentationAnchor)`
- [x] Verify `getSubOrgIds(filterType:filterValue:)` is available
- [x] Verify `login(organizationId:)` is available and returns a logged-in client or throws

## 2. Session Management
- [x] Create `SessionManager: ObservableObject` with:
  - `@Published var client: TurnkeyClient?`
- [x] Instantiate `SessionManager` in `@main` and inject via `.environmentObject(session)`

## 3. LoginViewModel
- [x] Create `LoginViewModel: ObservableObject` with properties:
  - `@Published var email: String`
  - `@Published var isLoading: Bool`
  - `@Published var errorMessage: String?`
- [x] Implement async `authenticate()` to:
  1. Call `proxyClient.getSubOrgIds(filterType: "EMAIL", filterValue: email)`
  2. Handle empty results and throw `LoginError.noAccount`
  3. Call `passkeyClient.login(organizationId:)`
  4. On success, set `session.client`
  5. Catch and publish errors

## 4. SwiftUI Login Screen
- [x] Build `LoginView`:
  - `TextField("Email", text: $vm.email)`
  - Inline error `Text(vm.errorMessage)` in red
  - `Button { Task { await vm.authenticate() } }`
  - `ProgressView()` when `isLoading`
- [x] Present `HomeView` via conditional rendering in ContentView

## 5. HomeView & Logout
- [x] Create `HomeView` that reads `session.client` from environment
- [x] Add a "Log out" button that sets `session.client = nil`

## 6. UX & Error Handling
- [x] Disable login button if `email.isEmpty || isLoading`
- [x] Display descriptive inline errors and use `.alert` where appropriate

## 7. Testing
- [x] Unit-test `LoginViewModel.authenticate()` using a mock `TurnkeyClient`
- [x] Launch and verify the flow against the local proxy server

## 8. Documentation
- [x] Update `README.md` in `TurnkeyiOSExample` to cover:
  - Running the local proxy
  - Two-step login flow details
  - iOS version/passkey requirements
