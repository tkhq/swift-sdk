import Foundation
import TurnkeyHttp

public enum StorageError: LocalizedError, Sendable {
    case keychainAddFailed(status: OSStatus)
    case keychainFetchFailed(status: OSStatus)
    case keychainDeleteFailed(status: OSStatus)
    case invalidJWT
    case encodingFailed(key: String, underlying: Error)
    case decodingFailed(key: String, underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .keychainAddFailed(let status):
            return "Keychain add operation failed with status \(status)."
        case .keychainFetchFailed(let status):
            return "Keychain fetch operation failed with status \(status)."
        case .keychainDeleteFailed(let status):
            return "Keychain delete operation failed with status \(status)."
        case .invalidJWT:
            return "Invalid JWT format."
        case .encodingFailed(let key, let underlying):
            return "Failed to encode value for key '\(key)': \(underlying.localizedDescription)"
        case .decodingFailed(let key, let underlying):
            return "Failed to decode value for key '\(key)': \(underlying.localizedDescription)"
        }
    }
}

public enum TurnkeySwiftError: LocalizedError, Sendable {
    case keyGenerationFailed(Error)
    case keyIndexFailed(status: OSStatus)
    case keyAlreadyExists
    case keyNotFound
    case keychainAddFailed(status: OSStatus)
    case publicKeyMissing
    case signingNotSupported
    case invalidJWT
    case invalidResponse
    case invalidSession
    case invalidRefreshTTL(String)
    case invalidConfiguration(String)

    case failedToSignPayload(underlying: Error)
    case failedToCreateSession(underlying: Error)
    case failedToClearSession(underlying: Error)
    case failedToRefreshSession(underlying: Error)
    case failedToRefreshUser(underlying: Error)
    case failedToSetSelectedSession(underlying: Error)
    case failedToCreateWallet(underlying: Error)
    case failedToExportWallet(underlying: Error)
    case failedToImportWallet(underlying: Error)
    case failedToUpdateUser(underlying: Error)
    case failedToUpdateUserEmail(underlying: Error)
    case failedToUpdateUserPhoneNumber(underlying: Error)
    case failedToLoginWithPasskey(underlying: Error)
    case failedToInitOtp(underlying: Error)
    case failedToVerifyOtp(underlying: Error)
    case failedToLoginWithOtp(underlying: Error)

    case oauthInvalidURL
    case oauthMissingIDToken
    case oauthFailed(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .keyAlreadyExists: return "Key already exists."
        case .keyNotFound: return "Key not found."
        case .publicKeyMissing: return "Missing public key."
        case .signingNotSupported: return "Signing is not supported for this key."
        case .invalidJWT: return "Invalid JWT format."
        case .invalidResponse: return "Invalid response from server."
        case .invalidSession: return "Session is invalid or expired."
        case .invalidConfiguration(let msg): return "Invalid configuration: \(msg)"
        case .oauthInvalidURL: return "OAuth flow failed: invalid URL."
        case .oauthMissingIDToken: return "OAuth flow failed: missing ID token."

        case .keyIndexFailed(let status):
            return "Failed to retrieve key index (OSStatus: \(status))."
        case .keychainAddFailed(let status):
            return "Keychain add operation failed (OSStatus: \(status))."

        case .keyGenerationFailed(let e),
             .failedToSignPayload(let e),
             .failedToCreateSession(let e),
             .failedToClearSession(let e),
             .failedToRefreshSession(let e),
             .failedToRefreshUser(let e),
             .failedToSetSelectedSession(let e),
             .failedToCreateWallet(let e),
             .failedToExportWallet(let e),
             .failedToImportWallet(let e),
             .failedToUpdateUser(let e),
             .failedToUpdateUserEmail(let e),
             .failedToUpdateUserPhoneNumber(let e),
             .failedToLoginWithPasskey(let e),
             .failedToInitOtp(let e),
             .failedToVerifyOtp(let e),
             .failedToLoginWithOtp(let e),
             .oauthFailed(let e):

            // prefer rich TurnkeyRequestError message when available
            if let turnkeyError = e as? TurnkeyRequestError {
                return turnkeyError.fullMessage
            }
            return e.localizedDescription

        case .invalidRefreshTTL(let ttl):
            return "Invalid refresh TTL: \(ttl)"
        }
    }

    // underlying TurnkeyRequestError extraction
    public var underlyingTurnkeyError: TurnkeyRequestError? {
        switch self {
        case .keyGenerationFailed(let e),
             .failedToSignPayload(let e),
             .failedToCreateSession(let e),
             .failedToClearSession(let e),
             .failedToRefreshSession(let e),
             .failedToRefreshUser(let e),
             .failedToSetSelectedSession(let e),
             .failedToCreateWallet(let e),
             .failedToExportWallet(let e),
             .failedToImportWallet(let e),
             .failedToUpdateUser(let e),
             .failedToUpdateUserEmail(let e),
             .failedToUpdateUserPhoneNumber(let e),
             .failedToLoginWithPasskey(let e),
             .failedToInitOtp(let e),
             .failedToVerifyOtp(let e),
             .failedToLoginWithOtp(let e),
             .oauthFailed(let e):
            return e as? TurnkeyRequestError
        default:
            return nil
        }
    }
}

extension Error {
    /// returns any TurnkeyRequestError found within the error chain
    public var turnkeyRequestError: TurnkeyRequestError? {
        if let e = self as? TurnkeyRequestError { return e }
        if let swiftError = self as? TurnkeySwiftError {
            return swiftError.underlyingTurnkeyError
        }
        return nil
    }
}
