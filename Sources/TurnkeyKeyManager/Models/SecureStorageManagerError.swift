import Foundation

public enum SecureStorageManagerError: Error {
  case keychainError(OSStatus)
  case stringEncodingFailed
}


