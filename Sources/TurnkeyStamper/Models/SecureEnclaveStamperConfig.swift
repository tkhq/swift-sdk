import Foundation

/// Public configuration for Secure Enclave key creation and usage policies.
public struct SecureEnclaveStamperConfig: Sendable {
  public enum AuthPolicy: Sendable {
    case none
    case userPresence
    case biometryAny
    case biometryCurrentSet
  }

  public let authPolicy: AuthPolicy

  public init(authPolicy: AuthPolicy = .none) {
    self.authPolicy = authPolicy
  }
}


