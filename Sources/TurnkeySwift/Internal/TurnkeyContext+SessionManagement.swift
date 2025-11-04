import Foundation
import TurnkeyTypes

extension TurnkeyContext {
    
    /// Restores the previously selected session from persistent storage.
    ///
    /// Attempts to load the last active session key from storage and re-establish
    /// the authenticated state if the session is still valid.
    /// If the stored session is expired or missing, it is removed and
    /// the authentication state is reset to unauthenticated.
    ///
    /// - Note: This method is called automatically on app launch or resume.
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
    
    /// Persists all artifacts associated with a session.
    ///
    /// Saves the session payload (decoded JWT, token, and metadata) into storage,
    /// registers it with the session registry, removes any pending keys,
    /// and schedules an expiration timer for automatic cleanup.
    ///
    /// - Parameters:
    ///   - dto: The decoded `TurnkeySession` object representing the session.
    ///   - jwt: The raw session JWT.
    ///   - sessionKey: The unique key used to identify this session in storage.
    ///   - refreshedSessionTTLSeconds: Optional override for the session's TTL (used for auto-refresh scheduling).
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.keyNotFound` if the private key for the session’s public key is missing.
    ///   - Any error thrown during session persistence or store updates.
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
    
    /// Removes stored session data from disk.
    ///
    /// Deletes all persisted artifacts associated with a session, including the JWT,
    /// registry entry, and any private keys, while optionally preserving auto-refresh settings.
    /// Does not modify in-memory state or authentication status.
    ///
    /// - Parameters:
    ///   - sessionKey: The key identifying the stored session.
    ///   - keepAutoRefresh: Whether to retain any existing auto-refresh configuration for the session.
    ///
    /// - Throws: Any error encountered while removing session data from local stores.
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
