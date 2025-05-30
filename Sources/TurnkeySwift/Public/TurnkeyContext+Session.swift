import Foundation
import TurnkeyCrypto
import TurnkeyHttp

extension TurnkeyContext {
    
    /// Generates a new ephemeral key pair, stores it securely, and adds it to the pending list.
    ///
    /// - Returns: The public key string.
    /// - Throws: An error if the key could not be saved.
    @discardableResult
    public func createKeyPair() throws -> String {
        let (_, publicKey, privateKey) = TurnkeyCrypto.generateP256KeyPair()
        try KeyPairStore.save(privateHex: privateKey, for: publicKey)
        try PendingKeysStore.add(publicKey)
        return publicKey
    }
    
    /// Creates and stores a new session from the provided JWT.
    ///
    /// - Parameters:
    ///   - jwt: A JWT string returned from the Turnkey backend.
    ///   - sessionKey: A key to label the session in storage. Defaults to a constant.
    ///
    /// - Throws: `TurnkeySwiftError` if session creation or decoding fails.
    public func createSession(
        jwt: String,
        sessionKey: String = Constants.Session.defaultSessionKey
    ) async throws {
        do {
            // eventually we should verify that the jwt was signed by Turnkey
            // but for now we just assume it is
            
            let dto = try JWTDecoder.decode(jwt, as: TurnkeySession.self)
            try JwtSessionStore.save(dto, key: sessionKey)
            try SessionRegistryStore.add(sessionKey)
            
            let priv = try KeyPairStore.getPrivateHex(for: dto.publicKey)
            if priv.isEmpty {
                throw TurnkeySwiftError.keyNotFound
            }
            
            if selectedSessionKey == nil {
                _ = try await setSelectedSession(sessionKey: sessionKey)
            }
            
            scheduleExpiryTimer(for: sessionKey, expTimestamp: dto.exp)
        } catch {
            throw TurnkeySwiftError.failedToCreateSession(underlying: error)
        }
    }
    
    /// Sets the currently active session to the specified session key.
    ///
    /// - Parameter sessionKey: The key identifying the session to activate.
    /// - Returns: A configured `TurnkeyClient` for the session.
    /// - Throws: `TurnkeySwiftError` if loading session details fails.
    @discardableResult
    public func setSelectedSession(sessionKey: String) async throws -> TurnkeyClient {
        do {
            guard let dto = try JwtSessionStore.load(key: sessionKey) else {
                throw TurnkeySwiftError.keyNotFound
            }
            
            let privHex = try KeyPairStore.getPrivateHex(for: dto.publicKey)
            
            let cli = TurnkeyClient(
                apiPrivateKey: privHex,
                apiPublicKey: dto.publicKey,
                baseUrl: apiUrl
            )
            
            let fetched = try await fetchSessionUser(
                using: cli,
                organizationId: dto.organizationId,
                userId: dto.userId
            )
            
            await MainActor.run {
                try? SelectedSessionStore.save(sessionKey)
                self.selectedSessionKey = sessionKey
                self.client = cli
                self.user = fetched
            }
            
            return cli
        } catch {
            throw TurnkeySwiftError.failedToSetSelectedSession(underlying: error)
        }
    }
    
    /// Clears the session associated with the given session key, or the current session if none provided.
    ///
    /// - Parameter sessionKey: Optional session key to clear. Defaults to the currently selected session.
    public func clearSession(for sessionKey: String? = nil) {
        let sessionKey = sessionKey ?? selectedSessionKey
        
        guard let sessionKey else {
            return
        }
        
        expiryTasks[sessionKey]?.cancel()
        expiryTasks.removeValue(forKey: sessionKey)
        
        do {
            if let dto = try? JwtSessionStore.load(key: sessionKey) {
                try? KeyPairStore.delete(for: dto.publicKey)
                try? PendingKeysStore.remove(dto.publicKey)
            }
            
            JwtSessionStore.delete(key: sessionKey)
            try? SessionRegistryStore.remove(sessionKey)
        }
        
        Task { @MainActor in
            if selectedSessionKey == sessionKey {
                selectedSessionKey = nil
                SelectedSessionStore.delete()
                client = nil
                user = nil
            }
        }
    }
}
