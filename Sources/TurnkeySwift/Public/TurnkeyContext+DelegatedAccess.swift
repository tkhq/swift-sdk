import Foundation
import TurnkeyTypes
import TurnkeyHttp

public struct CreateP256ApiKeyUserParams: Sendable {
    public var userName: String?
    public var apiKeyName: String?
    
    public init(userName: String? = nil, apiKeyName: String? = nil) {
        self.userName = userName
        self.apiKeyName = apiKeyName
    }
}

public struct FetchOrCreatePolicyResultItem: Codable, Sendable {
    public let policyId: String
    public let policyName: String
    public let effect: v1Effect
    public let condition: String?
    public let consensus: String?
    public let notes: String?
    
    public init(
        policyId: String,
        policyName: String,
        effect: v1Effect,
        condition: String? = nil,
        consensus: String? = nil,
        notes: String? = nil
    ) {
        self.policyId = policyId
        self.policyName = policyName
        self.effect = effect
        self.condition = condition
        self.consensus = consensus
        self.notes = notes
    }
}

extension TurnkeyContext {
    
    /// Fetches an existing user by P-256 API key public key, or creates a new one if none exists.
    ///
    /// - Parameters:
    ///   - publicKey: The P-256 public key to use for lookup and creation.
    ///   - createParams: Optional params to customize created user/api key names.
    ///   - organizationId: Optional organization override. Defaults to active session org.
    /// - Returns: The existing or newly created `v1User`.
    public func fetchOrCreateP256ApiKeyUser(
        publicKey: String,
        createParams: CreateP256ApiKeyUserParams? = nil,
        organizationId: String? = nil
    ) async throws -> v1User {
        guard
            authState == .authenticated,
            let client = client
        else {
            throw TurnkeySwiftError.invalidSession
        }
        
        let trimmedPublicKey = publicKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPublicKey.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration("'publicKey' is required and cannot be empty.")
        }
        
        let orgId = organizationId ?? self.session?.organizationId
        guard let orgId else {
            throw TurnkeySwiftError.invalidSession
        }
        
        // attempt to find an existing user with this P-256 API key
        let usersResp = try await client.getUsers(TGetUsersBody(organizationId: orgId))
        if let existing = usersResp.users.first(where: { user in
            user.apiKeys.contains(where: { apiKey in
                apiKey.credential.publicKey == trimmedPublicKey &&
                apiKey.credential.type == .credential_type_api_key_p256
            })
        }) {
            return existing
        }
        
        // not found, create a new user with this API key
        let userName = (createParams?.userName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Public Key User"
        let apiKeyName = (createParams?.apiKeyName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "public-key-user-\(trimmedPublicKey)"
        
        let apiKeyParams = v1ApiKeyParamsV2(
            apiKeyName: apiKeyName,
            curveType: .api_key_curve_p256,
            expirationSeconds: nil,
            publicKey: trimmedPublicKey
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
    /// - Parameters:
    ///   - policies: The list of policies to fetch or create.
    ///   - organizationId: Optional organization override. Defaults to active session org.
    /// - Returns: Array of result items containing policyId and original fields.
    public func fetchOrCreatePolicies(
        policies: [v1CreatePolicyIntentV3],
        organizationId: String? = nil
    ) async throws -> [FetchOrCreatePolicyResultItem] {
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
        
        var alreadyExisting: [FetchOrCreatePolicyResultItem] = []
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
        
        let newlyCreated: [FetchOrCreatePolicyResultItem] = zip(missing, createdIds).map { (intent, policyId) in
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


