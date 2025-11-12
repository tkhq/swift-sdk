import Foundation
import AuthenticationServices

/// Public configuration for API key–backed stamping.
public struct ApiKeyStamperConfig: Sendable {
  public let apiPublicKey: String
  public let apiPrivateKey: String

  public init(apiPublicKey: String, apiPrivateKey: String) {
    self.apiPublicKey = apiPublicKey
    self.apiPrivateKey = apiPrivateKey
  }
}

/// Public configuration for passkey-based stamping.
///
/// Note: `ASPresentationAnchor` is not `Sendable`; this type uses `@unchecked Sendable`.
public struct PasskeyStamperConfig: @unchecked Sendable {
  public let rpId: String
  public let presentationAnchor: ASPresentationAnchor

  public init(rpId: String, presentationAnchor: ASPresentationAnchor) {
    self.rpId = rpId
    self.presentationAnchor = presentationAnchor
  }
}

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

/// Public configuration for Secure Storage (Keychain)-backed key storage and access.
public struct SecureStorageStamperConfig: Sendable {
  public enum Accessibility: Sendable {
    case whenUnlockedThisDeviceOnly
    case afterFirstUnlockThisDeviceOnly
    case whenPasscodeSetThisDeviceOnly
  }

  public enum AccessControlPolicy: Sendable {
    case none
    case userPresence
    case biometryAny
    case biometryCurrentSet
    case devicePasscode
  }

  public let accessibility: Accessibility
  public let accessControlPolicy: AccessControlPolicy
  public let authPrompt: String?
  public let biometryReuseWindowSeconds: Int
  public let synchronizable: Bool
  public let accessGroup: String?

  public init(
    accessibility: Accessibility = .afterFirstUnlockThisDeviceOnly,
    accessControlPolicy: AccessControlPolicy = .none,
    authPrompt: String? = nil,
    biometryReuseWindowSeconds: Int = 0,
    synchronizable: Bool = false,
    accessGroup: String? = nil
  ) {
    self.accessibility = accessibility
    self.accessControlPolicy = accessControlPolicy
    self.authPrompt = authPrompt
    self.biometryReuseWindowSeconds = biometryReuseWindowSeconds
    self.synchronizable = synchronizable
    self.accessGroup = accessGroup
  }
}

/// Type-erased configuration carried by a `Stamper` instance.
public enum StamperConfiguration: @unchecked Sendable {
  case apiKey(ApiKeyStamperConfig)
  case passkey(PasskeyStamperConfig)
  case secureEnclave(SecureEnclaveStamperConfig)
  case secureStorage(SecureStorageStamperConfig)
}


