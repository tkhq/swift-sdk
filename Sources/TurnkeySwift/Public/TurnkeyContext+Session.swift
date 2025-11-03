import Foundation
import TurnkeyTypes
import TurnkeyCrypto
import TurnkeyHttp
import TurnkeyStamper

extension TurnkeyContext {
    
    /// Generates a new on-device key pair and adds it to the pending list.
    ///
    /// Prefers Secure Enclave when supported; otherwise falls back to Secure Storage (Keychain).
    /// The private key remains on-device and is not exportable. Returns the compressed public key.
    ///
    /// - Returns: The public key string.
    /// - Throws: An error if key creation or persistence fails.
    @discardableResult
    public func createKeyPair() throws -> String {
        let publicKey = try Stamper.createOnDeviceKeyPair()
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
    ///   - `TurnkeySwiftError.failedToStoreSession` if decoding, persistence, or other internal operations fail.
    public func storeSession(
        jwt: String,
        sessionKey: String? = nil,
        refreshedSessionTTLSeconds: String? = nil
    ) async throws {
        let resolvedSessionKey = sessionKey?.isEmpty == false
                ? sessionKey!
                : Constants.Session.defaultSessionKey
        
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
            if let _ = try JwtSessionStore.load(key: resolvedSessionKey) {
                throw TurnkeySwiftError.keyAlreadyExists
            }
                        
            let dto = try JWTDecoder.decode(jwt, as: TurnkeySession.self)
                       
            // determine if auto-refresh should be enabled and how to set the TTL
            // - auto-refresh is enabled if either:
            //     (a) `refreshedSessionTTLSeconds` is explicitly provided, OR
            //     (b) `runtimeConfig.auth.autoRefreshSession` is true
            // - if `refreshedSessionTTLSeconds` was passed in, we use it directly
            // - if it wasn’t passed in but auto-refresh is enabled via config,
            //   then we calculate the TTL dynamically based on the current time and the
            //   JWT’s expiration (`exp - now`)
            //
            // Note: this calculated TTL will be slightly shorter than the actual session
            //       lifetime due to timing differences, but that’s acceptable because it’s
            //       stored inside `AutoRefreshStore` and reused for future refreshes, so this
            //       loss only occurs once
            var ttlToStore: String? = refreshedSessionTTLSeconds
            if ttlToStore == nil {
                if runtimeConfig?.auth.autoRefreshSession == true {
                    let exp = dto.exp
                    let now = Date().timeIntervalSince1970
                    let ttl = max(0, exp - now)
                    ttlToStore = String(Int(ttl))
                }
            }
            
            try persistSession(
                dto: dto,
                jwt: jwt,
                sessionKey: resolvedSessionKey,
                refreshedSessionTTLSeconds: ttlToStore
            )
            
            if selectedSessionKey == nil {
                try? SelectedSessionStore.save(resolvedSessionKey)
                
                let privHex = try KeyPairStore.getPrivateHex(for: dto.publicKey)
                let cli = TurnkeyClient(
                    apiPrivateKey: privHex,
                    apiPublicKey: dto.publicKey,
                    baseUrl: apiUrl
                )
                
                // Create and set session state
                let session = Session(
                    exp: dto.exp,
                    publicKey: dto.publicKey,
                    sessionType: dto.sessionType,
                    userId: dto.userId,
                    organizationId: dto.organizationId,
                    token: jwt
                )
                
                await MainActor.run {
                    self.selectedSessionKey = resolvedSessionKey
                    self.client = cli
                    self.session = session
                    self.authState = .authenticated
                }
                
                // we set user and wallet state
                try? await refreshUser()
                try? await refreshWallets()
            }
            
        } catch {
            throw TurnkeySwiftError.failedToStoreSession(underlying: error)
        }
    }
    
    /// Sets the currently active session to the specified session key.
    ///
    /// - Parameter sessionKey: The key identifying the session to activate.
    /// - Returns: A configured `TurnkeyClient` for the session.
    /// - Throws: `TurnkeySwiftError` if loading session details fails.
    @discardableResult
    public func setActiveSession(sessionKey: String) async throws -> TurnkeyClient {
        do {
            guard let stored = try JwtSessionStore.load(key: sessionKey) else {
                throw TurnkeySwiftError.keyNotFound
            }
            
            let dto = stored.decoded
            let jwt = stored.jwt
        
            let client = try TurnkeyClient(
                apiPublicKey: dto.publicKey,
                baseUrl: apiUrl
            )
            
            let session = Session(
                exp: dto.exp,
                publicKey: dto.publicKey,
                sessionType: dto.sessionType,
                userId: dto.userId,
                organizationId: dto.organizationId,
                token: jwt
            )
            
            await MainActor.run {
                try? SelectedSessionStore.save(sessionKey)
                self.selectedSessionKey = sessionKey
                self.client = client
                self.session = session
            }
            
            // we update user and wallet state
            try? await refreshUser()
            try? await refreshWallets()
            
            return client
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
                authState = .unAuthenticated
                selectedSessionKey = nil
                client = self.makeAuthProxyClientIfNeeded()
                session = nil
                user = nil
                wallets = []
                
                SelectedSessionStore.delete()
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
            guard authState == .authenticated,
                  let currentSession = self.session,
                  let client = self.client else {
                throw TurnkeySwiftError.invalidSession
            }
            
            clientToUse = client
            orgId = currentSession.organizationId
        } else {
            // refreshing a background session
            
            guard let stored = try JwtSessionStore.load(key: targetSessionKey) else {
                throw TurnkeySwiftError.keyNotFound
            }
            
            let dto = stored.decoded

            clientToUse = try TurnkeyClient(
                apiPublicKey: dto.publicKey,
                baseUrl: apiUrl
            )
            orgId = dto.organizationId
        }
        
        let newPublicKey = try createKeyPair()
        
        do {
            let resp = try await clientToUse.stampLogin(TStampLoginBody(
                organizationId: orgId,
                expirationSeconds: expirationSeconds,
                invalidateExisting: invalidateExisting,
                publicKey: newPublicKey
            ))
            let jwt = resp.session
            
            // we purge old key material but preserve the auto-refresh metadata stored
            try purgeStoredSession(for: targetSessionKey, keepAutoRefresh: true)
            
            let dto = try JWTDecoder.decode(jwt, as: TurnkeySession.self)
            let nextDuration = AutoRefreshStore.durationSeconds(for: targetSessionKey)
            try persistSession(
                dto: dto,
                jwt: jwt,
                sessionKey: targetSessionKey,
                refreshedSessionTTLSeconds: nextDuration
            )
            
            // if this was the selected session we update client and session state
            if targetSessionKey == selectedSessionKey {

                let newClient = TurnkeyClient(
                    apiPublicKey: dto.publicKey,
                    baseUrl: apiUrl
                )
                
                let newSession = Session(
                    exp: dto.exp,
                    publicKey: dto.publicKey,
                    sessionType: dto.sessionType,
                    userId: dto.userId,
                    organizationId: dto.organizationId,
                    token: jwt
                )
                
                await MainActor.run {
                    self.client = newClient
                    self.session = newSession
                }
            }
            
        } catch {
            throw TurnkeySwiftError.failedToRefreshSession(underlying: error)
        }
    }
    
}


