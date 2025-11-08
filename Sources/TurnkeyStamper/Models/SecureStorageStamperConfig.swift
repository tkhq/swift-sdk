import Foundation

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


