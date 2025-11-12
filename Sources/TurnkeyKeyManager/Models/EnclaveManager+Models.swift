import Foundation
import Security
import TurnkeyCrypto

public extension EnclaveManager {
  enum EnclaveManagerError: Error {
    case secureEnclaveUnavailable
    case keyGenerationFailed(Error?)
    case unsupportedAlgorithm
    case keyNotFound(String)
    case keychainError(OSStatus)
    case payloadEncodingFailed
  }

  enum AuthPolicy {
    case none
    case userPresence
    case biometryAny
    case biometryCurrentSet
  }

  struct KeyPair: Sendable {
    public let publicKeyHex: String
    public init(publicKeyHex: String) {
      self.publicKeyHex = publicKeyHex
    }
  }
}


