// Generated using Sourcery 2.2.5 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

import AuthenticationServices
import CryptoKit
import Foundation
import Middleware
import OpenAPIRuntime
import OpenAPIURLSession
import Shared

public struct TurnkeyClient {
  public static let baseURLString = "https://api.turnkey.com"

  private let underlyingClient: any APIProtocol

  internal init(underlyingClient: any APIProtocol) {
    self.underlyingClient = underlyingClient
  }
  /// Initializes a `TurnkeyClient` with a proxy server URL.
  ///
  /// This initializer configures the `TurnkeyClient` to route all requests through a specified proxy server.
  /// The proxy server is responsible for forwarding these requests to a backend capable of authenticating them using an API private key.
  /// This setup is particularly useful during onboarding flows, such as email authentication and creating new sub-organizations,
  /// where direct authenticated requests are not feasible.
  ///
  /// - Parameter proxyURL: The URL of the proxy server that will forward requests to the authenticating backend.
  ///
  /// - Note: The `TurnkeyClient` initialized with this method does not directly send authenticated requests. Instead, it relies on the proxy server to handle the authentication.
  public init(proxyURL: String) {
    self.init(
      underlyingClient: Client(
        serverURL: URL(string: "https://api.turnkey.com")!,
        transport: URLSessionTransport(),
        middlewares: [ProxyMiddleware(proxyURL: URL(string: proxyURL)!)]
      )
    )
  }

  /// Initializes a `TurnkeyClient` with API keys for authentication.
  ///
  /// This initializer creates an instance of `TurnkeyClient` using the provided `apiPrivateKey` and `apiPublicKey`.
  /// These keys are typically obtained through the Turnkey CLI or your account dashboard. The client uses these keys
  /// to authenticate requests via a `Stamper` which stamps each request with the key pair.
  ///
  /// - Parameters:
  ///   - apiPrivateKey: The private key obtained from Turnkey, used for signing requests.
  ///   - apiPublicKey: The public key obtained from Turnkey, used to identify the client.
  ///   - baseUrl: The base URL of the Turnkey API. Defaults to "https://api.turnkey.com".
  ///
  /// - Note: For client-side usage where all authenticated requests need secure key management,
  ///   it is recommended to use the `AuthKeyManager` for creating, storing, and securely using key pairs.
  ///   For more details, refer to the [AuthKeyManager](#AuthKeyManager).
  ///
  /// - Example:
  ///   ```
  ///   let client = TurnkeyClient(apiPrivateKey: "your_api_private_key", apiPublicKey: "your_api_public_key")
  ///   ```
  public init(
    apiPrivateKey: String, apiPublicKey: String, baseUrl: String = "https://api.turnkey.com"
  ) {
    let stamper = Stamper(apiPublicKey: apiPublicKey, apiPrivateKey: apiPrivateKey)
    self.init(
      underlyingClient: Client(
        serverURL: URL(string: baseUrl)!,
        transport: URLSessionTransport(),
        middlewares: [AuthStampMiddleware(stamper: stamper)]
      )
    )
  }

  /// Creates an instance of the TurnkeyClient that uses passkeys for authentication.
  ///
  /// This initializer sets up the TurnkeyClient with a specific `rpId` (Relying Party Identifier) and `presentationAnchor`.
  ///
  /// - Important:
  ///   You need to have an associated domain with the `webcredentials` service type when making a registration or assertion request;
  ///   otherwise, the request returns an error. For more information, see [Supporting Associated Domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains).
  ///
  /// - Parameters:
  ///   - rpId: The relying party identifier used for passkey authentication.
  ///   - presentationAnchor: The presentation anchor used for displaying authentication interfaces.
  ///   - baseUrl: The base URL of the Turnkey API. Defaults to "https://api.turnkey.com".
  ///
  /// - Example:
  ///   ```
  ///   let presentationAnchor = ASPresentationAnchor()
  ///   let client = TurnkeyClient(rpId: "com.example.domain", presentationAnchor: presentationAnchor)
  ///   ```
  public init(
    rpId: String, presentationAnchor: ASPresentationAnchor,
    baseUrl: String = "https://api.turnkey.com"
  ) {
    let stamper = Stamper(rpId: rpId, presentationAnchor: presentationAnchor)
    self.init(
      underlyingClient: Client(
        serverURL: URL(string: baseUrl)!,
        transport: URLSessionTransport(),
        middlewares: [AuthStampMiddleware(stamper: stamper)]
      )
    )
  }

  public struct AuthResult {
    var whoamiResponse: Operations.GetWhoami.Output
    var apiPublicKey: String
    var apiPrivateKey: String
  }

  /// Performs email-based authentication for an organization.
  ///
  /// This method initiates an email authentication process by generating an ephemeral private key and using its public counterpart
  /// to authenticate the email. It returns a tuple containing the authentication response and a closure to verify the encrypted bundle.
  ///
  /// - Parameters:
  ///   - organizationId: The identifier of the organization initiating the authentication.
  ///   - email: The email address to authenticate.
  ///   - apiKeyName: Optional. The name of the API key used in the authentication process.
  ///   - expirationSeconds: Optional. The duration in seconds before the authentication request expires.
  ///   - emailCustomization: Optional. Customization parameters for the authentication email.
  ///
  /// - Returns: A tuple containing the `Operations.EmailAuth.Output` and a closure `(String) async throws -> Void` that accepts an encrypted bundle for verification.
  ///
  /// - Throws: An error if the authentication process fails.
  ///
  /// - Note: The method internally handles the generation of ephemeral keys and requires proper error handling when calling the returned closure for bundle verification.
  public func emailAuth(
    organizationId: String,
    email: String, apiKeyName: String?, expirationSeconds: String?,
    emailCustomization: Components.Schemas.EmailCustomizationParams?
  ) async throws -> (Operations.EmailAuth.Output, (String) async throws -> AuthResult) {
    let ephemeralPrivateKey = P256.KeyAgreement.PrivateKey()
    let targetPublicKey = try ephemeralPrivateKey.publicKey.toString(representation: .x963)

    let response = try await emailAuth(
      organizationId: organizationId, email: email, targetPublicKey: targetPublicKey,
      apiKeyName: apiKeyName, expirationSeconds: expirationSeconds,
      emailCustomization: emailCustomization)
    let authResponseOrganizationId = try response.ok.body.json.activity.organizationId

    let verify: (String) async throws -> AuthResult = { encryptedBundle in
      let (privateKey:privateKey, publicKey:publicKey) = try AuthManager.decryptBundle(
        encryptedBundle: encryptedBundle, ephemeralPrivateKey: ephemeralPrivateKey)

      let apiPublicKey = try publicKey.toString(representation: .compressed)
      let apiPrivateKey = try privateKey.toString(representation: .raw)

      let turnkeyClient = TurnkeyClient(apiPrivateKey: apiPrivateKey, apiPublicKey: apiPublicKey)

      let whoamiResponse = try await turnkeyClient.getWhoami(
        organizationId: authResponseOrganizationId)

      let result = AuthResult(
        whoamiResponse: whoamiResponse, apiPublicKey: apiPublicKey, apiPrivateKey: apiPrivateKey)
      return result
    }

    return (response, verify)
  }

  public func publicApiService_GetActivity() async throws
    -> Operations.PublicApiService_GetActivity.Output
  {

    // Create the PublicApiService_GetActivityRequest
    let publicApiService_GetActivityRequest = Components.Schemas
      .PublicApiService_GetActivityRequest()

    let input = Operations.PublicApiService_GetActivity.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetActivityRequest)
    )
    return try await underlyingClient.PublicApiService_GetActivity(input)
  }
  public func publicApiService_GetApiKey() async throws
    -> Operations.PublicApiService_GetApiKey.Output
  {

    // Create the PublicApiService_GetApiKeyRequest
    let publicApiService_GetApiKeyRequest = Components.Schemas.PublicApiService_GetApiKeyRequest()

    let input = Operations.PublicApiService_GetApiKey.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetApiKeyRequest)
    )
    return try await underlyingClient.PublicApiService_GetApiKey(input)
  }
  public func publicApiService_GetApiKeys() async throws
    -> Operations.PublicApiService_GetApiKeys.Output
  {

    // Create the PublicApiService_GetApiKeysRequest
    let publicApiService_GetApiKeysRequest = Components.Schemas.PublicApiService_GetApiKeysRequest()

    let input = Operations.PublicApiService_GetApiKeys.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetApiKeysRequest)
    )
    return try await underlyingClient.PublicApiService_GetApiKeys(input)
  }
  public func publicApiService_GetAttestationDocument() async throws
    -> Operations.PublicApiService_GetAttestationDocument.Output
  {

    // Create the PublicApiService_GetAttestationDocumentRequest
    let publicApiService_GetAttestationDocumentRequest = Components.Schemas
      .PublicApiService_GetAttestationDocumentRequest()

    let input = Operations.PublicApiService_GetAttestationDocument.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetAttestationDocumentRequest)
    )
    return try await underlyingClient.PublicApiService_GetAttestationDocument(input)
  }
  public func publicApiService_GetAuthenticator() async throws
    -> Operations.PublicApiService_GetAuthenticator.Output
  {

    // Create the PublicApiService_GetAuthenticatorRequest
    let publicApiService_GetAuthenticatorRequest = Components.Schemas
      .PublicApiService_GetAuthenticatorRequest()

    let input = Operations.PublicApiService_GetAuthenticator.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetAuthenticatorRequest)
    )
    return try await underlyingClient.PublicApiService_GetAuthenticator(input)
  }
  public func publicApiService_GetAuthenticators() async throws
    -> Operations.PublicApiService_GetAuthenticators.Output
  {

    // Create the PublicApiService_GetAuthenticatorsRequest
    let publicApiService_GetAuthenticatorsRequest = Components.Schemas
      .PublicApiService_GetAuthenticatorsRequest()

    let input = Operations.PublicApiService_GetAuthenticators.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetAuthenticatorsRequest)
    )
    return try await underlyingClient.PublicApiService_GetAuthenticators(input)
  }
  public func publicApiService_GetOauthProviders() async throws
    -> Operations.PublicApiService_GetOauthProviders.Output
  {

    // Create the PublicApiService_GetOauthProvidersRequest
    let publicApiService_GetOauthProvidersRequest = Components.Schemas
      .PublicApiService_GetOauthProvidersRequest()

    let input = Operations.PublicApiService_GetOauthProviders.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetOauthProvidersRequest)
    )
    return try await underlyingClient.PublicApiService_GetOauthProviders(input)
  }
  public func publicApiService_GetOrganization() async throws
    -> Operations.PublicApiService_GetOrganization.Output
  {

    // Create the PublicApiService_GetOrganizationRequest
    let publicApiService_GetOrganizationRequest = Components.Schemas
      .PublicApiService_GetOrganizationRequest()

    let input = Operations.PublicApiService_GetOrganization.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetOrganizationRequest)
    )
    return try await underlyingClient.PublicApiService_GetOrganization(input)
  }
  public func publicApiService_GetOrganizationConfigs() async throws
    -> Operations.PublicApiService_GetOrganizationConfigs.Output
  {

    // Create the PublicApiService_GetOrganizationConfigsRequest
    let publicApiService_GetOrganizationConfigsRequest = Components.Schemas
      .PublicApiService_GetOrganizationConfigsRequest()

    let input = Operations.PublicApiService_GetOrganizationConfigs.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetOrganizationConfigsRequest)
    )
    return try await underlyingClient.PublicApiService_GetOrganizationConfigs(input)
  }
  public func publicApiService_GetPolicy() async throws
    -> Operations.PublicApiService_GetPolicy.Output
  {

    // Create the PublicApiService_GetPolicyRequest
    let publicApiService_GetPolicyRequest = Components.Schemas.PublicApiService_GetPolicyRequest()

    let input = Operations.PublicApiService_GetPolicy.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetPolicyRequest)
    )
    return try await underlyingClient.PublicApiService_GetPolicy(input)
  }
  public func publicApiService_GetPrivateKey() async throws
    -> Operations.PublicApiService_GetPrivateKey.Output
  {

    // Create the PublicApiService_GetPrivateKeyRequest
    let publicApiService_GetPrivateKeyRequest = Components.Schemas
      .PublicApiService_GetPrivateKeyRequest()

    let input = Operations.PublicApiService_GetPrivateKey.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetPrivateKeyRequest)
    )
    return try await underlyingClient.PublicApiService_GetPrivateKey(input)
  }
  public func publicApiService_GetUser() async throws -> Operations.PublicApiService_GetUser.Output
  {

    // Create the PublicApiService_GetUserRequest
    let publicApiService_GetUserRequest = Components.Schemas.PublicApiService_GetUserRequest()

    let input = Operations.PublicApiService_GetUser.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetUserRequest)
    )
    return try await underlyingClient.PublicApiService_GetUser(input)
  }
  public func publicApiService_GetWallet() async throws
    -> Operations.PublicApiService_GetWallet.Output
  {

    // Create the PublicApiService_GetWalletRequest
    let publicApiService_GetWalletRequest = Components.Schemas.PublicApiService_GetWalletRequest()

    let input = Operations.PublicApiService_GetWallet.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetWalletRequest)
    )
    return try await underlyingClient.PublicApiService_GetWallet(input)
  }
  public func publicApiService_GetActivities() async throws
    -> Operations.PublicApiService_GetActivities.Output
  {

    // Create the PublicApiService_GetActivitiesRequest
    let publicApiService_GetActivitiesRequest = Components.Schemas
      .PublicApiService_GetActivitiesRequest()

    let input = Operations.PublicApiService_GetActivities.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetActivitiesRequest)
    )
    return try await underlyingClient.PublicApiService_GetActivities(input)
  }
  public func publicApiService_GetPolicies() async throws
    -> Operations.PublicApiService_GetPolicies.Output
  {

    // Create the PublicApiService_GetPoliciesRequest
    let publicApiService_GetPoliciesRequest = Components.Schemas
      .PublicApiService_GetPoliciesRequest()

    let input = Operations.PublicApiService_GetPolicies.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetPoliciesRequest)
    )
    return try await underlyingClient.PublicApiService_GetPolicies(input)
  }
  public func publicApiService_ListPrivateKeyTags() async throws
    -> Operations.PublicApiService_ListPrivateKeyTags.Output
  {

    // Create the PublicApiService_ListPrivateKeyTagsRequest
    let publicApiService_ListPrivateKeyTagsRequest = Components.Schemas
      .PublicApiService_ListPrivateKeyTagsRequest()

    let input = Operations.PublicApiService_ListPrivateKeyTags.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_ListPrivateKeyTagsRequest)
    )
    return try await underlyingClient.PublicApiService_ListPrivateKeyTags(input)
  }
  public func publicApiService_GetPrivateKeys() async throws
    -> Operations.PublicApiService_GetPrivateKeys.Output
  {

    // Create the PublicApiService_GetPrivateKeysRequest
    let publicApiService_GetPrivateKeysRequest = Components.Schemas
      .PublicApiService_GetPrivateKeysRequest()

    let input = Operations.PublicApiService_GetPrivateKeys.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetPrivateKeysRequest)
    )
    return try await underlyingClient.PublicApiService_GetPrivateKeys(input)
  }
  public func publicApiService_GetSubOrgIds() async throws
    -> Operations.PublicApiService_GetSubOrgIds.Output
  {

    // Create the PublicApiService_GetSubOrgIdsRequest
    let publicApiService_GetSubOrgIdsRequest = Components.Schemas
      .PublicApiService_GetSubOrgIdsRequest()

    let input = Operations.PublicApiService_GetSubOrgIds.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetSubOrgIdsRequest)
    )
    return try await underlyingClient.PublicApiService_GetSubOrgIds(input)
  }
  public func publicApiService_ListUserTags() async throws
    -> Operations.PublicApiService_ListUserTags.Output
  {

    // Create the PublicApiService_ListUserTagsRequest
    let publicApiService_ListUserTagsRequest = Components.Schemas
      .PublicApiService_ListUserTagsRequest()

    let input = Operations.PublicApiService_ListUserTags.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_ListUserTagsRequest)
    )
    return try await underlyingClient.PublicApiService_ListUserTags(input)
  }
  public func publicApiService_GetUsers() async throws
    -> Operations.PublicApiService_GetUsers.Output
  {

    // Create the PublicApiService_GetUsersRequest
    let publicApiService_GetUsersRequest = Components.Schemas.PublicApiService_GetUsersRequest()

    let input = Operations.PublicApiService_GetUsers.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetUsersRequest)
    )
    return try await underlyingClient.PublicApiService_GetUsers(input)
  }
  public func publicApiService_GetWalletAccounts() async throws
    -> Operations.PublicApiService_GetWalletAccounts.Output
  {

    // Create the PublicApiService_GetWalletAccountsRequest
    let publicApiService_GetWalletAccountsRequest = Components.Schemas
      .PublicApiService_GetWalletAccountsRequest()

    let input = Operations.PublicApiService_GetWalletAccounts.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetWalletAccountsRequest)
    )
    return try await underlyingClient.PublicApiService_GetWalletAccounts(input)
  }
  public func publicApiService_GetWallets() async throws
    -> Operations.PublicApiService_GetWallets.Output
  {

    // Create the PublicApiService_GetWalletsRequest
    let publicApiService_GetWalletsRequest = Components.Schemas.PublicApiService_GetWalletsRequest()

    let input = Operations.PublicApiService_GetWallets.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetWalletsRequest)
    )
    return try await underlyingClient.PublicApiService_GetWallets(input)
  }
  public func publicApiService_GetWhoami() async throws
    -> Operations.PublicApiService_GetWhoami.Output
  {

    // Create the PublicApiService_GetWhoamiRequest
    let publicApiService_GetWhoamiRequest = Components.Schemas.PublicApiService_GetWhoamiRequest()

    let input = Operations.PublicApiService_GetWhoami.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_GetWhoamiRequest)
    )
    return try await underlyingClient.PublicApiService_GetWhoami(input)
  }
  public func publicApiService_ApproveActivity() async throws
    -> Operations.PublicApiService_ApproveActivity.Output
  {

    // Create the PublicApiService_ApproveActivityRequest
    let publicApiService_ApproveActivityRequest = Components.Schemas
      .PublicApiService_ApproveActivityRequest()

    let input = Operations.PublicApiService_ApproveActivity.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_ApproveActivityRequest)
    )
    return try await underlyingClient.PublicApiService_ApproveActivity(input)
  }
  public func publicApiService_CreateApiKeys() async throws
    -> Operations.PublicApiService_CreateApiKeys.Output
  {

    // Create the PublicApiService_CreateApiKeysRequest
    let publicApiService_CreateApiKeysRequest = Components.Schemas
      .PublicApiService_CreateApiKeysRequest()

    let input = Operations.PublicApiService_CreateApiKeys.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_CreateApiKeysRequest)
    )
    return try await underlyingClient.PublicApiService_CreateApiKeys(input)
  }
  public func publicApiService_CreateApiOnlyUsers() async throws
    -> Operations.PublicApiService_CreateApiOnlyUsers.Output
  {

    // Create the PublicApiService_CreateApiOnlyUsersRequest
    let publicApiService_CreateApiOnlyUsersRequest = Components.Schemas
      .PublicApiService_CreateApiOnlyUsersRequest()

    let input = Operations.PublicApiService_CreateApiOnlyUsers.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_CreateApiOnlyUsersRequest)
    )
    return try await underlyingClient.PublicApiService_CreateApiOnlyUsers(input)
  }
  public func publicApiService_CreateAuthenticators() async throws
    -> Operations.PublicApiService_CreateAuthenticators.Output
  {

    // Create the PublicApiService_CreateAuthenticatorsRequest
    let publicApiService_CreateAuthenticatorsRequest = Components.Schemas
      .PublicApiService_CreateAuthenticatorsRequest()

    let input = Operations.PublicApiService_CreateAuthenticators.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_CreateAuthenticatorsRequest)
    )
    return try await underlyingClient.PublicApiService_CreateAuthenticators(input)
  }
  public func publicApiService_CreateInvitations() async throws
    -> Operations.PublicApiService_CreateInvitations.Output
  {

    // Create the PublicApiService_CreateInvitationsRequest
    let publicApiService_CreateInvitationsRequest = Components.Schemas
      .PublicApiService_CreateInvitationsRequest()

    let input = Operations.PublicApiService_CreateInvitations.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_CreateInvitationsRequest)
    )
    return try await underlyingClient.PublicApiService_CreateInvitations(input)
  }
  public func publicApiService_CreateOauthProviders() async throws
    -> Operations.PublicApiService_CreateOauthProviders.Output
  {

    // Create the PublicApiService_CreateOauthProvidersRequest
    let publicApiService_CreateOauthProvidersRequest = Components.Schemas
      .PublicApiService_CreateOauthProvidersRequest()

    let input = Operations.PublicApiService_CreateOauthProviders.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_CreateOauthProvidersRequest)
    )
    return try await underlyingClient.PublicApiService_CreateOauthProviders(input)
  }
  public func publicApiService_CreatePolicies() async throws
    -> Operations.PublicApiService_CreatePolicies.Output
  {

    // Create the PublicApiService_CreatePoliciesRequest
    let publicApiService_CreatePoliciesRequest = Components.Schemas
      .PublicApiService_CreatePoliciesRequest()

    let input = Operations.PublicApiService_CreatePolicies.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_CreatePoliciesRequest)
    )
    return try await underlyingClient.PublicApiService_CreatePolicies(input)
  }
  public func publicApiService_CreatePolicy() async throws
    -> Operations.PublicApiService_CreatePolicy.Output
  {

    // Create the PublicApiService_CreatePolicyRequest
    let publicApiService_CreatePolicyRequest = Components.Schemas
      .PublicApiService_CreatePolicyRequest()

    let input = Operations.PublicApiService_CreatePolicy.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_CreatePolicyRequest)
    )
    return try await underlyingClient.PublicApiService_CreatePolicy(input)
  }
  public func publicApiService_CreatePrivateKeyTag() async throws
    -> Operations.PublicApiService_CreatePrivateKeyTag.Output
  {

    // Create the PublicApiService_CreatePrivateKeyTagRequest
    let publicApiService_CreatePrivateKeyTagRequest = Components.Schemas
      .PublicApiService_CreatePrivateKeyTagRequest()

    let input = Operations.PublicApiService_CreatePrivateKeyTag.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_CreatePrivateKeyTagRequest)
    )
    return try await underlyingClient.PublicApiService_CreatePrivateKeyTag(input)
  }
  public func publicApiService_CreatePrivateKeys() async throws
    -> Operations.PublicApiService_CreatePrivateKeys.Output
  {

    // Create the PublicApiService_CreatePrivateKeysRequest
    let publicApiService_CreatePrivateKeysRequest = Components.Schemas
      .PublicApiService_CreatePrivateKeysRequest()

    let input = Operations.PublicApiService_CreatePrivateKeys.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_CreatePrivateKeysRequest)
    )
    return try await underlyingClient.PublicApiService_CreatePrivateKeys(input)
  }
  public func publicApiService_CreateReadOnlySession() async throws
    -> Operations.PublicApiService_CreateReadOnlySession.Output
  {

    // Create the PublicApiService_CreateReadOnlySessionRequest
    let publicApiService_CreateReadOnlySessionRequest = Components.Schemas
      .PublicApiService_CreateReadOnlySessionRequest()

    let input = Operations.PublicApiService_CreateReadOnlySession.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_CreateReadOnlySessionRequest)
    )
    return try await underlyingClient.PublicApiService_CreateReadOnlySession(input)
  }
  public func publicApiService_CreateReadWriteSession() async throws
    -> Operations.PublicApiService_CreateReadWriteSession.Output
  {

    // Create the PublicApiService_CreateReadWriteSessionRequest
    let publicApiService_CreateReadWriteSessionRequest = Components.Schemas
      .PublicApiService_CreateReadWriteSessionRequest()

    let input = Operations.PublicApiService_CreateReadWriteSession.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_CreateReadWriteSessionRequest)
    )
    return try await underlyingClient.PublicApiService_CreateReadWriteSession(input)
  }
  public func publicApiService_CreateSubOrganization() async throws
    -> Operations.PublicApiService_CreateSubOrganization.Output
  {

    // Create the PublicApiService_CreateSubOrganizationRequest
    let publicApiService_CreateSubOrganizationRequest = Components.Schemas
      .PublicApiService_CreateSubOrganizationRequest()

    let input = Operations.PublicApiService_CreateSubOrganization.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_CreateSubOrganizationRequest)
    )
    return try await underlyingClient.PublicApiService_CreateSubOrganization(input)
  }
  public func publicApiService_CreateUserTag() async throws
    -> Operations.PublicApiService_CreateUserTag.Output
  {

    // Create the PublicApiService_CreateUserTagRequest
    let publicApiService_CreateUserTagRequest = Components.Schemas
      .PublicApiService_CreateUserTagRequest()

    let input = Operations.PublicApiService_CreateUserTag.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_CreateUserTagRequest)
    )
    return try await underlyingClient.PublicApiService_CreateUserTag(input)
  }
  public func publicApiService_CreateUsers() async throws
    -> Operations.PublicApiService_CreateUsers.Output
  {

    // Create the PublicApiService_CreateUsersRequest
    let publicApiService_CreateUsersRequest = Components.Schemas
      .PublicApiService_CreateUsersRequest()

    let input = Operations.PublicApiService_CreateUsers.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_CreateUsersRequest)
    )
    return try await underlyingClient.PublicApiService_CreateUsers(input)
  }
  public func publicApiService_CreateWallet() async throws
    -> Operations.PublicApiService_CreateWallet.Output
  {

    // Create the PublicApiService_CreateWalletRequest
    let publicApiService_CreateWalletRequest = Components.Schemas
      .PublicApiService_CreateWalletRequest()

    let input = Operations.PublicApiService_CreateWallet.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_CreateWalletRequest)
    )
    return try await underlyingClient.PublicApiService_CreateWallet(input)
  }
  public func publicApiService_CreateWalletAccounts() async throws
    -> Operations.PublicApiService_CreateWalletAccounts.Output
  {

    // Create the PublicApiService_CreateWalletAccountsRequest
    let publicApiService_CreateWalletAccountsRequest = Components.Schemas
      .PublicApiService_CreateWalletAccountsRequest()

    let input = Operations.PublicApiService_CreateWalletAccounts.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_CreateWalletAccountsRequest)
    )
    return try await underlyingClient.PublicApiService_CreateWalletAccounts(input)
  }
  public func publicApiService_DeleteApiKeys() async throws
    -> Operations.PublicApiService_DeleteApiKeys.Output
  {

    // Create the PublicApiService_DeleteApiKeysRequest
    let publicApiService_DeleteApiKeysRequest = Components.Schemas
      .PublicApiService_DeleteApiKeysRequest()

    let input = Operations.PublicApiService_DeleteApiKeys.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_DeleteApiKeysRequest)
    )
    return try await underlyingClient.PublicApiService_DeleteApiKeys(input)
  }
  public func publicApiService_DeleteAuthenticators() async throws
    -> Operations.PublicApiService_DeleteAuthenticators.Output
  {

    // Create the PublicApiService_DeleteAuthenticatorsRequest
    let publicApiService_DeleteAuthenticatorsRequest = Components.Schemas
      .PublicApiService_DeleteAuthenticatorsRequest()

    let input = Operations.PublicApiService_DeleteAuthenticators.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_DeleteAuthenticatorsRequest)
    )
    return try await underlyingClient.PublicApiService_DeleteAuthenticators(input)
  }
  public func publicApiService_DeleteInvitation() async throws
    -> Operations.PublicApiService_DeleteInvitation.Output
  {

    // Create the PublicApiService_DeleteInvitationRequest
    let publicApiService_DeleteInvitationRequest = Components.Schemas
      .PublicApiService_DeleteInvitationRequest()

    let input = Operations.PublicApiService_DeleteInvitation.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_DeleteInvitationRequest)
    )
    return try await underlyingClient.PublicApiService_DeleteInvitation(input)
  }
  public func publicApiService_DeleteOauthProviders() async throws
    -> Operations.PublicApiService_DeleteOauthProviders.Output
  {

    // Create the PublicApiService_DeleteOauthProvidersRequest
    let publicApiService_DeleteOauthProvidersRequest = Components.Schemas
      .PublicApiService_DeleteOauthProvidersRequest()

    let input = Operations.PublicApiService_DeleteOauthProviders.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_DeleteOauthProvidersRequest)
    )
    return try await underlyingClient.PublicApiService_DeleteOauthProviders(input)
  }
  public func publicApiService_DeletePolicy() async throws
    -> Operations.PublicApiService_DeletePolicy.Output
  {

    // Create the PublicApiService_DeletePolicyRequest
    let publicApiService_DeletePolicyRequest = Components.Schemas
      .PublicApiService_DeletePolicyRequest()

    let input = Operations.PublicApiService_DeletePolicy.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_DeletePolicyRequest)
    )
    return try await underlyingClient.PublicApiService_DeletePolicy(input)
  }
  public func publicApiService_DeletePrivateKeyTags() async throws
    -> Operations.PublicApiService_DeletePrivateKeyTags.Output
  {

    // Create the PublicApiService_DeletePrivateKeyTagsRequest
    let publicApiService_DeletePrivateKeyTagsRequest = Components.Schemas
      .PublicApiService_DeletePrivateKeyTagsRequest()

    let input = Operations.PublicApiService_DeletePrivateKeyTags.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_DeletePrivateKeyTagsRequest)
    )
    return try await underlyingClient.PublicApiService_DeletePrivateKeyTags(input)
  }
  public func publicApiService_DeletePrivateKeys() async throws
    -> Operations.PublicApiService_DeletePrivateKeys.Output
  {

    // Create the PublicApiService_DeletePrivateKeysRequest
    let publicApiService_DeletePrivateKeysRequest = Components.Schemas
      .PublicApiService_DeletePrivateKeysRequest()

    let input = Operations.PublicApiService_DeletePrivateKeys.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_DeletePrivateKeysRequest)
    )
    return try await underlyingClient.PublicApiService_DeletePrivateKeys(input)
  }
  public func publicApiService_DeleteSubOrganization() async throws
    -> Operations.PublicApiService_DeleteSubOrganization.Output
  {

    // Create the PublicApiService_DeleteSubOrganizationRequest
    let publicApiService_DeleteSubOrganizationRequest = Components.Schemas
      .PublicApiService_DeleteSubOrganizationRequest()

    let input = Operations.PublicApiService_DeleteSubOrganization.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_DeleteSubOrganizationRequest)
    )
    return try await underlyingClient.PublicApiService_DeleteSubOrganization(input)
  }
  public func publicApiService_DeleteUserTags() async throws
    -> Operations.PublicApiService_DeleteUserTags.Output
  {

    // Create the PublicApiService_DeleteUserTagsRequest
    let publicApiService_DeleteUserTagsRequest = Components.Schemas
      .PublicApiService_DeleteUserTagsRequest()

    let input = Operations.PublicApiService_DeleteUserTags.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_DeleteUserTagsRequest)
    )
    return try await underlyingClient.PublicApiService_DeleteUserTags(input)
  }
  public func publicApiService_DeleteUsers() async throws
    -> Operations.PublicApiService_DeleteUsers.Output
  {

    // Create the PublicApiService_DeleteUsersRequest
    let publicApiService_DeleteUsersRequest = Components.Schemas
      .PublicApiService_DeleteUsersRequest()

    let input = Operations.PublicApiService_DeleteUsers.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_DeleteUsersRequest)
    )
    return try await underlyingClient.PublicApiService_DeleteUsers(input)
  }
  public func publicApiService_DeleteWallets() async throws
    -> Operations.PublicApiService_DeleteWallets.Output
  {

    // Create the PublicApiService_DeleteWalletsRequest
    let publicApiService_DeleteWalletsRequest = Components.Schemas
      .PublicApiService_DeleteWalletsRequest()

    let input = Operations.PublicApiService_DeleteWallets.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_DeleteWalletsRequest)
    )
    return try await underlyingClient.PublicApiService_DeleteWallets(input)
  }
  public func publicApiService_EmailAuth() async throws
    -> Operations.PublicApiService_EmailAuth.Output
  {

    // Create the PublicApiService_EmailAuthRequest
    let publicApiService_EmailAuthRequest = Components.Schemas.PublicApiService_EmailAuthRequest()

    let input = Operations.PublicApiService_EmailAuth.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_EmailAuthRequest)
    )
    return try await underlyingClient.PublicApiService_EmailAuth(input)
  }
  public func publicApiService_ExportPrivateKey() async throws
    -> Operations.PublicApiService_ExportPrivateKey.Output
  {

    // Create the PublicApiService_ExportPrivateKeyRequest
    let publicApiService_ExportPrivateKeyRequest = Components.Schemas
      .PublicApiService_ExportPrivateKeyRequest()

    let input = Operations.PublicApiService_ExportPrivateKey.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_ExportPrivateKeyRequest)
    )
    return try await underlyingClient.PublicApiService_ExportPrivateKey(input)
  }
  public func publicApiService_ExportWallet() async throws
    -> Operations.PublicApiService_ExportWallet.Output
  {

    // Create the PublicApiService_ExportWalletRequest
    let publicApiService_ExportWalletRequest = Components.Schemas
      .PublicApiService_ExportWalletRequest()

    let input = Operations.PublicApiService_ExportWallet.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_ExportWalletRequest)
    )
    return try await underlyingClient.PublicApiService_ExportWallet(input)
  }
  public func publicApiService_ExportWalletAccount() async throws
    -> Operations.PublicApiService_ExportWalletAccount.Output
  {

    // Create the PublicApiService_ExportWalletAccountRequest
    let publicApiService_ExportWalletAccountRequest = Components.Schemas
      .PublicApiService_ExportWalletAccountRequest()

    let input = Operations.PublicApiService_ExportWalletAccount.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_ExportWalletAccountRequest)
    )
    return try await underlyingClient.PublicApiService_ExportWalletAccount(input)
  }
  public func publicApiService_ImportPrivateKey() async throws
    -> Operations.PublicApiService_ImportPrivateKey.Output
  {

    // Create the PublicApiService_ImportPrivateKeyRequest
    let publicApiService_ImportPrivateKeyRequest = Components.Schemas
      .PublicApiService_ImportPrivateKeyRequest()

    let input = Operations.PublicApiService_ImportPrivateKey.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_ImportPrivateKeyRequest)
    )
    return try await underlyingClient.PublicApiService_ImportPrivateKey(input)
  }
  public func publicApiService_ImportWallet() async throws
    -> Operations.PublicApiService_ImportWallet.Output
  {

    // Create the PublicApiService_ImportWalletRequest
    let publicApiService_ImportWalletRequest = Components.Schemas
      .PublicApiService_ImportWalletRequest()

    let input = Operations.PublicApiService_ImportWallet.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_ImportWalletRequest)
    )
    return try await underlyingClient.PublicApiService_ImportWallet(input)
  }
  public func publicApiService_InitImportPrivateKey() async throws
    -> Operations.PublicApiService_InitImportPrivateKey.Output
  {

    // Create the PublicApiService_InitImportPrivateKeyRequest
    let publicApiService_InitImportPrivateKeyRequest = Components.Schemas
      .PublicApiService_InitImportPrivateKeyRequest()

    let input = Operations.PublicApiService_InitImportPrivateKey.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_InitImportPrivateKeyRequest)
    )
    return try await underlyingClient.PublicApiService_InitImportPrivateKey(input)
  }
  public func publicApiService_InitImportWallet() async throws
    -> Operations.PublicApiService_InitImportWallet.Output
  {

    // Create the PublicApiService_InitImportWalletRequest
    let publicApiService_InitImportWalletRequest = Components.Schemas
      .PublicApiService_InitImportWalletRequest()

    let input = Operations.PublicApiService_InitImportWallet.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_InitImportWalletRequest)
    )
    return try await underlyingClient.PublicApiService_InitImportWallet(input)
  }
  public func publicApiService_InitOtpAuth() async throws
    -> Operations.PublicApiService_InitOtpAuth.Output
  {

    // Create the PublicApiService_InitOtpAuthRequest
    let publicApiService_InitOtpAuthRequest = Components.Schemas
      .PublicApiService_InitOtpAuthRequest()

    let input = Operations.PublicApiService_InitOtpAuth.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_InitOtpAuthRequest)
    )
    return try await underlyingClient.PublicApiService_InitOtpAuth(input)
  }
  public func publicApiService_InitUserEmailRecovery() async throws
    -> Operations.PublicApiService_InitUserEmailRecovery.Output
  {

    // Create the PublicApiService_InitUserEmailRecoveryRequest
    let publicApiService_InitUserEmailRecoveryRequest = Components.Schemas
      .PublicApiService_InitUserEmailRecoveryRequest()

    let input = Operations.PublicApiService_InitUserEmailRecovery.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_InitUserEmailRecoveryRequest)
    )
    return try await underlyingClient.PublicApiService_InitUserEmailRecovery(input)
  }
  public func publicApiService_Oauth() async throws -> Operations.PublicApiService_Oauth.Output {

    // Create the PublicApiService_OauthRequest
    let publicApiService_OauthRequest = Components.Schemas.PublicApiService_OauthRequest()

    let input = Operations.PublicApiService_Oauth.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_OauthRequest)
    )
    return try await underlyingClient.PublicApiService_Oauth(input)
  }
  public func publicApiService_OtpAuth() async throws -> Operations.PublicApiService_OtpAuth.Output
  {

    // Create the PublicApiService_OtpAuthRequest
    let publicApiService_OtpAuthRequest = Components.Schemas.PublicApiService_OtpAuthRequest()

    let input = Operations.PublicApiService_OtpAuth.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_OtpAuthRequest)
    )
    return try await underlyingClient.PublicApiService_OtpAuth(input)
  }
  public func publicApiService_RecoverUser() async throws
    -> Operations.PublicApiService_RecoverUser.Output
  {

    // Create the PublicApiService_RecoverUserRequest
    let publicApiService_RecoverUserRequest = Components.Schemas
      .PublicApiService_RecoverUserRequest()

    let input = Operations.PublicApiService_RecoverUser.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_RecoverUserRequest)
    )
    return try await underlyingClient.PublicApiService_RecoverUser(input)
  }
  public func publicApiService_RejectActivity() async throws
    -> Operations.PublicApiService_RejectActivity.Output
  {

    // Create the PublicApiService_RejectActivityRequest
    let publicApiService_RejectActivityRequest = Components.Schemas
      .PublicApiService_RejectActivityRequest()

    let input = Operations.PublicApiService_RejectActivity.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_RejectActivityRequest)
    )
    return try await underlyingClient.PublicApiService_RejectActivity(input)
  }
  public func publicApiService_RemoveOrganizationFeature() async throws
    -> Operations.PublicApiService_RemoveOrganizationFeature.Output
  {

    // Create the PublicApiService_RemoveOrganizationFeatureRequest
    let publicApiService_RemoveOrganizationFeatureRequest = Components.Schemas
      .PublicApiService_RemoveOrganizationFeatureRequest()

    let input = Operations.PublicApiService_RemoveOrganizationFeature.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_RemoveOrganizationFeatureRequest)
    )
    return try await underlyingClient.PublicApiService_RemoveOrganizationFeature(input)
  }
  public func publicApiService_SetOrganizationFeature() async throws
    -> Operations.PublicApiService_SetOrganizationFeature.Output
  {

    // Create the PublicApiService_SetOrganizationFeatureRequest
    let publicApiService_SetOrganizationFeatureRequest = Components.Schemas
      .PublicApiService_SetOrganizationFeatureRequest()

    let input = Operations.PublicApiService_SetOrganizationFeature.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_SetOrganizationFeatureRequest)
    )
    return try await underlyingClient.PublicApiService_SetOrganizationFeature(input)
  }
  public func publicApiService_SignRawPayload() async throws
    -> Operations.PublicApiService_SignRawPayload.Output
  {

    // Create the PublicApiService_SignRawPayloadRequest
    let publicApiService_SignRawPayloadRequest = Components.Schemas
      .PublicApiService_SignRawPayloadRequest()

    let input = Operations.PublicApiService_SignRawPayload.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_SignRawPayloadRequest)
    )
    return try await underlyingClient.PublicApiService_SignRawPayload(input)
  }
  public func publicApiService_SignRawPayloads() async throws
    -> Operations.PublicApiService_SignRawPayloads.Output
  {

    // Create the PublicApiService_SignRawPayloadsRequest
    let publicApiService_SignRawPayloadsRequest = Components.Schemas
      .PublicApiService_SignRawPayloadsRequest()

    let input = Operations.PublicApiService_SignRawPayloads.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_SignRawPayloadsRequest)
    )
    return try await underlyingClient.PublicApiService_SignRawPayloads(input)
  }
  public func publicApiService_SignTransaction() async throws
    -> Operations.PublicApiService_SignTransaction.Output
  {

    // Create the PublicApiService_SignTransactionRequest
    let publicApiService_SignTransactionRequest = Components.Schemas
      .PublicApiService_SignTransactionRequest()

    let input = Operations.PublicApiService_SignTransaction.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_SignTransactionRequest)
    )
    return try await underlyingClient.PublicApiService_SignTransaction(input)
  }
  public func publicApiService_UpdatePolicy() async throws
    -> Operations.PublicApiService_UpdatePolicy.Output
  {

    // Create the PublicApiService_UpdatePolicyRequest
    let publicApiService_UpdatePolicyRequest = Components.Schemas
      .PublicApiService_UpdatePolicyRequest()

    let input = Operations.PublicApiService_UpdatePolicy.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_UpdatePolicyRequest)
    )
    return try await underlyingClient.PublicApiService_UpdatePolicy(input)
  }
  public func publicApiService_UpdatePrivateKeyTag() async throws
    -> Operations.PublicApiService_UpdatePrivateKeyTag.Output
  {

    // Create the PublicApiService_UpdatePrivateKeyTagRequest
    let publicApiService_UpdatePrivateKeyTagRequest = Components.Schemas
      .PublicApiService_UpdatePrivateKeyTagRequest()

    let input = Operations.PublicApiService_UpdatePrivateKeyTag.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_UpdatePrivateKeyTagRequest)
    )
    return try await underlyingClient.PublicApiService_UpdatePrivateKeyTag(input)
  }
  public func publicApiService_UpdateRootQuorum() async throws
    -> Operations.PublicApiService_UpdateRootQuorum.Output
  {

    // Create the PublicApiService_UpdateRootQuorumRequest
    let publicApiService_UpdateRootQuorumRequest = Components.Schemas
      .PublicApiService_UpdateRootQuorumRequest()

    let input = Operations.PublicApiService_UpdateRootQuorum.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_UpdateRootQuorumRequest)
    )
    return try await underlyingClient.PublicApiService_UpdateRootQuorum(input)
  }
  public func publicApiService_UpdateUser() async throws
    -> Operations.PublicApiService_UpdateUser.Output
  {

    // Create the PublicApiService_UpdateUserRequest
    let publicApiService_UpdateUserRequest = Components.Schemas.PublicApiService_UpdateUserRequest()

    let input = Operations.PublicApiService_UpdateUser.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_UpdateUserRequest)
    )
    return try await underlyingClient.PublicApiService_UpdateUser(input)
  }
  public func publicApiService_UpdateUserTag() async throws
    -> Operations.PublicApiService_UpdateUserTag.Output
  {

    // Create the PublicApiService_UpdateUserTagRequest
    let publicApiService_UpdateUserTagRequest = Components.Schemas
      .PublicApiService_UpdateUserTagRequest()

    let input = Operations.PublicApiService_UpdateUserTag.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_UpdateUserTagRequest)
    )
    return try await underlyingClient.PublicApiService_UpdateUserTag(input)
  }
  public func publicApiService_NOOPCodegenAnchor() async throws
    -> Operations.PublicApiService_NOOPCodegenAnchor.Output
  {

    // Create the PublicApiService_NOOPCodegenAnchorRequest
    let publicApiService_NOOPCodegenAnchorRequest = Components.Schemas
      .PublicApiService_NOOPCodegenAnchorRequest()

    let input = Operations.PublicApiService_NOOPCodegenAnchor.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(publicApiService_NOOPCodegenAnchorRequest)
    )
    return try await underlyingClient.PublicApiService_NOOPCodegenAnchor(input)
  }
}
