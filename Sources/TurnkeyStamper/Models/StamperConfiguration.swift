import Foundation

/// Type-erased configuration carried by a `Stamper` instance.
public enum StamperConfiguration: @unchecked Sendable {
  case apiKey(ApiKeyStamperConfig)
  case passkey(PasskeyStamperConfig)
  case secureEnclave(SecureEnclaveStamperConfig)
  case secureStorage(SecureStorageStamperConfig)
}


