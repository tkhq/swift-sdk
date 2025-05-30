import Foundation
import TurnkeyHttp

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

extension TurnkeyContext {

  /// Returns the appropriate notification that fires when the app returns to foreground.
  ///
  /// - Returns: The notification name for foreground entry on supported platforms.
  static var foregroundNotification: Notification.Name? {
    #if os(iOS) || os(tvOS) || os(visionOS)
    UIApplication.willEnterForegroundNotification
    #elseif os(macOS)
    NSApplication.didBecomeActiveNotification
    #else
    nil
    #endif
  }

  /// Attempts to restore the most recently selected session on app launch or resume.
  ///
  /// Loads the selected session key from persistent storage and re-establishes the client/user state if valid.
  func restoreSelectedSession() async {
    do {
      guard let sessionKey = try SelectedSessionStore.load(),
            (try? JwtSessionStore.load(key: sessionKey)) != nil
      else { return }

      _ = try? await setSelectedSession(sessionKey: sessionKey)
    } catch {
      // Silently fail
    }
  }

  /// Reschedules expiry timers for all persisted sessions.
  ///
  /// Iterates over all stored session keys and schedules timers based on JWT expiration.
  func rescheduleAllSessionExpiries() async {
    do {
      for key in try SessionRegistryStore.all() {
        guard let dto = try? JwtSessionStore.load(key: key) else { continue }
        scheduleExpiryTimer(for: key, expTimestamp: dto.exp)
      }
    } catch {
      // Silently fail
    }
  }

  /// Sets up a timer that will automatically clear the session when the JWT expires.
  ///
  /// - Parameters:
  ///   - sessionKey: The session key to track.
  ///   - expTimestamp: The expiration timestamp of the session JWT.
  func scheduleExpiryTimer(for sessionKey: String, expTimestamp: TimeInterval) {
    expiryTasks[sessionKey]?.cancel()

    // we add a 5s buffer
    let delay = expTimestamp - Date().timeIntervalSince1970 - 5
    guard delay > 0 else {
      clearSession(for: sessionKey)
      return
    }

    expiryTasks[sessionKey] = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      self?.clearSession(for: sessionKey)
    }
  }

  /// Fetches the current session user's full profile and associated wallets.
  ///
  /// - Parameters:
  ///   - client: The `TurnkeyClient` instance for API calls.
  ///   - organizationId: The organization ID associated with the session.
  ///   - userId: The user ID to retrieve.
  /// - Returns: A fully populated `SessionUser` object containing user metadata and wallet accounts.
  func fetchSessionUser(
    using client: TurnkeyClient,
    organizationId: String,
    userId: String
  ) async throws -> SessionUser {
    guard !organizationId.isEmpty, !userId.isEmpty else {
      throw TurnkeySwiftError.invalidResponse
    }

    do {
      // run user and wallets requests in parallel
      async let userResp = client.getUser(organizationId: organizationId, userId: userId)
      async let walletsResp = client.getWallets(organizationId: organizationId)

      let user = try await userResp.body.json.user
      let wallets = try await walletsResp.body.json.wallets

      // fetch wallet accounts concurrently
      let detailed = try await withThrowingTaskGroup(of: SessionUser.UserWallet.self) { group in
        for w in wallets {
          group.addTask {
            let accounts = try await client.getWalletAccounts(
              organizationId: organizationId,
              walletId: w.walletId,
              paginationOptions: nil
            ).body.json.accounts.map {
              SessionUser.UserWallet.WalletAccount(
                id: $0.walletAccountId,
                curve: $0.curve,
                pathFormat: $0.pathFormat,
                path: $0.path,
                addressFormat: $0.addressFormat,
                address: $0.address,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
              )
            }
            return SessionUser.UserWallet(id: w.walletId, name: w.walletName, accounts: accounts)
          }
        }

        var res: [SessionUser.UserWallet] = []
        for try await item in group { res.append(item) }
        return res
      }

      return SessionUser(
        id: user.userId,
        userName: user.userName,
        email: user.userEmail,
        phoneNumber: user.userPhoneNumber,
        organizationId: organizationId,
        wallets: detailed
      )

    } catch {
      throw error
    }
  }
}
