import Foundation

public enum PasskeyError: Error {
    case invalidUserId
    case missingAttestationObject
    case registrationFailed(Error)
    case assertionFailed(Error)
    case invalidChallenge
    case unsupportedOperation
    case credentialConversionFailed
    
    public var localizedDescription: String {
        switch self {
        case .invalidUserId:
            return "Invalid user ID format"
        case .missingAttestationObject:
            return "Missing attestation object in registration"
        case .registrationFailed(let error):
            return "Registration failed: \(error.localizedDescription)"
        case .assertionFailed(let error):
            return "Assertion failed: \(error.localizedDescription)"
        case .invalidChallenge:
            return "Invalid challenge format"
        case .unsupportedOperation:
            return "Unsupported operation"
        case .credentialConversionFailed:
            return "Failed to convert credential data"
        }
    }
}