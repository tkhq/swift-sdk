import Foundation
import Security

extension SecureStorageManager {
  static func accessibilityConstant(_ a: Config.Accessibility) -> CFString {
    switch a {
    case .whenUnlockedThisDeviceOnly:
      return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    case .afterFirstUnlockThisDeviceOnly:
      return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    case .whenPasscodeSetThisDeviceOnly:
      return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
    }
  }

  static func makeAccessControl(from config: Config) -> SecAccessControl? {
    guard config.accessControlPolicy != .none else { return nil }
    var flags: SecAccessControlCreateFlags = []
    switch config.accessControlPolicy {
    case .none:
      flags = []
    case .userPresence:
      flags = [.userPresence]
    case .biometryAny:
      flags = [.biometryAny]
    case .biometryCurrentSet:
      flags = [.biometryCurrentSet]
    case .devicePasscode:
      flags = [.devicePasscode]
    }
    var error: Unmanaged<CFError>?
    let access = SecAccessControlCreateWithFlags(
      kCFAllocatorDefault,
      accessibilityConstant(config.accessibility),
      flags,
      &error
    )
    return access
  }
}


