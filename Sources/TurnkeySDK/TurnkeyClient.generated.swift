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

  public func getActivity(organizationId: String, activityId: String) async throws
    -> Operations.GetActivity.Output
  {

    // Create the GetActivityRequest
    let getActivityRequest = Components.Schemas.GetActivityRequest(
      organizationId: organizationId, activityId: activityId
    )

    let input = Operations.GetActivity.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getActivityRequest)
    )
    return try await underlyingClient.GetActivity(input)
  }
  public func getApiKey(organizationId: String, apiKeyId: String) async throws
    -> Operations.GetApiKey.Output
  {

    // Create the GetApiKeyRequest
    let getApiKeyRequest = Components.Schemas.GetApiKeyRequest(
      organizationId: organizationId, apiKeyId: apiKeyId
    )

    let input = Operations.GetApiKey.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getApiKeyRequest)
    )
    return try await underlyingClient.GetApiKey(input)
  }
  public func getApiKeys(organizationId: String, userId: String?) async throws
    -> Operations.GetApiKeys.Output
  {

    // Create the GetApiKeysRequest
    let getApiKeysRequest = Components.Schemas.GetApiKeysRequest(
      organizationId: organizationId, userId: userId
    )

    let input = Operations.GetApiKeys.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getApiKeysRequest)
    )
    return try await underlyingClient.GetApiKeys(input)
  }
  public func getAuthenticator(organizationId: String, authenticatorId: String) async throws
    -> Operations.GetAuthenticator.Output
  {

    // Create the GetAuthenticatorRequest
    let getAuthenticatorRequest = Components.Schemas.GetAuthenticatorRequest(
      organizationId: organizationId, authenticatorId: authenticatorId
    )

    let input = Operations.GetAuthenticator.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getAuthenticatorRequest)
    )
    return try await underlyingClient.GetAuthenticator(input)
  }
  public func getAuthenticators(organizationId: String, userId: String) async throws
    -> Operations.GetAuthenticators.Output
  {

    // Create the GetAuthenticatorsRequest
    let getAuthenticatorsRequest = Components.Schemas.GetAuthenticatorsRequest(
      organizationId: organizationId, userId: userId
    )

    let input = Operations.GetAuthenticators.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getAuthenticatorsRequest)
    )
    return try await underlyingClient.GetAuthenticators(input)
  }
  public func getOauthProviders(organizationId: String, userId: String?) async throws
    -> Operations.GetOauthProviders.Output
  {

    // Create the GetOauthProvidersRequest
    let getOauthProvidersRequest = Components.Schemas.GetOauthProvidersRequest(
      organizationId: organizationId, userId: userId
    )

    let input = Operations.GetOauthProviders.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getOauthProvidersRequest)
    )
    return try await underlyingClient.GetOauthProviders(input)
  }
  public func getOrganizationConfigs(organizationId: String) async throws
    -> Operations.GetOrganizationConfigs.Output
  {

    // Create the GetOrganizationConfigsRequest
    let getOrganizationConfigsRequest = Components.Schemas.GetOrganizationConfigsRequest(
      organizationId: organizationId
    )

    let input = Operations.GetOrganizationConfigs.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getOrganizationConfigsRequest)
    )
    return try await underlyingClient.GetOrganizationConfigs(input)
  }
  public func getPolicy(organizationId: String, policyId: String) async throws
    -> Operations.GetPolicy.Output
  {

    // Create the GetPolicyRequest
    let getPolicyRequest = Components.Schemas.GetPolicyRequest(
      organizationId: organizationId, policyId: policyId
    )

    let input = Operations.GetPolicy.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getPolicyRequest)
    )
    return try await underlyingClient.GetPolicy(input)
  }
  public func getPrivateKey(organizationId: String, privateKeyId: String) async throws
    -> Operations.GetPrivateKey.Output
  {

    // Create the GetPrivateKeyRequest
    let getPrivateKeyRequest = Components.Schemas.GetPrivateKeyRequest(
      organizationId: organizationId, privateKeyId: privateKeyId
    )

    let input = Operations.GetPrivateKey.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getPrivateKeyRequest)
    )
    return try await underlyingClient.GetPrivateKey(input)
  }
  public func getUser(organizationId: String, userId: String) async throws
    -> Operations.GetUser.Output
  {

    // Create the GetUserRequest
    let getUserRequest = Components.Schemas.GetUserRequest(
      organizationId: organizationId, userId: userId
    )

    let input = Operations.GetUser.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getUserRequest)
    )
    return try await underlyingClient.GetUser(input)
  }
  public func getWallet(organizationId: String, walletId: String) async throws
    -> Operations.GetWallet.Output
  {

    // Create the GetWalletRequest
    let getWalletRequest = Components.Schemas.GetWalletRequest(
      organizationId: organizationId, walletId: walletId
    )

    let input = Operations.GetWallet.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getWalletRequest)
    )
    return try await underlyingClient.GetWallet(input)
  }
  public func getActivities(
    organizationId: String, filterByStatus: [Components.Schemas.ActivityStatus]?,
    paginationOptions: Components.Schemas.Pagination?,
    filterByType: [Components.Schemas.ActivityType]?
  ) async throws -> Operations.GetActivities.Output {

    // Create the GetActivitiesRequest
    let getActivitiesRequest = Components.Schemas.GetActivitiesRequest(
      organizationId: organizationId, filterByStatus: filterByStatus,
      paginationOptions: paginationOptions, filterByType: filterByType
    )

    let input = Operations.GetActivities.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getActivitiesRequest)
    )
    return try await underlyingClient.GetActivities(input)
  }
  public func getPolicies(organizationId: String) async throws -> Operations.GetPolicies.Output {

    // Create the GetPoliciesRequest
    let getPoliciesRequest = Components.Schemas.GetPoliciesRequest(
      organizationId: organizationId
    )

    let input = Operations.GetPolicies.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getPoliciesRequest)
    )
    return try await underlyingClient.GetPolicies(input)
  }
  public func listPrivateKeyTags(organizationId: String) async throws
    -> Operations.ListPrivateKeyTags.Output
  {

    // Create the ListPrivateKeyTagsRequest
    let listPrivateKeyTagsRequest = Components.Schemas.ListPrivateKeyTagsRequest(
      organizationId: organizationId
    )

    let input = Operations.ListPrivateKeyTags.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(listPrivateKeyTagsRequest)
    )
    return try await underlyingClient.ListPrivateKeyTags(input)
  }
  public func getPrivateKeys(organizationId: String) async throws
    -> Operations.GetPrivateKeys.Output
  {

    // Create the GetPrivateKeysRequest
    let getPrivateKeysRequest = Components.Schemas.GetPrivateKeysRequest(
      organizationId: organizationId
    )

    let input = Operations.GetPrivateKeys.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getPrivateKeysRequest)
    )
    return try await underlyingClient.GetPrivateKeys(input)
  }
  public func getSubOrgIds(
    organizationId: String, filterType: String?, filterValue: String?,
    paginationOptions: Components.Schemas.Pagination?
  ) async throws -> Operations.GetSubOrgIds.Output {

    // Create the GetSubOrgIdsRequest
    let getSubOrgIdsRequest = Components.Schemas.GetSubOrgIdsRequest(
      organizationId: organizationId, filterType: filterType, filterValue: filterValue,
      paginationOptions: paginationOptions
    )

    let input = Operations.GetSubOrgIds.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getSubOrgIdsRequest)
    )
    return try await underlyingClient.GetSubOrgIds(input)
  }
  public func listUserTags(organizationId: String) async throws -> Operations.ListUserTags.Output {

    // Create the ListUserTagsRequest
    let listUserTagsRequest = Components.Schemas.ListUserTagsRequest(
      organizationId: organizationId
    )

    let input = Operations.ListUserTags.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(listUserTagsRequest)
    )
    return try await underlyingClient.ListUserTags(input)
  }
  public func getUsers(organizationId: String) async throws -> Operations.GetUsers.Output {

    // Create the GetUsersRequest
    let getUsersRequest = Components.Schemas.GetUsersRequest(
      organizationId: organizationId
    )

    let input = Operations.GetUsers.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getUsersRequest)
    )
    return try await underlyingClient.GetUsers(input)
  }
  public func getWalletAccounts(
    organizationId: String, walletId: String, paginationOptions: Components.Schemas.Pagination?
  ) async throws -> Operations.GetWalletAccounts.Output {

    // Create the GetWalletAccountsRequest
    let getWalletAccountsRequest = Components.Schemas.GetWalletAccountsRequest(
      organizationId: organizationId, walletId: walletId, paginationOptions: paginationOptions
    )

    let input = Operations.GetWalletAccounts.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getWalletAccountsRequest)
    )
    return try await underlyingClient.GetWalletAccounts(input)
  }
  public func getWallets(organizationId: String) async throws -> Operations.GetWallets.Output {

    // Create the GetWalletsRequest
    let getWalletsRequest = Components.Schemas.GetWalletsRequest(
      organizationId: organizationId
    )

    let input = Operations.GetWallets.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getWalletsRequest)
    )
    return try await underlyingClient.GetWallets(input)
  }
  public func getWhoami(organizationId: String) async throws -> Operations.GetWhoami.Output {

    // Create the GetWhoamiRequest
    let getWhoamiRequest = Components.Schemas.GetWhoamiRequest(
      organizationId: organizationId
    )

    let input = Operations.GetWhoami.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getWhoamiRequest)
    )
    return try await underlyingClient.GetWhoami(input)
  }

  public func approveActivity(
    organizationId: String,
    fingerprint: String
  ) async throws -> Operations.ApproveActivity.Output {

    // Create the ApproveActivityIntent
    let approveActivityIntent = Components.Schemas.ApproveActivityIntent(
      fingerprint: fingerprint)

    // Create the ApproveActivityRequest
    let approveActivityRequest = Components.Schemas.ApproveActivityRequest(
      _type: .ACTIVITY_TYPE_APPROVE_ACTIVITY,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: approveActivityIntent
    )

    // Create the input for the ApproveActivity method
    let input = Operations.ApproveActivity.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(approveActivityRequest)
    )

    // Call the ApproveActivity method using the underlyingClient
    return try await underlyingClient.ApproveActivity(input)
  }

  public func createApiKeys(
    organizationId: String,
    apiKeys: [Components.Schemas.ApiKeyParamsV2], userId: String
  ) async throws -> Operations.CreateApiKeys.Output {

    // Create the CreateApiKeysIntentV2
    let createApiKeysIntent = Components.Schemas.CreateApiKeysIntentV2(
      apiKeys: apiKeys, userId: userId)

    // Create the CreateApiKeysRequest
    let createApiKeysRequest = Components.Schemas.CreateApiKeysRequest(
      _type: .ACTIVITY_TYPE_CREATE_API_KEYS_V2,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: createApiKeysIntent
    )

    // Create the input for the CreateApiKeys method
    let input = Operations.CreateApiKeys.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(createApiKeysRequest)
    )

    // Call the CreateApiKeys method using the underlyingClient
    return try await underlyingClient.CreateApiKeys(input)
  }

  public func createAuthenticators(
    organizationId: String,
    authenticators: [Components.Schemas.AuthenticatorParamsV2], userId: String
  ) async throws -> Operations.CreateAuthenticators.Output {

    // Create the CreateAuthenticatorsIntentV2
    let createAuthenticatorsIntent = Components.Schemas.CreateAuthenticatorsIntentV2(
      authenticators: authenticators, userId: userId)

    // Create the CreateAuthenticatorsRequest
    let createAuthenticatorsRequest = Components.Schemas.CreateAuthenticatorsRequest(
      _type: .ACTIVITY_TYPE_CREATE_AUTHENTICATORS_V2,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: createAuthenticatorsIntent
    )

    // Create the input for the CreateAuthenticators method
    let input = Operations.CreateAuthenticators.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(createAuthenticatorsRequest)
    )

    // Call the CreateAuthenticators method using the underlyingClient
    return try await underlyingClient.CreateAuthenticators(input)
  }

  public func createInvitations(
    organizationId: String,
    invitations: [Components.Schemas.InvitationParams]
  ) async throws -> Operations.CreateInvitations.Output {

    // Create the CreateInvitationsIntent
    let createInvitationsIntent = Components.Schemas.CreateInvitationsIntent(
      invitations: invitations)

    // Create the CreateInvitationsRequest
    let createInvitationsRequest = Components.Schemas.CreateInvitationsRequest(
      _type: .ACTIVITY_TYPE_CREATE_INVITATIONS,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: createInvitationsIntent
    )

    // Create the input for the CreateInvitations method
    let input = Operations.CreateInvitations.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(createInvitationsRequest)
    )

    // Call the CreateInvitations method using the underlyingClient
    return try await underlyingClient.CreateInvitations(input)
  }

  public func createOauthProviders(
    organizationId: String,
    userId: String, oauthProviders: [Components.Schemas.OauthProviderParams]
  ) async throws -> Operations.CreateOauthProviders.Output {

    // Create the CreateOauthProvidersIntent
    let createOauthProvidersIntent = Components.Schemas.CreateOauthProvidersIntent(
      userId: userId, oauthProviders: oauthProviders)

    // Create the CreateOauthProvidersRequest
    let createOauthProvidersRequest = Components.Schemas.CreateOauthProvidersRequest(
      _type: .ACTIVITY_TYPE_CREATE_OAUTH_PROVIDERS,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: createOauthProvidersIntent
    )

    // Create the input for the CreateOauthProviders method
    let input = Operations.CreateOauthProviders.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(createOauthProvidersRequest)
    )

    // Call the CreateOauthProviders method using the underlyingClient
    return try await underlyingClient.CreateOauthProviders(input)
  }

  public func createPolicies(
    organizationId: String,
    policies: [Components.Schemas.CreatePolicyIntentV3]
  ) async throws -> Operations.CreatePolicies.Output {

    // Create the CreatePoliciesIntent
    let createPoliciesIntent = Components.Schemas.CreatePoliciesIntent(
      policies: policies)

    // Create the CreatePoliciesRequest
    let createPoliciesRequest = Components.Schemas.CreatePoliciesRequest(
      _type: .ACTIVITY_TYPE_CREATE_POLICIES,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: createPoliciesIntent
    )

    // Create the input for the CreatePolicies method
    let input = Operations.CreatePolicies.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(createPoliciesRequest)
    )

    // Call the CreatePolicies method using the underlyingClient
    return try await underlyingClient.CreatePolicies(input)
  }

  public func createPolicy(
    organizationId: String,
    policyName: String, effect: Components.Schemas.Effect, condition: String?, consensus: String?,
    notes: String?
  ) async throws -> Operations.CreatePolicy.Output {

    // Create the CreatePolicyIntentV3
    let createPolicyIntent = Components.Schemas.CreatePolicyIntentV3(
      policyName: policyName, effect: effect, condition: condition, consensus: consensus,
      notes: notes)

    // Create the CreatePolicyRequest
    let createPolicyRequest = Components.Schemas.CreatePolicyRequest(
      _type: .ACTIVITY_TYPE_CREATE_POLICY_V3,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: createPolicyIntent
    )

    // Create the input for the CreatePolicy method
    let input = Operations.CreatePolicy.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(createPolicyRequest)
    )

    // Call the CreatePolicy method using the underlyingClient
    return try await underlyingClient.CreatePolicy(input)
  }

  public func createPrivateKeyTag(
    organizationId: String,
    privateKeyTagName: String, privateKeyIds: [String]
  ) async throws -> Operations.CreatePrivateKeyTag.Output {

    // Create the CreatePrivateKeyTagIntent
    let createPrivateKeyTagIntent = Components.Schemas.CreatePrivateKeyTagIntent(
      privateKeyTagName: privateKeyTagName, privateKeyIds: privateKeyIds)

    // Create the CreatePrivateKeyTagRequest
    let createPrivateKeyTagRequest = Components.Schemas.CreatePrivateKeyTagRequest(
      _type: .ACTIVITY_TYPE_CREATE_PRIVATE_KEY_TAG,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: createPrivateKeyTagIntent
    )

    // Create the input for the CreatePrivateKeyTag method
    let input = Operations.CreatePrivateKeyTag.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(createPrivateKeyTagRequest)
    )

    // Call the CreatePrivateKeyTag method using the underlyingClient
    return try await underlyingClient.CreatePrivateKeyTag(input)
  }

  public func createPrivateKeys(
    organizationId: String,
    privateKeys: [Components.Schemas.PrivateKeyParams]
  ) async throws -> Operations.CreatePrivateKeys.Output {

    // Create the CreatePrivateKeysIntentV2
    let createPrivateKeysIntent = Components.Schemas.CreatePrivateKeysIntentV2(
      privateKeys: privateKeys)

    // Create the CreatePrivateKeysRequest
    let createPrivateKeysRequest = Components.Schemas.CreatePrivateKeysRequest(
      _type: .ACTIVITY_TYPE_CREATE_PRIVATE_KEYS_V2,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: createPrivateKeysIntent
    )

    // Create the input for the CreatePrivateKeys method
    let input = Operations.CreatePrivateKeys.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(createPrivateKeysRequest)
    )

    // Call the CreatePrivateKeys method using the underlyingClient
    return try await underlyingClient.CreatePrivateKeys(input)
  }

  public func createReadOnlySession(
    organizationId: String,
  ) async throws -> Operations.CreateReadOnlySession.Output {

    // Create the CreateReadOnlySessionIntent
    let createReadOnlySessionIntent = Components.Schemas.CreateReadOnlySessionIntent()

    // Create the CreateReadOnlySessionRequest
    let createReadOnlySessionRequest = Components.Schemas.CreateReadOnlySessionRequest(
      _type: .ACTIVITY_TYPE_CREATE_READ_ONLY_SESSION,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: createReadOnlySessionIntent
    )

    // Create the input for the CreateReadOnlySession method
    let input = Operations.CreateReadOnlySession.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(createReadOnlySessionRequest)
    )

    // Call the CreateReadOnlySession method using the underlyingClient
    return try await underlyingClient.CreateReadOnlySession(input)
  }

  public func createReadWriteSession(
    organizationId: String,
    targetPublicKey: String, userId: String?, apiKeyName: String?, expirationSeconds: String?
  ) async throws -> Operations.CreateReadWriteSession.Output {

    // Create the CreateReadWriteSessionIntentV2
    let createReadWriteSessionIntent = Components.Schemas.CreateReadWriteSessionIntentV2(
      targetPublicKey: targetPublicKey, userId: userId, apiKeyName: apiKeyName,
      expirationSeconds: expirationSeconds)

    // Create the CreateReadWriteSessionRequest
    let createReadWriteSessionRequest = Components.Schemas.CreateReadWriteSessionRequest(
      _type: .ACTIVITY_TYPE_CREATE_READ_WRITE_SESSION_V2,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: createReadWriteSessionIntent
    )

    // Create the input for the CreateReadWriteSession method
    let input = Operations.CreateReadWriteSession.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(createReadWriteSessionRequest)
    )

    // Call the CreateReadWriteSession method using the underlyingClient
    return try await underlyingClient.CreateReadWriteSession(input)
  }

  public func createSubOrganization(
    organizationId: String,
    subOrganizationName: String, rootUsers: [Components.Schemas.RootUserParamsV4],
    rootQuorumThreshold: Int32, wallet: Components.Schemas.WalletParams?,
    disableEmailRecovery: Bool?, disableEmailAuth: Bool?, disableSmsAuth: Bool?,
    disableOtpEmailAuth: Bool?
  ) async throws -> Operations.CreateSubOrganization.Output {

    // Create the CreateSubOrganizationIntentV7
    let createSubOrganizationIntent = Components.Schemas.CreateSubOrganizationIntentV7(
      subOrganizationName: subOrganizationName, rootUsers: rootUsers,
      rootQuorumThreshold: rootQuorumThreshold, wallet: wallet,
      disableEmailRecovery: disableEmailRecovery, disableEmailAuth: disableEmailAuth,
      disableSmsAuth: disableSmsAuth, disableOtpEmailAuth: disableOtpEmailAuth)

    // Create the CreateSubOrganizationRequest
    let createSubOrganizationRequest = Components.Schemas.CreateSubOrganizationRequest(
      _type: .ACTIVITY_TYPE_CREATE_SUB_ORGANIZATION_V7,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: createSubOrganizationIntent
    )

    // Create the input for the CreateSubOrganization method
    let input = Operations.CreateSubOrganization.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(createSubOrganizationRequest)
    )

    // Call the CreateSubOrganization method using the underlyingClient
    return try await underlyingClient.CreateSubOrganization(input)
  }

  public func createUserTag(
    organizationId: String,
    userTagName: String, userIds: [String]
  ) async throws -> Operations.CreateUserTag.Output {

    // Create the CreateUserTagIntent
    let createUserTagIntent = Components.Schemas.CreateUserTagIntent(
      userTagName: userTagName, userIds: userIds)

    // Create the CreateUserTagRequest
    let createUserTagRequest = Components.Schemas.CreateUserTagRequest(
      _type: .ACTIVITY_TYPE_CREATE_USER_TAG,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: createUserTagIntent
    )

    // Create the input for the CreateUserTag method
    let input = Operations.CreateUserTag.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(createUserTagRequest)
    )

    // Call the CreateUserTag method using the underlyingClient
    return try await underlyingClient.CreateUserTag(input)
  }

  public func createUsers(
    organizationId: String,
    users: [Components.Schemas.UserParamsV2]
  ) async throws -> Operations.CreateUsers.Output {

    // Create the CreateUsersIntentV2
    let createUsersIntent = Components.Schemas.CreateUsersIntentV2(
      users: users)

    // Create the CreateUsersRequest
    let createUsersRequest = Components.Schemas.CreateUsersRequest(
      _type: .ACTIVITY_TYPE_CREATE_USERS_V2,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: createUsersIntent
    )

    // Create the input for the CreateUsers method
    let input = Operations.CreateUsers.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(createUsersRequest)
    )

    // Call the CreateUsers method using the underlyingClient
    return try await underlyingClient.CreateUsers(input)
  }

  public func createWallet(
    organizationId: String,
    walletName: String, accounts: [Components.Schemas.WalletAccountParams], mnemonicLength: Int32?
  ) async throws -> Operations.CreateWallet.Output {

    // Create the CreateWalletIntent
    let createWalletIntent = Components.Schemas.CreateWalletIntent(
      walletName: walletName, accounts: accounts, mnemonicLength: mnemonicLength)

    // Create the CreateWalletRequest
    let createWalletRequest = Components.Schemas.CreateWalletRequest(
      _type: .ACTIVITY_TYPE_CREATE_WALLET,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: createWalletIntent
    )

    // Create the input for the CreateWallet method
    let input = Operations.CreateWallet.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(createWalletRequest)
    )

    // Call the CreateWallet method using the underlyingClient
    return try await underlyingClient.CreateWallet(input)
  }

  public func createWalletAccounts(
    organizationId: String,
    walletId: String, accounts: [Components.Schemas.WalletAccountParams]
  ) async throws -> Operations.CreateWalletAccounts.Output {

    // Create the CreateWalletAccountsIntent
    let createWalletAccountsIntent = Components.Schemas.CreateWalletAccountsIntent(
      walletId: walletId, accounts: accounts)

    // Create the CreateWalletAccountsRequest
    let createWalletAccountsRequest = Components.Schemas.CreateWalletAccountsRequest(
      _type: .ACTIVITY_TYPE_CREATE_WALLET_ACCOUNTS,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: createWalletAccountsIntent
    )

    // Create the input for the CreateWalletAccounts method
    let input = Operations.CreateWalletAccounts.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(createWalletAccountsRequest)
    )

    // Call the CreateWalletAccounts method using the underlyingClient
    return try await underlyingClient.CreateWalletAccounts(input)
  }

  public func deleteApiKeys(
    organizationId: String,
    userId: String, apiKeyIds: [String]
  ) async throws -> Operations.DeleteApiKeys.Output {

    // Create the DeleteApiKeysIntent
    let deleteApiKeysIntent = Components.Schemas.DeleteApiKeysIntent(
      userId: userId, apiKeyIds: apiKeyIds)

    // Create the DeleteApiKeysRequest
    let deleteApiKeysRequest = Components.Schemas.DeleteApiKeysRequest(
      _type: .ACTIVITY_TYPE_DELETE_API_KEYS,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: deleteApiKeysIntent
    )

    // Create the input for the DeleteApiKeys method
    let input = Operations.DeleteApiKeys.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(deleteApiKeysRequest)
    )

    // Call the DeleteApiKeys method using the underlyingClient
    return try await underlyingClient.DeleteApiKeys(input)
  }

  public func deleteAuthenticators(
    organizationId: String,
    userId: String, authenticatorIds: [String]
  ) async throws -> Operations.DeleteAuthenticators.Output {

    // Create the DeleteAuthenticatorsIntent
    let deleteAuthenticatorsIntent = Components.Schemas.DeleteAuthenticatorsIntent(
      userId: userId, authenticatorIds: authenticatorIds)

    // Create the DeleteAuthenticatorsRequest
    let deleteAuthenticatorsRequest = Components.Schemas.DeleteAuthenticatorsRequest(
      _type: .ACTIVITY_TYPE_DELETE_AUTHENTICATORS,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: deleteAuthenticatorsIntent
    )

    // Create the input for the DeleteAuthenticators method
    let input = Operations.DeleteAuthenticators.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(deleteAuthenticatorsRequest)
    )

    // Call the DeleteAuthenticators method using the underlyingClient
    return try await underlyingClient.DeleteAuthenticators(input)
  }

  public func deleteInvitation(
    organizationId: String,
    invitationId: String
  ) async throws -> Operations.DeleteInvitation.Output {

    // Create the DeleteInvitationIntent
    let deleteInvitationIntent = Components.Schemas.DeleteInvitationIntent(
      invitationId: invitationId)

    // Create the DeleteInvitationRequest
    let deleteInvitationRequest = Components.Schemas.DeleteInvitationRequest(
      _type: .ACTIVITY_TYPE_DELETE_INVITATION,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: deleteInvitationIntent
    )

    // Create the input for the DeleteInvitation method
    let input = Operations.DeleteInvitation.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(deleteInvitationRequest)
    )

    // Call the DeleteInvitation method using the underlyingClient
    return try await underlyingClient.DeleteInvitation(input)
  }

  public func deleteOauthProviders(
    organizationId: String,
    userId: String, providerIds: [String]
  ) async throws -> Operations.DeleteOauthProviders.Output {

    // Create the DeleteOauthProvidersIntent
    let deleteOauthProvidersIntent = Components.Schemas.DeleteOauthProvidersIntent(
      userId: userId, providerIds: providerIds)

    // Create the DeleteOauthProvidersRequest
    let deleteOauthProvidersRequest = Components.Schemas.DeleteOauthProvidersRequest(
      _type: .ACTIVITY_TYPE_DELETE_OAUTH_PROVIDERS,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: deleteOauthProvidersIntent
    )

    // Create the input for the DeleteOauthProviders method
    let input = Operations.DeleteOauthProviders.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(deleteOauthProvidersRequest)
    )

    // Call the DeleteOauthProviders method using the underlyingClient
    return try await underlyingClient.DeleteOauthProviders(input)
  }

  public func deletePolicy(
    organizationId: String,
    policyId: String
  ) async throws -> Operations.DeletePolicy.Output {

    // Create the DeletePolicyIntent
    let deletePolicyIntent = Components.Schemas.DeletePolicyIntent(
      policyId: policyId)

    // Create the DeletePolicyRequest
    let deletePolicyRequest = Components.Schemas.DeletePolicyRequest(
      _type: .ACTIVITY_TYPE_DELETE_POLICY,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: deletePolicyIntent
    )

    // Create the input for the DeletePolicy method
    let input = Operations.DeletePolicy.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(deletePolicyRequest)
    )

    // Call the DeletePolicy method using the underlyingClient
    return try await underlyingClient.DeletePolicy(input)
  }

  public func deletePrivateKeyTags(
    organizationId: String,
    privateKeyTagIds: [String]
  ) async throws -> Operations.DeletePrivateKeyTags.Output {

    // Create the DeletePrivateKeyTagsIntent
    let deletePrivateKeyTagsIntent = Components.Schemas.DeletePrivateKeyTagsIntent(
      privateKeyTagIds: privateKeyTagIds)

    // Create the DeletePrivateKeyTagsRequest
    let deletePrivateKeyTagsRequest = Components.Schemas.DeletePrivateKeyTagsRequest(
      _type: .ACTIVITY_TYPE_DELETE_PRIVATE_KEY_TAGS,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: deletePrivateKeyTagsIntent
    )

    // Create the input for the DeletePrivateKeyTags method
    let input = Operations.DeletePrivateKeyTags.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(deletePrivateKeyTagsRequest)
    )

    // Call the DeletePrivateKeyTags method using the underlyingClient
    return try await underlyingClient.DeletePrivateKeyTags(input)
  }

  public func deletePrivateKeys(
    organizationId: String,
    privateKeyIds: [String], deleteWithoutExport: Bool?
  ) async throws -> Operations.DeletePrivateKeys.Output {

    // Create the DeletePrivateKeysIntent
    let deletePrivateKeysIntent = Components.Schemas.DeletePrivateKeysIntent(
      privateKeyIds: privateKeyIds, deleteWithoutExport: deleteWithoutExport)

    // Create the DeletePrivateKeysRequest
    let deletePrivateKeysRequest = Components.Schemas.DeletePrivateKeysRequest(
      _type: .ACTIVITY_TYPE_DELETE_PRIVATE_KEYS,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: deletePrivateKeysIntent
    )

    // Create the input for the DeletePrivateKeys method
    let input = Operations.DeletePrivateKeys.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(deletePrivateKeysRequest)
    )

    // Call the DeletePrivateKeys method using the underlyingClient
    return try await underlyingClient.DeletePrivateKeys(input)
  }

  public func deleteSubOrganization(
    organizationId: String,
    deleteWithoutExport: Bool?
  ) async throws -> Operations.DeleteSubOrganization.Output {

    // Create the DeleteSubOrganizationIntent
    let deleteSubOrganizationIntent = Components.Schemas.DeleteSubOrganizationIntent(
      deleteWithoutExport: deleteWithoutExport)

    // Create the DeleteSubOrganizationRequest
    let deleteSubOrganizationRequest = Components.Schemas.DeleteSubOrganizationRequest(
      _type: .ACTIVITY_TYPE_DELETE_SUB_ORGANIZATION,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: deleteSubOrganizationIntent
    )

    // Create the input for the DeleteSubOrganization method
    let input = Operations.DeleteSubOrganization.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(deleteSubOrganizationRequest)
    )

    // Call the DeleteSubOrganization method using the underlyingClient
    return try await underlyingClient.DeleteSubOrganization(input)
  }

  public func deleteUserTags(
    organizationId: String,
    userTagIds: [String]
  ) async throws -> Operations.DeleteUserTags.Output {

    // Create the DeleteUserTagsIntent
    let deleteUserTagsIntent = Components.Schemas.DeleteUserTagsIntent(
      userTagIds: userTagIds)

    // Create the DeleteUserTagsRequest
    let deleteUserTagsRequest = Components.Schemas.DeleteUserTagsRequest(
      _type: .ACTIVITY_TYPE_DELETE_USER_TAGS,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: deleteUserTagsIntent
    )

    // Create the input for the DeleteUserTags method
    let input = Operations.DeleteUserTags.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(deleteUserTagsRequest)
    )

    // Call the DeleteUserTags method using the underlyingClient
    return try await underlyingClient.DeleteUserTags(input)
  }

  public func deleteUsers(
    organizationId: String,
    userIds: [String]
  ) async throws -> Operations.DeleteUsers.Output {

    // Create the DeleteUsersIntent
    let deleteUsersIntent = Components.Schemas.DeleteUsersIntent(
      userIds: userIds)

    // Create the DeleteUsersRequest
    let deleteUsersRequest = Components.Schemas.DeleteUsersRequest(
      _type: .ACTIVITY_TYPE_DELETE_USERS,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: deleteUsersIntent
    )

    // Create the input for the DeleteUsers method
    let input = Operations.DeleteUsers.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(deleteUsersRequest)
    )

    // Call the DeleteUsers method using the underlyingClient
    return try await underlyingClient.DeleteUsers(input)
  }

  public func deleteWallets(
    organizationId: String,
    walletIds: [String], deleteWithoutExport: Bool?
  ) async throws -> Operations.DeleteWallets.Output {

    // Create the DeleteWalletsIntent
    let deleteWalletsIntent = Components.Schemas.DeleteWalletsIntent(
      walletIds: walletIds, deleteWithoutExport: deleteWithoutExport)

    // Create the DeleteWalletsRequest
    let deleteWalletsRequest = Components.Schemas.DeleteWalletsRequest(
      _type: .ACTIVITY_TYPE_DELETE_WALLETS,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: deleteWalletsIntent
    )

    // Create the input for the DeleteWallets method
    let input = Operations.DeleteWallets.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(deleteWalletsRequest)
    )

    // Call the DeleteWallets method using the underlyingClient
    return try await underlyingClient.DeleteWallets(input)
  }

  public func emailAuth(
    organizationId: String,
    email: String, targetPublicKey: String, apiKeyName: String?, expirationSeconds: String?,
    emailCustomization: Components.Schemas.EmailCustomizationParams?, invalidateExisting: Bool?
  ) async throws -> Operations.EmailAuth.Output {

    // Create the EmailAuthIntentV2
    let emailAuthIntent = Components.Schemas.EmailAuthIntentV2(
      email: email, targetPublicKey: targetPublicKey, apiKeyName: apiKeyName,
      expirationSeconds: expirationSeconds, emailCustomization: emailCustomization,
      invalidateExisting: invalidateExisting)

    // Create the EmailAuthRequest
    let emailAuthRequest = Components.Schemas.EmailAuthRequest(
      _type: .ACTIVITY_TYPE_EMAIL_AUTH_V2,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: emailAuthIntent
    )

    // Create the input for the EmailAuth method
    let input = Operations.EmailAuth.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(emailAuthRequest)
    )

    // Call the EmailAuth method using the underlyingClient
    return try await underlyingClient.EmailAuth(input)
  }

  public func exportPrivateKey(
    organizationId: String,
    privateKeyId: String, targetPublicKey: String
  ) async throws -> Operations.ExportPrivateKey.Output {

    // Create the ExportPrivateKeyIntent
    let exportPrivateKeyIntent = Components.Schemas.ExportPrivateKeyIntent(
      privateKeyId: privateKeyId, targetPublicKey: targetPublicKey)

    // Create the ExportPrivateKeyRequest
    let exportPrivateKeyRequest = Components.Schemas.ExportPrivateKeyRequest(
      _type: .ACTIVITY_TYPE_EXPORT_PRIVATE_KEY,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: exportPrivateKeyIntent
    )

    // Create the input for the ExportPrivateKey method
    let input = Operations.ExportPrivateKey.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(exportPrivateKeyRequest)
    )

    // Call the ExportPrivateKey method using the underlyingClient
    return try await underlyingClient.ExportPrivateKey(input)
  }

  public func exportWallet(
    organizationId: String,
    walletId: String, targetPublicKey: String, language: Components.Schemas.MnemonicLanguage?
  ) async throws -> Operations.ExportWallet.Output {

    // Create the ExportWalletIntent
    let exportWalletIntent = Components.Schemas.ExportWalletIntent(
      walletId: walletId, targetPublicKey: targetPublicKey, language: language)

    // Create the ExportWalletRequest
    let exportWalletRequest = Components.Schemas.ExportWalletRequest(
      _type: .ACTIVITY_TYPE_EXPORT_WALLET,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: exportWalletIntent
    )

    // Create the input for the ExportWallet method
    let input = Operations.ExportWallet.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(exportWalletRequest)
    )

    // Call the ExportWallet method using the underlyingClient
    return try await underlyingClient.ExportWallet(input)
  }

  public func exportWalletAccount(
    organizationId: String,
    address: String, targetPublicKey: String
  ) async throws -> Operations.ExportWalletAccount.Output {

    // Create the ExportWalletAccountIntent
    let exportWalletAccountIntent = Components.Schemas.ExportWalletAccountIntent(
      address: address, targetPublicKey: targetPublicKey)

    // Create the ExportWalletAccountRequest
    let exportWalletAccountRequest = Components.Schemas.ExportWalletAccountRequest(
      _type: .ACTIVITY_TYPE_EXPORT_WALLET_ACCOUNT,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: exportWalletAccountIntent
    )

    // Create the input for the ExportWalletAccount method
    let input = Operations.ExportWalletAccount.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(exportWalletAccountRequest)
    )

    // Call the ExportWalletAccount method using the underlyingClient
    return try await underlyingClient.ExportWalletAccount(input)
  }

  public func importPrivateKey(
    organizationId: String,
    userId: String, privateKeyName: String, encryptedBundle: String,
    curve: Components.Schemas.Curve, addressFormats: [Components.Schemas.AddressFormat]
  ) async throws -> Operations.ImportPrivateKey.Output {

    // Create the ImportPrivateKeyIntent
    let importPrivateKeyIntent = Components.Schemas.ImportPrivateKeyIntent(
      userId: userId, privateKeyName: privateKeyName, encryptedBundle: encryptedBundle,
      curve: curve, addressFormats: addressFormats)

    // Create the ImportPrivateKeyRequest
    let importPrivateKeyRequest = Components.Schemas.ImportPrivateKeyRequest(
      _type: .ACTIVITY_TYPE_IMPORT_PRIVATE_KEY,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: importPrivateKeyIntent
    )

    // Create the input for the ImportPrivateKey method
    let input = Operations.ImportPrivateKey.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(importPrivateKeyRequest)
    )

    // Call the ImportPrivateKey method using the underlyingClient
    return try await underlyingClient.ImportPrivateKey(input)
  }

  public func importWallet(
    organizationId: String,
    userId: String, walletName: String, encryptedBundle: String,
    accounts: [Components.Schemas.WalletAccountParams]
  ) async throws -> Operations.ImportWallet.Output {

    // Create the ImportWalletIntent
    let importWalletIntent = Components.Schemas.ImportWalletIntent(
      userId: userId, walletName: walletName, encryptedBundle: encryptedBundle, accounts: accounts)

    // Create the ImportWalletRequest
    let importWalletRequest = Components.Schemas.ImportWalletRequest(
      _type: .ACTIVITY_TYPE_IMPORT_WALLET,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: importWalletIntent
    )

    // Create the input for the ImportWallet method
    let input = Operations.ImportWallet.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(importWalletRequest)
    )

    // Call the ImportWallet method using the underlyingClient
    return try await underlyingClient.ImportWallet(input)
  }

  public func initImportPrivateKey(
    organizationId: String,
    userId: String
  ) async throws -> Operations.InitImportPrivateKey.Output {

    // Create the InitImportPrivateKeyIntent
    let initImportPrivateKeyIntent = Components.Schemas.InitImportPrivateKeyIntent(
      userId: userId)

    // Create the InitImportPrivateKeyRequest
    let initImportPrivateKeyRequest = Components.Schemas.InitImportPrivateKeyRequest(
      _type: .ACTIVITY_TYPE_INIT_IMPORT_PRIVATE_KEY,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: initImportPrivateKeyIntent
    )

    // Create the input for the InitImportPrivateKey method
    let input = Operations.InitImportPrivateKey.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(initImportPrivateKeyRequest)
    )

    // Call the InitImportPrivateKey method using the underlyingClient
    return try await underlyingClient.InitImportPrivateKey(input)
  }

  public func initImportWallet(
    organizationId: String,
    userId: String
  ) async throws -> Operations.InitImportWallet.Output {

    // Create the InitImportWalletIntent
    let initImportWalletIntent = Components.Schemas.InitImportWalletIntent(
      userId: userId)

    // Create the InitImportWalletRequest
    let initImportWalletRequest = Components.Schemas.InitImportWalletRequest(
      _type: .ACTIVITY_TYPE_INIT_IMPORT_WALLET,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: initImportWalletIntent
    )

    // Create the input for the InitImportWallet method
    let input = Operations.InitImportWallet.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(initImportWalletRequest)
    )

    // Call the InitImportWallet method using the underlyingClient
    return try await underlyingClient.InitImportWallet(input)
  }

  public func initOtpAuth(
    organizationId: String,
    otpType: String, contact: String,
    emailCustomization: Components.Schemas.EmailCustomizationParams?
  ) async throws -> Operations.InitOtpAuth.Output {

    // Create the InitOtpAuthIntent
    let initOtpAuthIntent = Components.Schemas.InitOtpAuthIntent(
      otpType: otpType, contact: contact, emailCustomization: emailCustomization)

    // Create the InitOtpAuthRequest
    let initOtpAuthRequest = Components.Schemas.InitOtpAuthRequest(
      _type: .ACTIVITY_TYPE_INIT_OTP_AUTH,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: initOtpAuthIntent
    )

    // Create the input for the InitOtpAuth method
    let input = Operations.InitOtpAuth.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(initOtpAuthRequest)
    )

    // Call the InitOtpAuth method using the underlyingClient
    return try await underlyingClient.InitOtpAuth(input)
  }

  public func initUserEmailRecovery(
    organizationId: String,
    email: String, targetPublicKey: String, expirationSeconds: String?,
    emailCustomization: Components.Schemas.EmailCustomizationParams?
  ) async throws -> Operations.InitUserEmailRecovery.Output {

    // Create the InitUserEmailRecoveryIntent
    let initUserEmailRecoveryIntent = Components.Schemas.InitUserEmailRecoveryIntent(
      email: email, targetPublicKey: targetPublicKey, expirationSeconds: expirationSeconds,
      emailCustomization: emailCustomization)

    // Create the InitUserEmailRecoveryRequest
    let initUserEmailRecoveryRequest = Components.Schemas.InitUserEmailRecoveryRequest(
      _type: .ACTIVITY_TYPE_INIT_USER_EMAIL_RECOVERY,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: initUserEmailRecoveryIntent
    )

    // Create the input for the InitUserEmailRecovery method
    let input = Operations.InitUserEmailRecovery.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(initUserEmailRecoveryRequest)
    )

    // Call the InitUserEmailRecovery method using the underlyingClient
    return try await underlyingClient.InitUserEmailRecovery(input)
  }

  public func oauth(
    organizationId: String,
    oidcToken: String, targetPublicKey: String, apiKeyName: String?, expirationSeconds: String?
  ) async throws -> Operations.Oauth.Output {

    // Create the OauthIntent
    let oauthIntent = Components.Schemas.OauthIntent(
      oidcToken: oidcToken, targetPublicKey: targetPublicKey, apiKeyName: apiKeyName,
      expirationSeconds: expirationSeconds)

    // Create the OauthRequest
    let oauthRequest = Components.Schemas.OauthRequest(
      _type: .ACTIVITY_TYPE_OAUTH,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: oauthIntent
    )

    // Create the input for the Oauth method
    let input = Operations.Oauth.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(oauthRequest)
    )

    // Call the Oauth method using the underlyingClient
    return try await underlyingClient.Oauth(input)
  }

  public func otpAuth(
    organizationId: String,
    otpId: String, otpCode: String, targetPublicKey: String?, apiKeyName: String?,
    expirationSeconds: String?, invalidateExisting: Bool?
  ) async throws -> Operations.OtpAuth.Output {

    // Create the OtpAuthIntent
    let otpAuthIntent = Components.Schemas.OtpAuthIntent(
      otpId: otpId, otpCode: otpCode, targetPublicKey: targetPublicKey, apiKeyName: apiKeyName,
      expirationSeconds: expirationSeconds, invalidateExisting: invalidateExisting)

    // Create the OtpAuthRequest
    let otpAuthRequest = Components.Schemas.OtpAuthRequest(
      _type: .ACTIVITY_TYPE_OTP_AUTH,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: otpAuthIntent
    )

    // Create the input for the OtpAuth method
    let input = Operations.OtpAuth.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(otpAuthRequest)
    )

    // Call the OtpAuth method using the underlyingClient
    return try await underlyingClient.OtpAuth(input)
  }

  public func recoverUser(
    organizationId: String,
    authenticator: Components.Schemas.AuthenticatorParamsV2, userId: String
  ) async throws -> Operations.RecoverUser.Output {

    // Create the RecoverUserIntent
    let recoverUserIntent = Components.Schemas.RecoverUserIntent(
      authenticator: authenticator, userId: userId)

    // Create the RecoverUserRequest
    let recoverUserRequest = Components.Schemas.RecoverUserRequest(
      _type: .ACTIVITY_TYPE_RECOVER_USER,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: recoverUserIntent
    )

    // Create the input for the RecoverUser method
    let input = Operations.RecoverUser.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(recoverUserRequest)
    )

    // Call the RecoverUser method using the underlyingClient
    return try await underlyingClient.RecoverUser(input)
  }

  public func rejectActivity(
    organizationId: String,
    fingerprint: String
  ) async throws -> Operations.RejectActivity.Output {

    // Create the RejectActivityIntent
    let rejectActivityIntent = Components.Schemas.RejectActivityIntent(
      fingerprint: fingerprint)

    // Create the RejectActivityRequest
    let rejectActivityRequest = Components.Schemas.RejectActivityRequest(
      _type: .ACTIVITY_TYPE_REJECT_ACTIVITY,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: rejectActivityIntent
    )

    // Create the input for the RejectActivity method
    let input = Operations.RejectActivity.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(rejectActivityRequest)
    )

    // Call the RejectActivity method using the underlyingClient
    return try await underlyingClient.RejectActivity(input)
  }

  public func removeOrganizationFeature(
    organizationId: String,
    name: Components.Schemas.FeatureName
  ) async throws -> Operations.RemoveOrganizationFeature.Output {

    // Create the RemoveOrganizationFeatureIntent
    let removeOrganizationFeatureIntent = Components.Schemas.RemoveOrganizationFeatureIntent(
      name: name)

    // Create the RemoveOrganizationFeatureRequest
    let removeOrganizationFeatureRequest = Components.Schemas.RemoveOrganizationFeatureRequest(
      _type: .ACTIVITY_TYPE_REMOVE_ORGANIZATION_FEATURE,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: removeOrganizationFeatureIntent
    )

    // Create the input for the RemoveOrganizationFeature method
    let input = Operations.RemoveOrganizationFeature.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(removeOrganizationFeatureRequest)
    )

    // Call the RemoveOrganizationFeature method using the underlyingClient
    return try await underlyingClient.RemoveOrganizationFeature(input)
  }

  public func setOrganizationFeature(
    organizationId: String,
    name: Components.Schemas.FeatureName, value: String
  ) async throws -> Operations.SetOrganizationFeature.Output {

    // Create the SetOrganizationFeatureIntent
    let setOrganizationFeatureIntent = Components.Schemas.SetOrganizationFeatureIntent(
      name: name, value: value)

    // Create the SetOrganizationFeatureRequest
    let setOrganizationFeatureRequest = Components.Schemas.SetOrganizationFeatureRequest(
      _type: .ACTIVITY_TYPE_SET_ORGANIZATION_FEATURE,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: setOrganizationFeatureIntent
    )

    // Create the input for the SetOrganizationFeature method
    let input = Operations.SetOrganizationFeature.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(setOrganizationFeatureRequest)
    )

    // Call the SetOrganizationFeature method using the underlyingClient
    return try await underlyingClient.SetOrganizationFeature(input)
  }

  public func signRawPayload(
    organizationId: String,
    signWith: String, payload: String, encoding: Components.Schemas.PayloadEncoding,
    hashFunction: Components.Schemas.HashFunction
  ) async throws -> Operations.SignRawPayload.Output {

    // Create the SignRawPayloadIntentV2
    let signRawPayloadIntent = Components.Schemas.SignRawPayloadIntentV2(
      signWith: signWith, payload: payload, encoding: encoding, hashFunction: hashFunction)

    // Create the SignRawPayloadRequest
    let signRawPayloadRequest = Components.Schemas.SignRawPayloadRequest(
      _type: .ACTIVITY_TYPE_SIGN_RAW_PAYLOAD_V2,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: signRawPayloadIntent
    )

    // Create the input for the SignRawPayload method
    let input = Operations.SignRawPayload.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(signRawPayloadRequest)
    )

    // Call the SignRawPayload method using the underlyingClient
    return try await underlyingClient.SignRawPayload(input)
  }

  public func signRawPayloads(
    organizationId: String,
    signWith: String, payloads: [String], encoding: Components.Schemas.PayloadEncoding,
    hashFunction: Components.Schemas.HashFunction
  ) async throws -> Operations.SignRawPayloads.Output {

    // Create the SignRawPayloadsIntent
    let signRawPayloadsIntent = Components.Schemas.SignRawPayloadsIntent(
      signWith: signWith, payloads: payloads, encoding: encoding, hashFunction: hashFunction)

    // Create the SignRawPayloadsRequest
    let signRawPayloadsRequest = Components.Schemas.SignRawPayloadsRequest(
      _type: .ACTIVITY_TYPE_SIGN_RAW_PAYLOADS,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: signRawPayloadsIntent
    )

    // Create the input for the SignRawPayloads method
    let input = Operations.SignRawPayloads.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(signRawPayloadsRequest)
    )

    // Call the SignRawPayloads method using the underlyingClient
    return try await underlyingClient.SignRawPayloads(input)
  }

  public func signTransaction(
    organizationId: String,
    signWith: String, unsignedTransaction: String, _type: Components.Schemas.TransactionType
  ) async throws -> Operations.SignTransaction.Output {

    // Create the SignTransactionIntentV2
    let signTransactionIntent = Components.Schemas.SignTransactionIntentV2(
      signWith: signWith, unsignedTransaction: unsignedTransaction, _type: _type)

    // Create the SignTransactionRequest
    let signTransactionRequest = Components.Schemas.SignTransactionRequest(
      _type: .ACTIVITY_TYPE_SIGN_TRANSACTION_V2,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: signTransactionIntent
    )

    // Create the input for the SignTransaction method
    let input = Operations.SignTransaction.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(signTransactionRequest)
    )

    // Call the SignTransaction method using the underlyingClient
    return try await underlyingClient.SignTransaction(input)
  }

  public func updatePolicy(
    organizationId: String,
    policyId: String, policyName: String?, policyEffect: Components.Schemas.Effect?,
    policyCondition: String?, policyConsensus: String?, policyNotes: String?
  ) async throws -> Operations.UpdatePolicy.Output {

    // Create the UpdatePolicyIntent
    let updatePolicyIntent = Components.Schemas.UpdatePolicyIntent(
      policyId: policyId, policyName: policyName, policyEffect: policyEffect,
      policyCondition: policyCondition, policyConsensus: policyConsensus, policyNotes: policyNotes)

    // Create the UpdatePolicyRequest
    let updatePolicyRequest = Components.Schemas.UpdatePolicyRequest(
      _type: .ACTIVITY_TYPE_UPDATE_POLICY,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: updatePolicyIntent
    )

    // Create the input for the UpdatePolicy method
    let input = Operations.UpdatePolicy.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(updatePolicyRequest)
    )

    // Call the UpdatePolicy method using the underlyingClient
    return try await underlyingClient.UpdatePolicy(input)
  }

  public func updatePrivateKeyTag(
    organizationId: String,
    privateKeyTagId: String, newPrivateKeyTagName: String?, addPrivateKeyIds: [String],
    removePrivateKeyIds: [String]
  ) async throws -> Operations.UpdatePrivateKeyTag.Output {

    // Create the UpdatePrivateKeyTagIntent
    let updatePrivateKeyTagIntent = Components.Schemas.UpdatePrivateKeyTagIntent(
      privateKeyTagId: privateKeyTagId, newPrivateKeyTagName: newPrivateKeyTagName,
      addPrivateKeyIds: addPrivateKeyIds, removePrivateKeyIds: removePrivateKeyIds)

    // Create the UpdatePrivateKeyTagRequest
    let updatePrivateKeyTagRequest = Components.Schemas.UpdatePrivateKeyTagRequest(
      _type: .ACTIVITY_TYPE_UPDATE_PRIVATE_KEY_TAG,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: updatePrivateKeyTagIntent
    )

    // Create the input for the UpdatePrivateKeyTag method
    let input = Operations.UpdatePrivateKeyTag.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(updatePrivateKeyTagRequest)
    )

    // Call the UpdatePrivateKeyTag method using the underlyingClient
    return try await underlyingClient.UpdatePrivateKeyTag(input)
  }

  public func updateRootQuorum(
    organizationId: String,
    threshold: Int32, userIds: [String]
  ) async throws -> Operations.UpdateRootQuorum.Output {

    // Create the UpdateRootQuorumIntent
    let updateRootQuorumIntent = Components.Schemas.UpdateRootQuorumIntent(
      threshold: threshold, userIds: userIds)

    // Create the UpdateRootQuorumRequest
    let updateRootQuorumRequest = Components.Schemas.UpdateRootQuorumRequest(
      _type: .ACTIVITY_TYPE_UPDATE_ROOT_QUORUM,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: updateRootQuorumIntent
    )

    // Create the input for the UpdateRootQuorum method
    let input = Operations.UpdateRootQuorum.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(updateRootQuorumRequest)
    )

    // Call the UpdateRootQuorum method using the underlyingClient
    return try await underlyingClient.UpdateRootQuorum(input)
  }

  public func updateUser(
    organizationId: String,
    userId: String, userName: String?, userEmail: String?, userTagIds: [String]?,
    userPhoneNumber: String?
  ) async throws -> Operations.UpdateUser.Output {

    // Create the UpdateUserIntent
    let updateUserIntent = Components.Schemas.UpdateUserIntent(
      userId: userId, userName: userName, userEmail: userEmail, userTagIds: userTagIds,
      userPhoneNumber: userPhoneNumber)

    // Create the UpdateUserRequest
    let updateUserRequest = Components.Schemas.UpdateUserRequest(
      _type: .ACTIVITY_TYPE_UPDATE_USER,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: updateUserIntent
    )

    // Create the input for the UpdateUser method
    let input = Operations.UpdateUser.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(updateUserRequest)
    )

    // Call the UpdateUser method using the underlyingClient
    return try await underlyingClient.UpdateUser(input)
  }

  public func updateUserTag(
    organizationId: String,
    userTagId: String, newUserTagName: String?, addUserIds: [String], removeUserIds: [String]
  ) async throws -> Operations.UpdateUserTag.Output {

    // Create the UpdateUserTagIntent
    let updateUserTagIntent = Components.Schemas.UpdateUserTagIntent(
      userTagId: userTagId, newUserTagName: newUserTagName, addUserIds: addUserIds,
      removeUserIds: removeUserIds)

    // Create the UpdateUserTagRequest
    let updateUserTagRequest = Components.Schemas.UpdateUserTagRequest(
      _type: .ACTIVITY_TYPE_UPDATE_USER_TAG,
      timestampMs: String(Int(Date().timeIntervalSince1970 * 1000)),
      organizationId: organizationId,
      parameters: updateUserTagIntent
    )

    // Create the input for the UpdateUserTag method
    let input = Operations.UpdateUserTag.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(updateUserTagRequest)
    )

    // Call the UpdateUserTag method using the underlyingClient
    return try await underlyingClient.UpdateUserTag(input)
  }
}
