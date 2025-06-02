import Combine
import CryptoKit
import Foundation
import TurnkeyHttp

public final class TurnkeyContext: ObservableObject {

  // public state
  @Published public internal(set) var client: TurnkeyClient?
  @Published public internal(set) var selectedSessionKey: String?
  @Published public internal(set) var user: SessionUser?

  // internal state
  internal var expiryTasks: [String: Task<Void, Never>] = [:]
  internal let apiUrl: String

  // configurable base URL
  private static var _apiUrl: String = Constants.Turnkey.defaultApiUrl

  public static func configure(apiUrl: String) {
    _apiUrl = apiUrl
  }

  public static let shared: TurnkeyContext = TurnkeyContext(apiUrl: _apiUrl)

  private init(apiUrl: String = Constants.Turnkey.defaultApiUrl) {
    self.apiUrl = apiUrl

    // clean up expired sessions and pending keys
    PendingKeysStore.purge(ttlHours: 2)
    SessionRegistryStore.purgeExpiredSessions()

    // restore session and timers after launch
    Task { [weak self] in
      await self?.rescheduleAllSessionExpiries()
      await self?.restoreSelectedSession()
    }

    // clean up periodically when app enters foreground
    if let note = Self.foregroundNotification {
      Task.detached {
        for await _ in NotificationCenter.default.notifications(named: note) {
          PendingKeysStore.purge(ttlHours: 1)
          SessionRegistryStore.purgeExpiredSessions()
        }
      }
    }
  }
}
