import Foundation

enum StorageError: Error {
    case keychainAddFailed(status: OSStatus)
    case keychainFetchFailed(status: OSStatus)
    case keychainDeleteFailed(status: OSStatus)
    case invalidJWT
    case encodingFailed(key: String, underlying: Error)
    case decodingFailed(key: String, underlying: Error)
}

enum TurnkeySwiftError: Error {
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
    
    case oauthInvalidURL
    case oauthMissingIDToken
    case oauthFailed(underlying: Error)

}
