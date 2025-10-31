import AuthenticationServices
import Foundation

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
