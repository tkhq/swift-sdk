import Foundation
import TurnkeyTypes
import TurnkeyHttp

extension TurnkeyContext {
    
    /// Fetches an existing user by P-256 API key public key, or creates a new one if none exists.
    ///
    /// - Parameters:
    ///   - params: Params containing the P-256 public key and desired user/api key names.
    ///   - organizationId: Optional organization override. Defaults to active session org.
    /// - Returns: The existing or newly created `v1User`.
    public func fetchOrCreateP256ApiKeyUser(
        params: CreateP256ApiKeyUserParams,
        organizationId: String? = nil
    ) async throws -> v1User {
        guard
            authState == .authenticated,
            let client = client
        else {
            throw TurnkeySwiftError.invalidSession
        }
        
        let orgId = organizationId ?? self.session?.organizationId
        guard let orgId else {
            throw TurnkeySwiftError.invalidSession
        }
        
        // attempt to find an existing user with this P-256 API key
        let usersResp = try await client.getUsers(TGetUsersBody(organizationId: orgId))
        if let existing = usersResp.users.first(where: { user in
            user.apiKeys.contains(where: { apiKey in
                apiKey.credential.publicKey == params.publicKey &&
                apiKey.credential.type == .credential_type_api_key_p256
            })
        }) {
            return existing
        }
        
        // not found, create a new user with this API key
        let userName = params.userName.isEmpty ? "Public Key User" : params.userName
        let apiKeyName = params.apiKeyName.isEmpty ? "public-key-user-\(params.publicKey)" : params.apiKeyName
        
        let apiKeyParams = v1ApiKeyParamsV2(
            apiKeyName: apiKeyName,
            curveType: .api_key_curve_p256,
            expirationSeconds: nil,
            publicKey: params.publicKey
        )
        
        let createParamsV3 = v1UserParamsV3(
            apiKeys: [apiKeyParams],
            authenticators: [],
            oauthProviders: [],
            userEmail: nil,
            userName: userName,
            userPhoneNumber: nil,
            userTags: []
        )
        
        let createResp = try await client.createUsers(TCreateUsersBody(
            organizationId: orgId,
            users: [createParamsV3]
        ))
        
        guard let newUserId = createResp.userIds.first, !newUserId.isEmpty else {
            throw TurnkeySwiftError.invalidResponse
        }
        
        let userResp = try await client.getUser(TGetUserBody(
            organizationId: orgId,
            userId: newUserId
        ))
        return userResp.user
    }
    
    /// Fetches each requested policy if it exists, or creates it if it does not.
    ///
    /// This function is idempotent:
    /// - Multiple calls with the same `policies` will not create duplicates.
    /// - For every policy in the request:
    ///   - If it already exists, it is returned with its `policyId`.
    ///   - If it does not exist, it is created and returned with its new `policyId`.
    ///
    /// - Parameters:
    ///   - policies: The list of policies to fetch or create.
    ///   - organizationId: Optional organization override. Defaults to the current session's `organizationId`.
    /// - Returns: An array of items where each contains:
    ///   - `policyId`: The unique identifier of the policy.
    ///   - `policyName`: Human-readable name of the policy.
    ///   - `effect`: The instruction to DENY or ALLOW an activity.
    ///   - `condition`: Optional condition expression that triggers the effect.
    ///   - `consensus`: Optional consensus expression that triggers the effect.
    ///   - `notes`: Optional developer notes or description for the policy.
    /// - Throws: If there is no active session, if the input is invalid,
    ///           if fetching existing policies fails, or if creating policies fails.
    public func fetchOrCreatePolicies(
        policies: [v1CreatePolicyIntentV3],
        organizationId: String? = nil
    ) async throws -> [Policy] {
        guard
            authState == .authenticated,
            let client = client
        else {
            throw TurnkeySwiftError.invalidSession
        }
        
        guard !policies.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration("'policies' must be a non-empty array of policy definitions.")
        }
        
        let orgId = organizationId ?? self.session?.organizationId
        guard let orgId else {
            throw TurnkeySwiftError.invalidSession
        }
        
        let existingResp = try await client.getPolicies(TGetPoliciesBody(organizationId: orgId))
        let existing = existingResp.policies
        
        var existingBySignature: [String: String] = [:] // signature -> policyId
        for p in existing {
            existingBySignature[policySignature(p)] = p.policyId
        }
        
        var alreadyExisting: [Policy] = []
        var missing: [v1CreatePolicyIntentV3] = []
        
        for intent in policies {
            let sig = policySignature(intent)
            if let policyId = existingBySignature[sig] {
                alreadyExisting.append(
                    .init(
                        policyId: policyId,
                        policyName: intent.policyName,
                        effect: intent.effect,
                        condition: intent.condition,
                        consensus: intent.consensus,
                        notes: intent.notes
                    )
                )
            } else {
                missing.append(intent)
            }
        }
        
        if missing.isEmpty {
            return alreadyExisting
        }
        
        let createResp = try await client.createPolicies(TCreatePoliciesBody(
            organizationId: orgId,
            policies: missing
        ))
        
        let createdIds = createResp.policyIds
        guard createdIds.count == missing.count else {
            throw TurnkeySwiftError.invalidResponse
        }
        
        let newlyCreated: [Policy] = zip(missing, createdIds).map { (intent, policyId) in
            .init(
                policyId: policyId,
                policyName: intent.policyName,
                effect: intent.effect,
                condition: intent.condition,
                consensus: intent.consensus,
                notes: intent.notes
            )
        }
        
        return alreadyExisting + newlyCreated
    }
    
    // MARK: - Helpers
    private func policySignature(_ policy: v1Policy) -> String {
        [
            policy.policyName,
            policy.effect.rawValue,
            policy.condition,
            policy.consensus,
            policy.notes
        ].joined(separator: "|")
    }
    
    private func policySignature(_ intent: v1CreatePolicyIntentV3) -> String {
        [
            intent.policyName,
            intent.effect.rawValue,
            intent.condition ?? "",
            intent.consensus ?? "",
            intent.notes ?? ""
        ].joined(separator: "|")
    }
}


