import Foundation
import TurnkeyTypes

public struct CreateP256ApiKeyUserParams: Sendable {
    public var userName: String
    public var apiKeyName: String
    public var publicKey: String
    
    public init(userName: String, apiKeyName: String, publicKey: String) throws {
        let trimmedPublicKey = publicKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPublicKey.isEmpty else {
            throw TurnkeySwiftError.invalidConfiguration(
                "'publicKey' is required and cannot be empty."
            )
        }
        self.userName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKeyName = apiKeyName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.publicKey = trimmedPublicKey
    }
}

public struct Policy: Codable, Sendable {
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


