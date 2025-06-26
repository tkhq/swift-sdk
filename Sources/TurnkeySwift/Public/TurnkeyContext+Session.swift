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
    
    /// Creates a new session from the provided JWT, persists its metadata, and (optionally) schedules auto-refresh.
    ///
    /// - Parameters:
    ///   - jwt: The JWT string returned by the Turnkey backend.
    ///   - sessionKey: An identifier under which to store this session. Defaults to `Constants.Session.defaultSessionKey`.
    ///   - refreshedSessionTTLSeconds: *Optional.* The duration (in seconds) that refreshed sessions will be valid for.
    ///     If provided, the SDK will automatically refresh this session near expiry using this value. Must be at least 30 seconds.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidRefreshTTL` if `refreshedSessionTTLSeconds` is provided but less than 30 seconds.
    ///   - `TurnkeySwiftError.keyAlreadyExists` if a session with the same `sessionKey` already exists.
    ///   - `TurnkeySwiftError.failedToCreateSession` if decoding, persistence, or other internal operations fail.
    public func createSession(
        jwt: String,
        sessionKey: String = Constants.Session.defaultSessionKey,
        refreshedSessionTTLSeconds: String? = nil
    ) async throws {
        do {
            // eventually we should verify that the jwt was signed by Turnkey
            // but for now we just assume it is
            
            if let ttlString = refreshedSessionTTLSeconds,
               let ttl = Int(ttlString),
               ttl < 30 {
                throw TurnkeySwiftError.invalidRefreshTTL("Minimum allowed TTL is 30 seconds.")
            }
            
            // we check if there is already an active session under that sessionKey
            // if so we throw an error
            if let _ = try JwtSessionStore.load(key: sessionKey) {
                throw TurnkeySwiftError.keyAlreadyExists
            }
            
            let dto = try JWTDecoder.decode(jwt, as: TurnkeySession.self)
            try persistSession(
                dto: dto,
                sessionKey: sessionKey,
                refreshedSessionTTLSeconds: refreshedSessionTTLSeconds
            )
            
            if selectedSessionKey == nil {
                _ = try await setSelectedSession(sessionKey: sessionKey)
            }
            
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
        
        guard let sessionKey else { return }
        
        try? purgeStoredSession(for: sessionKey, keepAutoRefresh: false)
        
        Task { @MainActor in
            if selectedSessionKey == sessionKey {
                selectedSessionKey = nil
                SelectedSessionStore.delete()
                client = nil
                user = nil
            }
        }
    }
    
    /// Refreshes a session by generating a new key pair, stamping a login request, and updating stored metadata.
    ///
    /// - Parameters:
    ///   - expirationSeconds: The requested lifetime for the new session in seconds. Defaults to `Constants.Session.defaultExpirationSeconds`.
    ///   - sessionKey: The key of the session to refresh. If `nil`, the currently selected session is used.
    ///   - invalidateExisting: Whether to invalidate the previous session on the server. Defaults to `false`.
    /// - Throws:
    ///   - `TurnkeySwiftError.keyNotFound` if no session exists under the given `sessionKey`.
    ///   - `TurnkeySwiftError.invalidSession` if the selected session is not initialized.
    ///   - `TurnkeySwiftError.failedToRefreshSession` if stamping or persistence fails..
    public func refreshSession(
        expirationSeconds: String = Constants.Session.defaultExpirationSeconds,
        sessionKey: String? = nil,
        invalidateExisting: Bool = false
    ) async throws {
        
        // determine which sessionKey we’re targeting
        let targetSessionKey = sessionKey ?? selectedSessionKey
        guard let targetSessionKey else {
            throw TurnkeySwiftError.keyNotFound
        }
        
        // pick the right client and user/org
        let clientToUse: TurnkeyClient
        let orgId: String
        
        if targetSessionKey == selectedSessionKey {
            // refreshing the selected session
            guard let currentClient = self.client,
                  let currentUser = self.user
            else {
                throw TurnkeySwiftError.invalidSession
            }
            clientToUse = currentClient
            orgId = currentUser.organizationId
        } else {
            // refreshing a background session
            
            guard let dto = try JwtSessionStore.load(key: targetSessionKey) else {
                throw TurnkeySwiftError.keyNotFound
            }
            
            let privHex = try KeyPairStore.getPrivateHex(for: dto.publicKey)
            clientToUse = TurnkeyClient(
                apiPrivateKey: privHex,
                apiPublicKey: dto.publicKey,
                baseUrl: apiUrl
            )
            orgId = dto.organizationId
        }
        
        let newPublicKey = try createKeyPair()
        
        do {
            let resp = try await clientToUse.stampLogin(
                organizationId: orgId,
                publicKey: newPublicKey,
                expirationSeconds: expirationSeconds,
                invalidateExisting: invalidateExisting
            )
            guard
                case let .json(body) = resp.body,
                let jwt = body.activity.result.stampLoginResult?.session
            else {
                throw TurnkeySwiftError.invalidResponse
            }
            
            try await updateSession(jwt: jwt, sessionKey: targetSessionKey)
            
            // if this was the selected session, swap in the new client
            if targetSessionKey == selectedSessionKey {
                let updatedDto = try JwtSessionStore.load(key: targetSessionKey)!
                let privHex = try KeyPairStore.getPrivateHex(for: updatedDto.publicKey)
                let newClient = TurnkeyClient(
                    apiPrivateKey: privHex,
                    apiPublicKey: updatedDto.publicKey,
                    baseUrl: apiUrl
                )
                await MainActor.run {
                    self.client = newClient
                }
            }
            
        } catch {
            throw TurnkeySwiftError.failedToRefreshSession(underlying: error)
        }
    }
    
}


