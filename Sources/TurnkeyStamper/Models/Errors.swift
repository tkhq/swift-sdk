import Foundation

public enum ApiKeyStampError: Error {
  case invalidPrivateKey
  case invalidPublicKey
  case mismatchedPublicKey(expected: String, actual: String)
  case invalidHexCharacter
  case signatureFailed
  case failedToSerializePayloadToJSON(Error)

  public var localizedDescription: String {
    switch self {
    case .invalidPrivateKey:
      return "Invalid private key format. Make sure it's a valid hex string."
    case .invalidPublicKey:
      return "Invalid public key format."
    case .mismatchedPublicKey(let expected, let actual):
      return "Mismatched public key. Expected: \(expected), but got: \(actual)."
    case .invalidHexCharacter:
      return "The provided hex string contains invalid characters."
    case .signatureFailed:
      return "Failed to generate signature using the private key."
    case .failedToSerializePayloadToJSON(let error):
      return "Could not convert payload to JSON: \(error.localizedDescription)"
    }
  }
}

public enum PasskeyStampError: Error {
  case invalidChallenge
  case assertionFailed(Error)
  case failedToEncodeStamp(Error)
  case invalidJSONString

  public var localizedDescription: String {
    switch self {
    case .invalidChallenge:
      return "Failed to encode the challenge as UTF-8 data."
    case .assertionFailed(let error):
      return "Passkey assertion failed: \(error.localizedDescription)"
    case .failedToEncodeStamp(let error):
      return "Failed to encode WebAuthn stamp as JSON: \(error.localizedDescription)"
    case .invalidJSONString:
      return "Unable to convert the stamp JSON data to a UTF-8 string."
    }
  }
}

public enum StampError: Error {
  case missingCredentials
  case assertionFailed
  case apiKeyStampError(ApiKeyStampError)
  case passkeyStampError(PasskeyStampError)
  case unknownError(String)
  case passkeyManagerNotSet
  case invalidPayload
  case secureEnclaveUnavailable
  case keyNotFound(publicKeyHex: String)

  public var localizedDescription: String {
    switch self {
    case .missingCredentials:
      return "Missing credentials. Please ensure API or passkey credentials are configured."
    case .assertionFailed:
      return "Failed to complete passkey assertion."
    case .apiKeyStampError(let error):
      return error.localizedDescription
    case .passkeyStampError(let error):
      return error.localizedDescription
    case .unknownError(let message):
      return "An unknown error occurred: \(message)"
    case .passkeyManagerNotSet:
      return "Passkey manager has not been initialized."
    case .invalidPayload:
      return "Invalid payload provided for stamping."
    case .secureEnclaveUnavailable:
      return "Secure Enclave is not available on this device."
    case .keyNotFound(let publicKeyHex):
      return "No private key found for public key: \(publicKeyHex)"
    }
  }
}

enum SecureEnclaveStamperError: Error, Equatable {
  case secureEnclaveUnavailable
  case keychainError(OSStatus)
  case keyGenerationFailed(Error?)
  case keyNotFound(publicKeyHex: String)
  case publicKeyEncodingFailed
  case unsupportedAlgorithm
  case payloadEncodingFailed
  case externalKeyImportNotSupported
}

extension SecureEnclaveStamperError {
  static func == (lhs: SecureEnclaveStamperError, rhs: SecureEnclaveStamperError) -> Bool {
    switch (lhs, rhs) {
    case (.secureEnclaveUnavailable, .secureEnclaveUnavailable):
      return true
    case let (.keychainError(a), .keychainError(b)):
      return a == b
    case (.keyGenerationFailed, .keyGenerationFailed):
      // Compare only by case; underlying Error? is not Equatable
      return true
    case let (.keyNotFound(a), .keyNotFound(b)):
      return a == b
    case (.publicKeyEncodingFailed, .publicKeyEncodingFailed):
      return true
    case (.unsupportedAlgorithm, .unsupportedAlgorithm):
      return true
    case (.payloadEncodingFailed, .payloadEncodingFailed):
      return true
    case (.externalKeyImportNotSupported, .externalKeyImportNotSupported):
      return true
    default:
      return false
    }
  }
}
enum SecureStorageStamperError: Error, Equatable {
  case keychainError(OSStatus)
  case privateKeyNotFound(publicKeyHex: String)
  case stringEncodingFailed
  case payloadEncodingFailed
}
