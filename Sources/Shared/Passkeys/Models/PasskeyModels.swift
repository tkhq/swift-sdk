import Foundation
import AuthenticationServices

public struct RelyingParty {
    public let id: String
    public let name: String
    
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct PasskeyUser {
    public let id: String
    public let name: String
    public let displayName: String
    
    public init(id: String, name: String, displayName: String) {
        self.id = id
        self.name = name
        self.displayName = displayName
    }
}

public struct Attestation {
    public let credentialId: String
    public let clientDataJSON: String
    public let attestationObject: String
}

public struct PasskeyRegistrationResult {
    public let challenge: String
    public let attestation: Attestation
}

public struct AssertionResult {
    public let credentialId: String
    public let userId: String
    public let signature: Data
    public let authenticatorData: Data
    public let clientDataJSON: String
}

public enum AuthenticatorType {
    case platformKey
    case securityKey
}