import AuthenticationServices
import Foundation

public struct RelyingParty {
  public let id: String
  public let name: String

  public init(id: String, name: String) {
    self.id = id
    self.name = name
  }
}

public struct PasskeyUser {
  public let id: String
  public let name: String
  public let displayName: String

  public init(id: String, name: String, displayName: String) {
    self.id = id
    self.name = name
    self.displayName = displayName
  }
}

public enum Transport: String, Codable {
  case ble = "AUTHENTICATOR_TRANSPORT_BLE"
  case internalTransport = "AUTHENTICATOR_TRANSPORT_INTERNAL"
  case nfc = "AUTHENTICATOR_TRANSPORT_NFC"
  case usb = "AUTHENTICATOR_TRANSPORT_USB"
  case hybrid = "AUTHENTICATOR_TRANSPORT_HYBRID"
}

public struct Attestation: Codable {
  public let credentialId: String
  public let clientDataJson: String
  public let attestationObject: String
  public let transports: [Transport]
}

public struct PasskeyRegistrationResult: Codable {
  public let challenge: String
  public let attestation: Attestation
}

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
