// Generated using Sourcery 2.2.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

import AuthenticationServices
import CryptoKit
import Foundation
import Middleware
import OpenAPIRuntime
import OpenAPIURLSession
import Shared

public struct TurnkeyClient {
  private let underlyingClient: any APIProtocol
  private let passkeyManager: PasskeyManager?
  private let proxyURL: URL?

  internal init(
    underlyingClient: any APIProtocol, passkeyManager: PasskeyManager?, proxyURL: URL? = nil
  ) {
    self.underlyingClient = underlyingClient
    self.passkeyManager = passkeyManager
    self.proxyURL = proxyURL
  }

  public init(apiPrivateKey: String, apiPublicKey: String, proxyURL: URL? = nil) {
    let stamper = Stamper(apiPublicKey: apiPublicKey, apiPrivateKey: apiPrivateKey)
    self.init(
      underlyingClient: Client(
        serverURL: URL(string: "https://api.turnkey.com")!,
        transport: URLSessionTransport(),
        middlewares: [AuthStampMiddleware(stamper: stamper)]
      ),
      passkeyManager: nil,
      proxyURL: proxyURL
    )
  }

  public init(rpId: String, presentationAnchor: ASPresentationAnchor, proxyURL: URL? = nil) {
    let stamper = Stamper(rpId: rpId, presentationAnchor: presentationAnchor)
    self.init(
      underlyingClient: Client(
        serverURL: URL(string: "https://api.turnkey.com")!,
        transport: URLSessionTransport(),
        middlewares: [AuthStampMiddleware(stamper: stamper)]
      ),
      passkeyManager: PasskeyManager(rpId: rpId, presentationAnchor: presentationAnchor),
      proxyURL: proxyURL
    )
  }

  private func getProxiedClient() -> any APIProtocol {
    let proxyMiddleware = ProxyMiddleware(proxyURL: proxyURL!)
    return Client(
      serverURL: URL(string: "https://api.turnkey.com")!,
      transport: URLSessionTransport(),
      middlewares: [proxyMiddleware]
    )
  }

  public func getActivity(organizationId: String, activityId: String, useProxy: Bool = false)
    async throws -> Operations.GetActivity.Output
  {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the GetActivityRequest
    let getActivityRequest = Components.Schemas.GetActivityRequest(
      organizationId: organizationId, activityId: activityId
    )

    let input = Operations.GetActivity.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getActivityRequest)
    )
    return try await client.GetActivity(input)
  }
  public func getApiKey(organizationId: String, apiKeyId: String, useProxy: Bool = false)
    async throws -> Operations.GetApiKey.Output
  {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the GetApiKeyRequest
    let getApiKeyRequest = Components.Schemas.GetApiKeyRequest(
      organizationId: organizationId, apiKeyId: apiKeyId
    )

    let input = Operations.GetApiKey.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getApiKeyRequest)
    )
    return try await client.GetApiKey(input)
  }
  public func getApiKeys(organizationId: String, userId: String?, useProxy: Bool = false)
    async throws -> Operations.GetApiKeys.Output
  {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the GetApiKeysRequest
    let getApiKeysRequest = Components.Schemas.GetApiKeysRequest(
      organizationId: organizationId, userId: userId
    )

    let input = Operations.GetApiKeys.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getApiKeysRequest)
    )
    return try await client.GetApiKeys(input)
  }
  public func getAuthenticator(
    organizationId: String, authenticatorId: String, useProxy: Bool = false
  ) async throws -> Operations.GetAuthenticator.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the GetAuthenticatorRequest
    let getAuthenticatorRequest = Components.Schemas.GetAuthenticatorRequest(
      organizationId: organizationId, authenticatorId: authenticatorId
    )

    let input = Operations.GetAuthenticator.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getAuthenticatorRequest)
    )
    return try await client.GetAuthenticator(input)
  }
  public func getAuthenticators(organizationId: String, userId: String, useProxy: Bool = false)
    async throws -> Operations.GetAuthenticators.Output
  {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the GetAuthenticatorsRequest
    let getAuthenticatorsRequest = Components.Schemas.GetAuthenticatorsRequest(
      organizationId: organizationId, userId: userId
    )

    let input = Operations.GetAuthenticators.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getAuthenticatorsRequest)
    )
    return try await client.GetAuthenticators(input)
  }
  public func getPolicy(organizationId: String, policyId: String, useProxy: Bool = false)
    async throws -> Operations.GetPolicy.Output
  {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the GetPolicyRequest
    let getPolicyRequest = Components.Schemas.GetPolicyRequest(
      organizationId: organizationId, policyId: policyId
    )

    let input = Operations.GetPolicy.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getPolicyRequest)
    )
    return try await client.GetPolicy(input)
  }
  public func getPrivateKey(organizationId: String, privateKeyId: String, useProxy: Bool = false)
    async throws -> Operations.GetPrivateKey.Output
  {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the GetPrivateKeyRequest
    let getPrivateKeyRequest = Components.Schemas.GetPrivateKeyRequest(
      organizationId: organizationId, privateKeyId: privateKeyId
    )

    let input = Operations.GetPrivateKey.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getPrivateKeyRequest)
    )
    return try await client.GetPrivateKey(input)
  }
  public func getUser(organizationId: String, userId: String, useProxy: Bool = false) async throws
    -> Operations.GetUser.Output
  {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the GetUserRequest
    let getUserRequest = Components.Schemas.GetUserRequest(
      organizationId: organizationId, userId: userId
    )

    let input = Operations.GetUser.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getUserRequest)
    )
    return try await client.GetUser(input)
  }
  public func getWallet(organizationId: String, walletId: String, useProxy: Bool = false)
    async throws -> Operations.GetWallet.Output
  {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the GetWalletRequest
    let getWalletRequest = Components.Schemas.GetWalletRequest(
      organizationId: organizationId, walletId: walletId
    )

    let input = Operations.GetWallet.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getWalletRequest)
    )
    return try await client.GetWallet(input)
  }
  public func getActivities(
    organizationId: String, filterByStatus: [Components.Schemas.ActivityStatus]?,
    paginationOptions: Components.Schemas.Pagination?,
    filterByType: [Components.Schemas.ActivityType]?, useProxy: Bool = false
  ) async throws -> Operations.GetActivities.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the GetActivitiesRequest
    let getActivitiesRequest = Components.Schemas.GetActivitiesRequest(
      organizationId: organizationId, filterByStatus: filterByStatus,
      paginationOptions: paginationOptions, filterByType: filterByType
    )

    let input = Operations.GetActivities.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getActivitiesRequest)
    )
    return try await client.GetActivities(input)
  }
  public func getPolicies(organizationId: String, useProxy: Bool = false) async throws
    -> Operations.GetPolicies.Output
  {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the GetPoliciesRequest
    let getPoliciesRequest = Components.Schemas.GetPoliciesRequest(
      organizationId: organizationId
    )

    let input = Operations.GetPolicies.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getPoliciesRequest)
    )
    return try await client.GetPolicies(input)
  }
  public func listPrivateKeyTags(organizationId: String, useProxy: Bool = false) async throws
    -> Operations.ListPrivateKeyTags.Output
  {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the ListPrivateKeyTagsRequest
    let listPrivateKeyTagsRequest = Components.Schemas.ListPrivateKeyTagsRequest(
      organizationId: organizationId
    )

    let input = Operations.ListPrivateKeyTags.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(listPrivateKeyTagsRequest)
    )
    return try await client.ListPrivateKeyTags(input)
  }
  public func getPrivateKeys(organizationId: String, useProxy: Bool = false) async throws
    -> Operations.GetPrivateKeys.Output
  {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the GetPrivateKeysRequest
    let getPrivateKeysRequest = Components.Schemas.GetPrivateKeysRequest(
      organizationId: organizationId
    )

    let input = Operations.GetPrivateKeys.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getPrivateKeysRequest)
    )
    return try await client.GetPrivateKeys(input)
  }
  public func getSubOrgIds(
    organizationId: String, filterType: String?, filterValue: String?,
    paginationOptions: Components.Schemas.Pagination?, useProxy: Bool = false
  ) async throws -> Operations.GetSubOrgIds.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the GetSubOrgIdsRequest
    let getSubOrgIdsRequest = Components.Schemas.GetSubOrgIdsRequest(
      organizationId: organizationId, filterType: filterType, filterValue: filterValue,
      paginationOptions: paginationOptions
    )

    let input = Operations.GetSubOrgIds.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getSubOrgIdsRequest)
    )
    return try await client.GetSubOrgIds(input)
  }
  public func listUserTags(organizationId: String, useProxy: Bool = false) async throws
    -> Operations.ListUserTags.Output
  {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the ListUserTagsRequest
    let listUserTagsRequest = Components.Schemas.ListUserTagsRequest(
      organizationId: organizationId
    )

    let input = Operations.ListUserTags.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(listUserTagsRequest)
    )
    return try await client.ListUserTags(input)
  }
  public func getUsers(organizationId: String, useProxy: Bool = false) async throws
    -> Operations.GetUsers.Output
  {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the GetUsersRequest
    let getUsersRequest = Components.Schemas.GetUsersRequest(
      organizationId: organizationId
    )

    let input = Operations.GetUsers.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getUsersRequest)
    )
    return try await client.GetUsers(input)
  }
  public func getWalletAccounts(
    organizationId: String, walletId: String, paginationOptions: Components.Schemas.Pagination?,
    useProxy: Bool = false
  ) async throws -> Operations.GetWalletAccounts.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the GetWalletAccountsRequest
    let getWalletAccountsRequest = Components.Schemas.GetWalletAccountsRequest(
      organizationId: organizationId, walletId: walletId, paginationOptions: paginationOptions
    )

    let input = Operations.GetWalletAccounts.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getWalletAccountsRequest)
    )
    return try await client.GetWalletAccounts(input)
  }
  public func getWallets(organizationId: String, useProxy: Bool = false) async throws
    -> Operations.GetWallets.Output
  {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the GetWalletsRequest
    let getWalletsRequest = Components.Schemas.GetWalletsRequest(
      organizationId: organizationId
    )

    let input = Operations.GetWallets.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getWalletsRequest)
    )
    return try await client.GetWallets(input)
  }
  public func getWhoami(organizationId: String, useProxy: Bool = false) async throws
    -> Operations.GetWhoami.Output
  {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the GetWhoamiRequest
    let getWhoamiRequest = Components.Schemas.GetWhoamiRequest(
      organizationId: organizationId
    )

    let input = Operations.GetWhoami.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getWhoamiRequest)
    )
    return try await client.GetWhoami(input)
  }

  public func approveActivity(
    organizationId: String,
    fingerprint: String, useProxy: Bool = false
  ) async throws -> Operations.ApproveActivity.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.ApproveActivity(input)
  }

  public func createApiKeys(
    organizationId: String,
    apiKeys: [Components.Schemas.ApiKeyParams], userId: String, useProxy: Bool = false
  ) async throws -> Operations.CreateApiKeys.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the CreateApiKeysIntent
    let createApiKeysIntent = Components.Schemas.CreateApiKeysIntent(
      apiKeys: apiKeys, userId: userId)

    // Create the CreateApiKeysRequest
    let createApiKeysRequest = Components.Schemas.CreateApiKeysRequest(
      _type: .ACTIVITY_TYPE_CREATE_API_KEYS,
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
    return try await client.CreateApiKeys(input)
  }

  public func createAuthenticators(
    organizationId: String,
    authenticators: [Components.Schemas.AuthenticatorParamsV2], userId: String,
    useProxy: Bool = false
  ) async throws -> Operations.CreateAuthenticators.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.CreateAuthenticators(input)
  }

  public func createInvitations(
    organizationId: String,
    invitations: [Components.Schemas.InvitationParams], useProxy: Bool = false
  ) async throws -> Operations.CreateInvitations.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.CreateInvitations(input)
  }

  public func createPolicies(
    organizationId: String,
    policies: [Components.Schemas.CreatePolicyIntentV3], useProxy: Bool = false
  ) async throws -> Operations.CreatePolicies.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.CreatePolicies(input)
  }

  public func createPolicy(
    organizationId: String,
    policyName: String, effect: Components.Schemas.Effect, condition: String?, consensus: String?,
    notes: String?, useProxy: Bool = false
  ) async throws -> Operations.CreatePolicy.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.CreatePolicy(input)
  }

  public func createPrivateKeyTag(
    organizationId: String,
    privateKeyTagName: String, privateKeyIds: [String], useProxy: Bool = false
  ) async throws -> Operations.CreatePrivateKeyTag.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.CreatePrivateKeyTag(input)
  }

  public func createPrivateKeys(
    organizationId: String,
    privateKeys: [Components.Schemas.PrivateKeyParams], useProxy: Bool = false
  ) async throws -> Operations.CreatePrivateKeys.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.CreatePrivateKeys(input)
  }

  public func createSubOrganization(
    organizationId: String,
    subOrganizationName: String, rootUsers: [Components.Schemas.RootUserParams],
    rootQuorumThreshold: Int32, wallet: Components.Schemas.WalletParams?,
    disableEmailRecovery: Bool?, disableEmailAuth: Bool?, useProxy: Bool = false
  ) async throws -> Operations.CreateSubOrganization.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the CreateSubOrganizationIntentV4
    let createSubOrganizationIntent = Components.Schemas.CreateSubOrganizationIntentV4(
      subOrganizationName: subOrganizationName, rootUsers: rootUsers,
      rootQuorumThreshold: rootQuorumThreshold, wallet: wallet,
      disableEmailRecovery: disableEmailRecovery, disableEmailAuth: disableEmailAuth)

    // Create the CreateSubOrganizationRequest
    let createSubOrganizationRequest = Components.Schemas.CreateSubOrganizationRequest(
      _type: .ACTIVITY_TYPE_CREATE_SUB_ORGANIZATION_V4,
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
    return try await client.CreateSubOrganization(input)
  }

  public func createUserTag(
    organizationId: String,
    userTagName: String, userIds: [String], useProxy: Bool = false
  ) async throws -> Operations.CreateUserTag.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.CreateUserTag(input)
  }

  public func createUsers(
    organizationId: String,
    users: [Components.Schemas.UserParamsV2], useProxy: Bool = false
  ) async throws -> Operations.CreateUsers.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.CreateUsers(input)
  }

  public func createWallet(
    organizationId: String,
    walletName: String, accounts: [Components.Schemas.WalletAccountParams], mnemonicLength: Int32?,
    useProxy: Bool = false
  ) async throws -> Operations.CreateWallet.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.CreateWallet(input)
  }

  public func createWalletAccounts(
    organizationId: String,
    walletId: String, accounts: [Components.Schemas.WalletAccountParams], useProxy: Bool = false
  ) async throws -> Operations.CreateWalletAccounts.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.CreateWalletAccounts(input)
  }

  public func deleteApiKeys(
    organizationId: String,
    userId: String, apiKeyIds: [String], useProxy: Bool = false
  ) async throws -> Operations.DeleteApiKeys.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.DeleteApiKeys(input)
  }

  public func deleteAuthenticators(
    organizationId: String,
    userId: String, authenticatorIds: [String], useProxy: Bool = false
  ) async throws -> Operations.DeleteAuthenticators.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.DeleteAuthenticators(input)
  }

  public func deleteInvitation(
    organizationId: String,
    invitationId: String, useProxy: Bool = false
  ) async throws -> Operations.DeleteInvitation.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.DeleteInvitation(input)
  }

  public func deletePolicy(
    organizationId: String,
    policyId: String, useProxy: Bool = false
  ) async throws -> Operations.DeletePolicy.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.DeletePolicy(input)
  }

  public func deletePrivateKeyTags(
    organizationId: String,
    privateKeyTagIds: [String], useProxy: Bool = false
  ) async throws -> Operations.DeletePrivateKeyTags.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.DeletePrivateKeyTags(input)
  }

  public func deleteUserTags(
    organizationId: String,
    userTagIds: [String], useProxy: Bool = false
  ) async throws -> Operations.DeleteUserTags.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.DeleteUserTags(input)
  }

  public func deleteUsers(
    organizationId: String,
    userIds: [String], useProxy: Bool = false
  ) async throws -> Operations.DeleteUsers.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.DeleteUsers(input)
  }

  public func emailAuth(
    organizationId: String,
    email: String, targetPublicKey: String, apiKeyName: String?, expirationSeconds: String?,
    emailCustomization: Components.Schemas.EmailCustomizationParams?, useProxy: Bool = false
  ) async throws -> Operations.EmailAuth.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the EmailAuthIntent
    let emailAuthIntent = Components.Schemas.EmailAuthIntent(
      email: email, targetPublicKey: targetPublicKey, apiKeyName: apiKeyName,
      expirationSeconds: expirationSeconds, emailCustomization: emailCustomization)

    // Create the EmailAuthRequest
    let emailAuthRequest = Components.Schemas.EmailAuthRequest(
      _type: .ACTIVITY_TYPE_EMAIL_AUTH,
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
    return try await client.EmailAuth(input)
  }

  public func exportPrivateKey(
    organizationId: String,
    privateKeyId: String, targetPublicKey: String, useProxy: Bool = false
  ) async throws -> Operations.ExportPrivateKey.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.ExportPrivateKey(input)
  }

  public func exportWallet(
    organizationId: String,
    walletId: String, targetPublicKey: String, language: Components.Schemas.MnemonicLanguage?,
    useProxy: Bool = false
  ) async throws -> Operations.ExportWallet.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.ExportWallet(input)
  }

  public func exportWalletAccount(
    organizationId: String,
    address: String, targetPublicKey: String, useProxy: Bool = false
  ) async throws -> Operations.ExportWalletAccount.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.ExportWalletAccount(input)
  }

  public func importPrivateKey(
    organizationId: String,
    userId: String, privateKeyName: String, encryptedBundle: String,
    curve: Components.Schemas.Curve, addressFormats: [Components.Schemas.AddressFormat],
    useProxy: Bool = false
  ) async throws -> Operations.ImportPrivateKey.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.ImportPrivateKey(input)
  }

  public func importWallet(
    organizationId: String,
    userId: String, walletName: String, encryptedBundle: String,
    accounts: [Components.Schemas.WalletAccountParams], useProxy: Bool = false
  ) async throws -> Operations.ImportWallet.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.ImportWallet(input)
  }

  public func initImportPrivateKey(
    organizationId: String,
    userId: String, useProxy: Bool = false
  ) async throws -> Operations.InitImportPrivateKey.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.InitImportPrivateKey(input)
  }

  public func initImportWallet(
    organizationId: String,
    userId: String, useProxy: Bool = false
  ) async throws -> Operations.InitImportWallet.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.InitImportWallet(input)
  }

  public func initUserEmailRecovery(
    organizationId: String,
    email: String, targetPublicKey: String, expirationSeconds: String?,
    emailCustomization: Components.Schemas.EmailCustomizationParams?, useProxy: Bool = false
  ) async throws -> Operations.InitUserEmailRecovery.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.InitUserEmailRecovery(input)
  }

  public func recoverUser(
    organizationId: String,
    authenticator: Components.Schemas.AuthenticatorParamsV2, userId: String, useProxy: Bool = false
  ) async throws -> Operations.RecoverUser.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.RecoverUser(input)
  }

  public func rejectActivity(
    organizationId: String,
    fingerprint: String, useProxy: Bool = false
  ) async throws -> Operations.RejectActivity.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.RejectActivity(input)
  }

  public func removeOrganizationFeature(
    organizationId: String,
    name: Components.Schemas.FeatureName, useProxy: Bool = false
  ) async throws -> Operations.RemoveOrganizationFeature.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.RemoveOrganizationFeature(input)
  }

  public func setOrganizationFeature(
    organizationId: String,
    name: Components.Schemas.FeatureName, value: String, useProxy: Bool = false
  ) async throws -> Operations.SetOrganizationFeature.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.SetOrganizationFeature(input)
  }

  public func signRawPayload(
    organizationId: String,
    signWith: String, payload: String, encoding: Components.Schemas.PayloadEncoding,
    hashFunction: Components.Schemas.HashFunction, useProxy: Bool = false
  ) async throws -> Operations.SignRawPayload.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.SignRawPayload(input)
  }

  public func signRawPayloads(
    organizationId: String,
    signWith: String, payloads: [String], encoding: Components.Schemas.PayloadEncoding,
    hashFunction: Components.Schemas.HashFunction, useProxy: Bool = false
  ) async throws -> Operations.SignRawPayloads.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.SignRawPayloads(input)
  }

  public func signTransaction(
    organizationId: String,
    signWith: String, unsignedTransaction: String, _type: Components.Schemas.TransactionType,
    useProxy: Bool = false
  ) async throws -> Operations.SignTransaction.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.SignTransaction(input)
  }

  public func updatePolicy(
    organizationId: String,
    policyId: String, policyName: String?, policyEffect: Components.Schemas.Effect?,
    policyCondition: String?, policyConsensus: String?, policyNotes: String?, useProxy: Bool = false
  ) async throws -> Operations.UpdatePolicy.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.UpdatePolicy(input)
  }

  public func updatePrivateKeyTag(
    organizationId: String,
    privateKeyTagId: String, newPrivateKeyTagName: String?, addPrivateKeyIds: [String],
    removePrivateKeyIds: [String], useProxy: Bool = false
  ) async throws -> Operations.UpdatePrivateKeyTag.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.UpdatePrivateKeyTag(input)
  }

  public func updateRootQuorum(
    organizationId: String,
    threshold: Int32, userIds: [String], useProxy: Bool = false
  ) async throws -> Operations.UpdateRootQuorum.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.UpdateRootQuorum(input)
  }

  public func updateUser(
    organizationId: String,
    userId: String, userName: String?, userEmail: String?, userTagIds: [String]?,
    useProxy: Bool = false
  ) async throws -> Operations.UpdateUser.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

    // Create the UpdateUserIntent
    let updateUserIntent = Components.Schemas.UpdateUserIntent(
      userId: userId, userName: userName, userEmail: userEmail, userTagIds: userTagIds)

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
    return try await client.UpdateUser(input)
  }

  public func updateUserTag(
    organizationId: String,
    userTagId: String, newUserTagName: String?, addUserIds: [String], removeUserIds: [String],
    useProxy: Bool = false
  ) async throws -> Operations.UpdateUserTag.Output {
    let client: any APIProtocol = useProxy ? getProxiedClient() : underlyingClient

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
    return try await client.UpdateUserTag(input)
  }
}
