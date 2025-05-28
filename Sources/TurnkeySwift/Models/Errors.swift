import Foundation

enum SessionStoreError: Error {
  case keyGenerationFailed(Error)
  case keyIndexFailed(status: OSStatus)
  case keyNotFound
  case keychainAddFailed(status: OSStatus)
  case publicKeyMissing
  case signingNotSupported
  case invalidJWT
  case invalidResponse
  case invalidSession
}
