import Foundation
import TurnkeyTypes

extension TurnkeyContext {
    
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
            _ = try? await self.setActiveSession(sessionKey: sessionKey)
        } catch {
            await MainActor.run { self.authState = .unAuthenticated }
        }
    }
    
    /// Persists all storage-level artefacts for a session, schedules its expiry
    /// timer, and (optionally) registers the session for auto-refresh.
    func persistSession(
        dto: TurnkeySession,
        jwt: String,
        sessionKey: String,
        refreshedSessionTTLSeconds: String? = nil
    ) throws {
        let stored = StoredSession(decoded: dto, jwt: jwt)
        try JwtSessionStore.save(stored, key: sessionKey)
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

        if let stored = try? JwtSessionStore.load(key: sessionKey) {
            try? KeyPairStore.delete(for: stored.decoded.publicKey)
        }

        JwtSessionStore.delete(key: sessionKey)
        try? SessionRegistryStore.remove(sessionKey)

        if !keepAutoRefresh {
            try? AutoRefreshStore.remove(for: sessionKey)
        }
    }
}
