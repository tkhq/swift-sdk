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
            else {
                // if we fail that means the selected session expired
                // so we delete it from the SelectedSessionStore
                SelectedSessionStore.delete()
                await MainActor.run { self.authState = .unAuthenticated }
                return
            }
            
            await MainActor.run { self.authState = .authenticated }
            _ = try? await setSelectedSession(sessionKey: sessionKey)
        } catch {
            await MainActor.run { self.authState = .unAuthenticated }
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
    
    /// Schedules an expiry timer to automatically refresh or clear a session when its JWT expires.
    ///
    /// - Parameters:
    ///   - sessionKey: The key identifying the session to monitor.
    ///   - expTimestamp: The UNIX timestamp (in seconds) when the JWT expires.
    ///   - buffer: Seconds to subtract from the expiry time to fire early (default is 5 seconds)
    func scheduleExpiryTimer(
        for sessionKey: String,
        expTimestamp: TimeInterval,
        buffer: TimeInterval = 5
    ) {
        // cancel any old timer
        expiryTasks[sessionKey]?.cancel()

        let timeLeft = expTimestamp - Date().timeIntervalSince1970

        // if already within (or past) the buffer window, we just clear now
        if timeLeft <= buffer {
            clearSession(for: sessionKey)
            return
        }

        let interval = timeLeft - buffer
        let deadline = DispatchTime.now() + .milliseconds(Int(interval * 1_000))
        let timer = DispatchSource.makeTimerSource()

        timer.schedule(deadline: deadline, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }

            // we calculate how much time is left when this handler actually runs
            // this is needed because if the app was backgrounded past the expiry,
            // the dispatch timer will still fire once the app returns to foreground
            // this avoids making a call we know will fail
            let currentLeft = expTimestamp - Date().timeIntervalSince1970
            if currentLeft <= 0 {
                self.clearSession(for: sessionKey)
                timer.cancel()
                return
            }

            if let dur = AutoRefreshStore.durationSeconds(for: sessionKey) {
                Task {
                    do {
                        try await self.refreshSession(
                            expirationSeconds: dur,
                            sessionKey: sessionKey
                        )
                    } catch {
                        self.clearSession(for: sessionKey)
                    }
                }
            } else {
                self.clearSession(for: sessionKey)
            }

            timer.cancel()
        }

        timer.resume()
        expiryTasks[sessionKey] = timer
    }


    
    /// Persists all storage-level artefacts for a session, schedules its expiry
    /// timer, and (optionally) registers the session for auto-refresh.
    func persistSession(
        dto: TurnkeySession,
        sessionKey: String,
        refreshedSessionTTLSeconds: String? = nil
    ) throws {
        try JwtSessionStore.save(dto, key: sessionKey)
        try SessionRegistryStore.add(sessionKey)

        let priv = try KeyPairStore.getPrivateHex(for: dto.publicKey)
        if priv.isEmpty { throw TurnkeySwiftError.keyNotFound }
        try PendingKeysStore.remove(dto.publicKey)

        if let duration = refreshedSessionTTLSeconds {
            try AutoRefreshStore.set(durationSeconds: duration, for: sessionKey)
        }
        
        scheduleExpiryTimer(for: sessionKey, expTimestamp: dto.exp)
    }

    /// Removes *only* the stored artefacts for a session (no UI / in-memory reset).
    ///
    /// - Parameters:
    ///   - sessionKey: The key identifying the session in storage.
    ///   - keepAutoRefresh: Whether to retain any auto-refresh setting.
    func purgeStoredSession(
        for sessionKey: String,
        keepAutoRefresh: Bool
    ) throws {
        expiryTasks[sessionKey]?.cancel()
        expiryTasks.removeValue(forKey: sessionKey)

        if let dto = try? JwtSessionStore.load(key: sessionKey) {
            try? KeyPairStore.delete(for: dto.publicKey)
        }

        JwtSessionStore.delete(key: sessionKey)
        try? SessionRegistryStore.remove(sessionKey)

        if !keepAutoRefresh {
            try? AutoRefreshStore.remove(for: sessionKey)
        }
    }
    
    /// Updates an existing session with a new JWT, preserving any configured auto-refresh duration.
    ///
    /// - Parameters:
    ///   - jwt: The fresh JWT string returned by the Turnkey backend.
    ///   - sessionKey: The identifier of the session to update. Defaults to `Constants.Session.defaultSessionKey`.
    ///   
    /// - Throws:
    ///   - `TurnkeySwiftError.keyNotFound` if no session exists under the given key.
    ///   - `TurnkeySwiftError.failedToCreateSession` if decoding or persistence operations fail.
    func updateSession(
        jwt: String,
        sessionKey: String = Constants.Session.defaultSessionKey
    ) async throws {
        do {
            // eventually we should verify that the jwt was signed by Turnkey
            // but for now we just assume it is

            guard try JwtSessionStore.load(key: sessionKey) != nil else {
                throw TurnkeySwiftError.keyNotFound
            }

            // remove old key material but preserve any auto-refresh duration
            try purgeStoredSession(for: sessionKey, keepAutoRefresh: true)

            let dto = try JWTDecoder.decode(jwt, as: TurnkeySession.self)
            let nextDuration = AutoRefreshStore.durationSeconds(for: sessionKey)
            try persistSession(dto: dto,
                               sessionKey: sessionKey,
                               refreshedSessionTTLSeconds: nextDuration)
        } catch {
            throw TurnkeySwiftError.failedToCreateSession(underlying: error)
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
