import Foundation

extension SessionManager {
  /// Clears any stored session data without throwing. Primarily used internally
  /// by the SDK when specific `TurnkeyError` cases arise.
  public static func resetShared() {
    do {
      try SessionManager.shared.deleteSession()
    } catch {
      // Swallow errors – reset is best-effort.
    }
  }
}
