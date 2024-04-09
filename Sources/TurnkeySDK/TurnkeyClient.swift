// Generated using Sourcery 2.2.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT


import OpenAPIRuntime
import OpenAPIURLSession
import Foundation
import CryptoKit
import AuthStampMiddleware

public struct TurnkeyClient {
    private let underlyingClient: any APIProtocol
    private let apiPrivateKey: String
    private let apiPublicKey: String

    internal init(underlyingClient: any APIProtocol, apiPrivateKey: String, apiPublicKey: String) {
        self.underlyingClient = underlyingClient
        self.apiPrivateKey = apiPrivateKey
        self.apiPublicKey = apiPublicKey
    }

    public init(apiPrivateKey: String, apiPublicKey: String) {
        self.init(
            underlyingClient: Client(
                serverURL: URL(string: "https://api.turnkey.com")!,
                transport: URLSessionTransport(),
                middlewares: [AuthStampMiddleware(apiPrivateKey: apiPrivateKey, apiPublicKey: apiPublicKey)]
            ),
            apiPrivateKey: apiPrivateKey,
            apiPublicKey: apiPublicKey
        )
    }

        public func getActivity(organizationId: String, activityId: String) async throws -> Operations.GetActivity.Output {
        let input = Operations.GetActivity.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.GetActivityRequest(organizationId: organizationId), Components.Schemas.GetActivityRequest(activityId: activityId))
        )
        return try await underlyingClient.GetActivity(input)
    }
        public func getApiKey(organizationId: String, apiKeyId: String) async throws -> Operations.GetApiKey.Output {
        let input = Operations.GetApiKey.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.GetApiKeyRequest(organizationId: organizationId), Components.Schemas.GetApiKeyRequest(apiKeyId: apiKeyId))
        )
        return try await underlyingClient.GetApiKey(input)
    }
        public func getApiKeys(organizationId: String, userId: String?) async throws -> Operations.GetApiKeys.Output {
        let input = Operations.GetApiKeys.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.GetApiKeysRequest(organizationId: organizationId), Components.Schemas.GetApiKeysRequest(userId: userId))
        )
        return try await underlyingClient.GetApiKeys(input)
    }
        public func getAuthenticator(organizationId: String, authenticatorId: String) async throws -> Operations.GetAuthenticator.Output {
        let input = Operations.GetAuthenticator.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.GetAuthenticatorRequest(organizationId: organizationId), Components.Schemas.GetAuthenticatorRequest(authenticatorId: authenticatorId))
        )
        return try await underlyingClient.GetAuthenticator(input)
    }
        public func getAuthenticators(organizationId: String, userId: String) async throws -> Operations.GetAuthenticators.Output {
        let input = Operations.GetAuthenticators.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.GetAuthenticatorsRequest(organizationId: organizationId), Components.Schemas.GetAuthenticatorsRequest(userId: userId))
        )
        return try await underlyingClient.GetAuthenticators(input)
    }
        public func getPolicy(organizationId: String, policyId: String) async throws -> Operations.GetPolicy.Output {
        let input = Operations.GetPolicy.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.GetPolicyRequest(organizationId: organizationId), Components.Schemas.GetPolicyRequest(policyId: policyId))
        )
        return try await underlyingClient.GetPolicy(input)
    }
        public func getPrivateKey(organizationId: String, privateKeyId: String) async throws -> Operations.GetPrivateKey.Output {
        let input = Operations.GetPrivateKey.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.GetPrivateKeyRequest(organizationId: organizationId), Components.Schemas.GetPrivateKeyRequest(privateKeyId: privateKeyId))
        )
        return try await underlyingClient.GetPrivateKey(input)
    }
        public func getUser(organizationId: String, userId: String) async throws -> Operations.GetUser.Output {
        let input = Operations.GetUser.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.GetUserRequest(organizationId: organizationId), Components.Schemas.GetUserRequest(userId: userId))
        )
        return try await underlyingClient.GetUser(input)
    }
        public func getWallet(organizationId: String, walletId: String) async throws -> Operations.GetWallet.Output {
        let input = Operations.GetWallet.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.GetWalletRequest(organizationId: organizationId), Components.Schemas.GetWalletRequest(walletId: walletId))
        )
        return try await underlyingClient.GetWallet(input)
    }
        public func getActivities(organizationId: String, filterByStatus: [Components.Schemas.ActivityStatus]?, paginationOptions: Components.Schemas.Pagination?, filterByType: [Components.Schemas.ActivityType]?) async throws -> Operations.GetActivities.Output {
        let input = Operations.GetActivities.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.GetActivitiesRequest(organizationId: organizationId), Components.Schemas.GetActivitiesRequest(filterByStatus: filterByStatus), Components.Schemas.GetActivitiesRequest(paginationOptions: paginationOptions), Components.Schemas.GetActivitiesRequest(filterByType: filterByType))
        )
        return try await underlyingClient.GetActivities(input)
    }
        public func getPolicies(organizationId: String) async throws -> Operations.GetPolicies.Output {
        let input = Operations.GetPolicies.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.GetPoliciesRequest(organizationId: organizationId))
        )
        return try await underlyingClient.GetPolicies(input)
    }
        public func listPrivateKeyTags(organizationId: String) async throws -> Operations.ListPrivateKeyTags.Output {
        let input = Operations.ListPrivateKeyTags.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.ListPrivateKeyTagsRequest(organizationId: organizationId))
        )
        return try await underlyingClient.ListPrivateKeyTags(input)
    }
        public func getPrivateKeys(organizationId: String) async throws -> Operations.GetPrivateKeys.Output {
        let input = Operations.GetPrivateKeys.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.GetPrivateKeysRequest(organizationId: organizationId))
        )
        return try await underlyingClient.GetPrivateKeys(input)
    }
        public func getSubOrgIds(organizationId: String, filterType: String?, filterValue: String?, paginationOptions: Components.Schemas.Pagination?) async throws -> Operations.GetSubOrgIds.Output {
        let input = Operations.GetSubOrgIds.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.GetSubOrgIdsRequest(organizationId: organizationId), Components.Schemas.GetSubOrgIdsRequest(filterType: filterType), Components.Schemas.GetSubOrgIdsRequest(filterValue: filterValue), Components.Schemas.GetSubOrgIdsRequest(paginationOptions: paginationOptions))
        )
        return try await underlyingClient.GetSubOrgIds(input)
    }
        public func listUserTags(organizationId: String) async throws -> Operations.ListUserTags.Output {
        let input = Operations.ListUserTags.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.ListUserTagsRequest(organizationId: organizationId))
        )
        return try await underlyingClient.ListUserTags(input)
    }
        public func getUsers(organizationId: String) async throws -> Operations.GetUsers.Output {
        let input = Operations.GetUsers.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.GetUsersRequest(organizationId: organizationId))
        )
        return try await underlyingClient.GetUsers(input)
    }
        public func getWalletAccounts(organizationId: String, walletId: String, paginationOptions: Components.Schemas.Pagination?) async throws -> Operations.GetWalletAccounts.Output {
        let input = Operations.GetWalletAccounts.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.GetWalletAccountsRequest(organizationId: organizationId), Components.Schemas.GetWalletAccountsRequest(walletId: walletId), Components.Schemas.GetWalletAccountsRequest(paginationOptions: paginationOptions))
        )
        return try await underlyingClient.GetWalletAccounts(input)
    }
        public func getWallets(organizationId: String) async throws -> Operations.GetWallets.Output {
        let input = Operations.GetWallets.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.GetWalletsRequest(organizationId: organizationId))
        )
        return try await underlyingClient.GetWallets(input)
    }
        public func getWhoami(organizationId: String) async throws -> Operations.GetWhoami.Output {
        let input = Operations.GetWhoami.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.GetWhoamiRequest(organizationId: organizationId))
        )
        return try await underlyingClient.GetWhoami(input)
    }
        public func approveActivity(_type: Components.Schemas.ApproveActivityRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.ApproveActivityIntent) async throws -> Operations.ApproveActivity.Output {
        let input = Operations.ApproveActivity.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.ApproveActivityRequest(_type: _type), Components.Schemas.ApproveActivityRequest(timestampMs: timestampMs), Components.Schemas.ApproveActivityRequest(organizationId: organizationId), Components.Schemas.ApproveActivityRequest(parameters: parameters))
        )
        return try await underlyingClient.ApproveActivity(input)
    }
        public func createApiKeys(_type: Components.Schemas.CreateApiKeysRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.CreateApiKeysIntent) async throws -> Operations.CreateApiKeys.Output {
        let input = Operations.CreateApiKeys.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.CreateApiKeysRequest(_type: _type), Components.Schemas.CreateApiKeysRequest(timestampMs: timestampMs), Components.Schemas.CreateApiKeysRequest(organizationId: organizationId), Components.Schemas.CreateApiKeysRequest(parameters: parameters))
        )
        return try await underlyingClient.CreateApiKeys(input)
    }
        public func createAuthenticators(_type: Components.Schemas.CreateAuthenticatorsRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.CreateAuthenticatorsIntentV2) async throws -> Operations.CreateAuthenticators.Output {
        let input = Operations.CreateAuthenticators.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.CreateAuthenticatorsRequest(_type: _type), Components.Schemas.CreateAuthenticatorsRequest(timestampMs: timestampMs), Components.Schemas.CreateAuthenticatorsRequest(organizationId: organizationId), Components.Schemas.CreateAuthenticatorsRequest(parameters: parameters))
        )
        return try await underlyingClient.CreateAuthenticators(input)
    }
        public func createInvitations(_type: Components.Schemas.CreateInvitationsRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.CreateInvitationsIntent) async throws -> Operations.CreateInvitations.Output {
        let input = Operations.CreateInvitations.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.CreateInvitationsRequest(_type: _type), Components.Schemas.CreateInvitationsRequest(timestampMs: timestampMs), Components.Schemas.CreateInvitationsRequest(organizationId: organizationId), Components.Schemas.CreateInvitationsRequest(parameters: parameters))
        )
        return try await underlyingClient.CreateInvitations(input)
    }
        public func createPolicies(_type: Components.Schemas.CreatePoliciesRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.CreatePoliciesIntent) async throws -> Operations.CreatePolicies.Output {
        let input = Operations.CreatePolicies.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.CreatePoliciesRequest(_type: _type), Components.Schemas.CreatePoliciesRequest(timestampMs: timestampMs), Components.Schemas.CreatePoliciesRequest(organizationId: organizationId), Components.Schemas.CreatePoliciesRequest(parameters: parameters))
        )
        return try await underlyingClient.CreatePolicies(input)
    }
        public func createPolicy(_type: Components.Schemas.CreatePolicyRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.CreatePolicyIntentV3) async throws -> Operations.CreatePolicy.Output {
        let input = Operations.CreatePolicy.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.CreatePolicyRequest(_type: _type), Components.Schemas.CreatePolicyRequest(timestampMs: timestampMs), Components.Schemas.CreatePolicyRequest(organizationId: organizationId), Components.Schemas.CreatePolicyRequest(parameters: parameters))
        )
        return try await underlyingClient.CreatePolicy(input)
    }
        public func createPrivateKeyTag(_type: Components.Schemas.CreatePrivateKeyTagRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.CreatePrivateKeyTagIntent) async throws -> Operations.CreatePrivateKeyTag.Output {
        let input = Operations.CreatePrivateKeyTag.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.CreatePrivateKeyTagRequest(_type: _type), Components.Schemas.CreatePrivateKeyTagRequest(timestampMs: timestampMs), Components.Schemas.CreatePrivateKeyTagRequest(organizationId: organizationId), Components.Schemas.CreatePrivateKeyTagRequest(parameters: parameters))
        )
        return try await underlyingClient.CreatePrivateKeyTag(input)
    }
        public func createPrivateKeys(_type: Components.Schemas.CreatePrivateKeysRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.CreatePrivateKeysIntentV2) async throws -> Operations.CreatePrivateKeys.Output {
        let input = Operations.CreatePrivateKeys.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.CreatePrivateKeysRequest(_type: _type), Components.Schemas.CreatePrivateKeysRequest(timestampMs: timestampMs), Components.Schemas.CreatePrivateKeysRequest(organizationId: organizationId), Components.Schemas.CreatePrivateKeysRequest(parameters: parameters))
        )
        return try await underlyingClient.CreatePrivateKeys(input)
    }
        public func createSubOrganization(_type: Components.Schemas.CreateSubOrganizationRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.CreateSubOrganizationIntentV4) async throws -> Operations.CreateSubOrganization.Output {
        let input = Operations.CreateSubOrganization.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.CreateSubOrganizationRequest(_type: _type), Components.Schemas.CreateSubOrganizationRequest(timestampMs: timestampMs), Components.Schemas.CreateSubOrganizationRequest(organizationId: organizationId), Components.Schemas.CreateSubOrganizationRequest(parameters: parameters))
        )
        return try await underlyingClient.CreateSubOrganization(input)
    }
        public func createUserTag(_type: Components.Schemas.CreateUserTagRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.CreateUserTagIntent) async throws -> Operations.CreateUserTag.Output {
        let input = Operations.CreateUserTag.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.CreateUserTagRequest(_type: _type), Components.Schemas.CreateUserTagRequest(timestampMs: timestampMs), Components.Schemas.CreateUserTagRequest(organizationId: organizationId), Components.Schemas.CreateUserTagRequest(parameters: parameters))
        )
        return try await underlyingClient.CreateUserTag(input)
    }
        public func createUsers(_type: Components.Schemas.CreateUsersRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.CreateUsersIntentV2) async throws -> Operations.CreateUsers.Output {
        let input = Operations.CreateUsers.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.CreateUsersRequest(_type: _type), Components.Schemas.CreateUsersRequest(timestampMs: timestampMs), Components.Schemas.CreateUsersRequest(organizationId: organizationId), Components.Schemas.CreateUsersRequest(parameters: parameters))
        )
        return try await underlyingClient.CreateUsers(input)
    }
        public func createWallet(_type: Components.Schemas.CreateWalletRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.CreateWalletIntent) async throws -> Operations.CreateWallet.Output {
        let input = Operations.CreateWallet.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.CreateWalletRequest(_type: _type), Components.Schemas.CreateWalletRequest(timestampMs: timestampMs), Components.Schemas.CreateWalletRequest(organizationId: organizationId), Components.Schemas.CreateWalletRequest(parameters: parameters))
        )
        return try await underlyingClient.CreateWallet(input)
    }
        public func createWalletAccounts(_type: Components.Schemas.CreateWalletAccountsRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.CreateWalletAccountsIntent) async throws -> Operations.CreateWalletAccounts.Output {
        let input = Operations.CreateWalletAccounts.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.CreateWalletAccountsRequest(_type: _type), Components.Schemas.CreateWalletAccountsRequest(timestampMs: timestampMs), Components.Schemas.CreateWalletAccountsRequest(organizationId: organizationId), Components.Schemas.CreateWalletAccountsRequest(parameters: parameters))
        )
        return try await underlyingClient.CreateWalletAccounts(input)
    }
        public func deleteApiKeys(_type: Components.Schemas.DeleteApiKeysRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.DeleteApiKeysIntent) async throws -> Operations.DeleteApiKeys.Output {
        let input = Operations.DeleteApiKeys.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.DeleteApiKeysRequest(_type: _type), Components.Schemas.DeleteApiKeysRequest(timestampMs: timestampMs), Components.Schemas.DeleteApiKeysRequest(organizationId: organizationId), Components.Schemas.DeleteApiKeysRequest(parameters: parameters))
        )
        return try await underlyingClient.DeleteApiKeys(input)
    }
        public func deleteAuthenticators(_type: Components.Schemas.DeleteAuthenticatorsRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.DeleteAuthenticatorsIntent) async throws -> Operations.DeleteAuthenticators.Output {
        let input = Operations.DeleteAuthenticators.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.DeleteAuthenticatorsRequest(_type: _type), Components.Schemas.DeleteAuthenticatorsRequest(timestampMs: timestampMs), Components.Schemas.DeleteAuthenticatorsRequest(organizationId: organizationId), Components.Schemas.DeleteAuthenticatorsRequest(parameters: parameters))
        )
        return try await underlyingClient.DeleteAuthenticators(input)
    }
        public func deleteInvitation(_type: Components.Schemas.DeleteInvitationRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.DeleteInvitationIntent) async throws -> Operations.DeleteInvitation.Output {
        let input = Operations.DeleteInvitation.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.DeleteInvitationRequest(_type: _type), Components.Schemas.DeleteInvitationRequest(timestampMs: timestampMs), Components.Schemas.DeleteInvitationRequest(organizationId: organizationId), Components.Schemas.DeleteInvitationRequest(parameters: parameters))
        )
        return try await underlyingClient.DeleteInvitation(input)
    }
        public func deletePolicy(_type: Components.Schemas.DeletePolicyRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.DeletePolicyIntent) async throws -> Operations.DeletePolicy.Output {
        let input = Operations.DeletePolicy.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.DeletePolicyRequest(_type: _type), Components.Schemas.DeletePolicyRequest(timestampMs: timestampMs), Components.Schemas.DeletePolicyRequest(organizationId: organizationId), Components.Schemas.DeletePolicyRequest(parameters: parameters))
        )
        return try await underlyingClient.DeletePolicy(input)
    }
        public func deletePrivateKeyTags(_type: Components.Schemas.DeletePrivateKeyTagsRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.DeletePrivateKeyTagsIntent) async throws -> Operations.DeletePrivateKeyTags.Output {
        let input = Operations.DeletePrivateKeyTags.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.DeletePrivateKeyTagsRequest(_type: _type), Components.Schemas.DeletePrivateKeyTagsRequest(timestampMs: timestampMs), Components.Schemas.DeletePrivateKeyTagsRequest(organizationId: organizationId), Components.Schemas.DeletePrivateKeyTagsRequest(parameters: parameters))
        )
        return try await underlyingClient.DeletePrivateKeyTags(input)
    }
        public func deleteUserTags(_type: Components.Schemas.DeleteUserTagsRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.DeleteUserTagsIntent) async throws -> Operations.DeleteUserTags.Output {
        let input = Operations.DeleteUserTags.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.DeleteUserTagsRequest(_type: _type), Components.Schemas.DeleteUserTagsRequest(timestampMs: timestampMs), Components.Schemas.DeleteUserTagsRequest(organizationId: organizationId), Components.Schemas.DeleteUserTagsRequest(parameters: parameters))
        )
        return try await underlyingClient.DeleteUserTags(input)
    }
        public func deleteUsers(_type: Components.Schemas.DeleteUsersRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.DeleteUsersIntent) async throws -> Operations.DeleteUsers.Output {
        let input = Operations.DeleteUsers.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.DeleteUsersRequest(_type: _type), Components.Schemas.DeleteUsersRequest(timestampMs: timestampMs), Components.Schemas.DeleteUsersRequest(organizationId: organizationId), Components.Schemas.DeleteUsersRequest(parameters: parameters))
        )
        return try await underlyingClient.DeleteUsers(input)
    }
        public func emailAuth(_type: Components.Schemas.EmailAuthRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.EmailAuthIntent) async throws -> Operations.EmailAuth.Output {
        let input = Operations.EmailAuth.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.EmailAuthRequest(_type: _type), Components.Schemas.EmailAuthRequest(timestampMs: timestampMs), Components.Schemas.EmailAuthRequest(organizationId: organizationId), Components.Schemas.EmailAuthRequest(parameters: parameters))
        )
        return try await underlyingClient.EmailAuth(input)
    }
        public func exportPrivateKey(_type: Components.Schemas.ExportPrivateKeyRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.ExportPrivateKeyIntent) async throws -> Operations.ExportPrivateKey.Output {
        let input = Operations.ExportPrivateKey.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.ExportPrivateKeyRequest(_type: _type), Components.Schemas.ExportPrivateKeyRequest(timestampMs: timestampMs), Components.Schemas.ExportPrivateKeyRequest(organizationId: organizationId), Components.Schemas.ExportPrivateKeyRequest(parameters: parameters))
        )
        return try await underlyingClient.ExportPrivateKey(input)
    }
        public func exportWallet(_type: Components.Schemas.ExportWalletRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.ExportWalletIntent) async throws -> Operations.ExportWallet.Output {
        let input = Operations.ExportWallet.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.ExportWalletRequest(_type: _type), Components.Schemas.ExportWalletRequest(timestampMs: timestampMs), Components.Schemas.ExportWalletRequest(organizationId: organizationId), Components.Schemas.ExportWalletRequest(parameters: parameters))
        )
        return try await underlyingClient.ExportWallet(input)
    }
        public func exportWalletAccount(_type: Components.Schemas.ExportWalletAccountRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.ExportWalletAccountIntent) async throws -> Operations.ExportWalletAccount.Output {
        let input = Operations.ExportWalletAccount.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.ExportWalletAccountRequest(_type: _type), Components.Schemas.ExportWalletAccountRequest(timestampMs: timestampMs), Components.Schemas.ExportWalletAccountRequest(organizationId: organizationId), Components.Schemas.ExportWalletAccountRequest(parameters: parameters))
        )
        return try await underlyingClient.ExportWalletAccount(input)
    }
        public func importPrivateKey(_type: Components.Schemas.ImportPrivateKeyRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.ImportPrivateKeyIntent) async throws -> Operations.ImportPrivateKey.Output {
        let input = Operations.ImportPrivateKey.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.ImportPrivateKeyRequest(_type: _type), Components.Schemas.ImportPrivateKeyRequest(timestampMs: timestampMs), Components.Schemas.ImportPrivateKeyRequest(organizationId: organizationId), Components.Schemas.ImportPrivateKeyRequest(parameters: parameters))
        )
        return try await underlyingClient.ImportPrivateKey(input)
    }
        public func importWallet(_type: Components.Schemas.ImportWalletRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.ImportWalletIntent) async throws -> Operations.ImportWallet.Output {
        let input = Operations.ImportWallet.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.ImportWalletRequest(_type: _type), Components.Schemas.ImportWalletRequest(timestampMs: timestampMs), Components.Schemas.ImportWalletRequest(organizationId: organizationId), Components.Schemas.ImportWalletRequest(parameters: parameters))
        )
        return try await underlyingClient.ImportWallet(input)
    }
        public func initImportPrivateKey(_type: Components.Schemas.InitImportPrivateKeyRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.InitImportPrivateKeyIntent) async throws -> Operations.InitImportPrivateKey.Output {
        let input = Operations.InitImportPrivateKey.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.InitImportPrivateKeyRequest(_type: _type), Components.Schemas.InitImportPrivateKeyRequest(timestampMs: timestampMs), Components.Schemas.InitImportPrivateKeyRequest(organizationId: organizationId), Components.Schemas.InitImportPrivateKeyRequest(parameters: parameters))
        )
        return try await underlyingClient.InitImportPrivateKey(input)
    }
        public func initImportWallet(_type: Components.Schemas.InitImportWalletRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.InitImportWalletIntent) async throws -> Operations.InitImportWallet.Output {
        let input = Operations.InitImportWallet.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.InitImportWalletRequest(_type: _type), Components.Schemas.InitImportWalletRequest(timestampMs: timestampMs), Components.Schemas.InitImportWalletRequest(organizationId: organizationId), Components.Schemas.InitImportWalletRequest(parameters: parameters))
        )
        return try await underlyingClient.InitImportWallet(input)
    }
        public func initUserEmailRecovery(_type: Components.Schemas.InitUserEmailRecoveryRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.InitUserEmailRecoveryIntent) async throws -> Operations.InitUserEmailRecovery.Output {
        let input = Operations.InitUserEmailRecovery.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.InitUserEmailRecoveryRequest(_type: _type), Components.Schemas.InitUserEmailRecoveryRequest(timestampMs: timestampMs), Components.Schemas.InitUserEmailRecoveryRequest(organizationId: organizationId), Components.Schemas.InitUserEmailRecoveryRequest(parameters: parameters))
        )
        return try await underlyingClient.InitUserEmailRecovery(input)
    }
        public func recoverUser(_type: Components.Schemas.RecoverUserRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.RecoverUserIntent) async throws -> Operations.RecoverUser.Output {
        let input = Operations.RecoverUser.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.RecoverUserRequest(_type: _type), Components.Schemas.RecoverUserRequest(timestampMs: timestampMs), Components.Schemas.RecoverUserRequest(organizationId: organizationId), Components.Schemas.RecoverUserRequest(parameters: parameters))
        )
        return try await underlyingClient.RecoverUser(input)
    }
        public func rejectActivity(_type: Components.Schemas.RejectActivityRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.RejectActivityIntent) async throws -> Operations.RejectActivity.Output {
        let input = Operations.RejectActivity.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.RejectActivityRequest(_type: _type), Components.Schemas.RejectActivityRequest(timestampMs: timestampMs), Components.Schemas.RejectActivityRequest(organizationId: organizationId), Components.Schemas.RejectActivityRequest(parameters: parameters))
        )
        return try await underlyingClient.RejectActivity(input)
    }
        public func removeOrganizationFeature(_type: Components.Schemas.RemoveOrganizationFeatureRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.RemoveOrganizationFeatureIntent) async throws -> Operations.RemoveOrganizationFeature.Output {
        let input = Operations.RemoveOrganizationFeature.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.RemoveOrganizationFeatureRequest(_type: _type), Components.Schemas.RemoveOrganizationFeatureRequest(timestampMs: timestampMs), Components.Schemas.RemoveOrganizationFeatureRequest(organizationId: organizationId), Components.Schemas.RemoveOrganizationFeatureRequest(parameters: parameters))
        )
        return try await underlyingClient.RemoveOrganizationFeature(input)
    }
        public func setOrganizationFeature(_type: Components.Schemas.SetOrganizationFeatureRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.SetOrganizationFeatureIntent) async throws -> Operations.SetOrganizationFeature.Output {
        let input = Operations.SetOrganizationFeature.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.SetOrganizationFeatureRequest(_type: _type), Components.Schemas.SetOrganizationFeatureRequest(timestampMs: timestampMs), Components.Schemas.SetOrganizationFeatureRequest(organizationId: organizationId), Components.Schemas.SetOrganizationFeatureRequest(parameters: parameters))
        )
        return try await underlyingClient.SetOrganizationFeature(input)
    }
        public func signRawPayload(_type: Components.Schemas.SignRawPayloadRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.SignRawPayloadIntentV2) async throws -> Operations.SignRawPayload.Output {
        let input = Operations.SignRawPayload.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.SignRawPayloadRequest(_type: _type), Components.Schemas.SignRawPayloadRequest(timestampMs: timestampMs), Components.Schemas.SignRawPayloadRequest(organizationId: organizationId), Components.Schemas.SignRawPayloadRequest(parameters: parameters))
        )
        return try await underlyingClient.SignRawPayload(input)
    }
        public func signRawPayloads(_type: Components.Schemas.SignRawPayloadsRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.SignRawPayloadsIntent) async throws -> Operations.SignRawPayloads.Output {
        let input = Operations.SignRawPayloads.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.SignRawPayloadsRequest(_type: _type), Components.Schemas.SignRawPayloadsRequest(timestampMs: timestampMs), Components.Schemas.SignRawPayloadsRequest(organizationId: organizationId), Components.Schemas.SignRawPayloadsRequest(parameters: parameters))
        )
        return try await underlyingClient.SignRawPayloads(input)
    }
        public func signTransaction(_type: Components.Schemas.SignTransactionRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.SignTransactionIntentV2) async throws -> Operations.SignTransaction.Output {
        let input = Operations.SignTransaction.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.SignTransactionRequest(_type: _type), Components.Schemas.SignTransactionRequest(timestampMs: timestampMs), Components.Schemas.SignTransactionRequest(organizationId: organizationId), Components.Schemas.SignTransactionRequest(parameters: parameters))
        )
        return try await underlyingClient.SignTransaction(input)
    }
        public func updatePolicy(_type: Components.Schemas.UpdatePolicyRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.UpdatePolicyIntent) async throws -> Operations.UpdatePolicy.Output {
        let input = Operations.UpdatePolicy.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.UpdatePolicyRequest(_type: _type), Components.Schemas.UpdatePolicyRequest(timestampMs: timestampMs), Components.Schemas.UpdatePolicyRequest(organizationId: organizationId), Components.Schemas.UpdatePolicyRequest(parameters: parameters))
        )
        return try await underlyingClient.UpdatePolicy(input)
    }
        public func updatePrivateKeyTag(_type: Components.Schemas.UpdatePrivateKeyTagRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.UpdatePrivateKeyTagIntent) async throws -> Operations.UpdatePrivateKeyTag.Output {
        let input = Operations.UpdatePrivateKeyTag.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.UpdatePrivateKeyTagRequest(_type: _type), Components.Schemas.UpdatePrivateKeyTagRequest(timestampMs: timestampMs), Components.Schemas.UpdatePrivateKeyTagRequest(organizationId: organizationId), Components.Schemas.UpdatePrivateKeyTagRequest(parameters: parameters))
        )
        return try await underlyingClient.UpdatePrivateKeyTag(input)
    }
        public func updateRootQuorum(_type: Components.Schemas.UpdateRootQuorumRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.UpdateRootQuorumIntent) async throws -> Operations.UpdateRootQuorum.Output {
        let input = Operations.UpdateRootQuorum.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.UpdateRootQuorumRequest(_type: _type), Components.Schemas.UpdateRootQuorumRequest(timestampMs: timestampMs), Components.Schemas.UpdateRootQuorumRequest(organizationId: organizationId), Components.Schemas.UpdateRootQuorumRequest(parameters: parameters))
        )
        return try await underlyingClient.UpdateRootQuorum(input)
    }
        public func updateUser(_type: Components.Schemas.UpdateUserRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.UpdateUserIntent) async throws -> Operations.UpdateUser.Output {
        let input = Operations.UpdateUser.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.UpdateUserRequest(_type: _type), Components.Schemas.UpdateUserRequest(timestampMs: timestampMs), Components.Schemas.UpdateUserRequest(organizationId: organizationId), Components.Schemas.UpdateUserRequest(parameters: parameters))
        )
        return try await underlyingClient.UpdateUser(input)
    }
        public func updateUserTag(_type: Components.Schemas.UpdateUserTagRequest._typePayload, timestampMs: String, organizationId: String, parameters: Components.Schemas.UpdateUserTagIntent) async throws -> Operations.UpdateUserTag.Output {
        let input = Operations.UpdateUserTag.Input(
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(Components.Schemas.UpdateUserTagRequest(_type: _type), Components.Schemas.UpdateUserTagRequest(timestampMs: timestampMs), Components.Schemas.UpdateUserTagRequest(organizationId: organizationId), Components.Schemas.UpdateUserTagRequest(parameters: parameters))
        )
        return try await underlyingClient.UpdateUserTag(input)
    }
}