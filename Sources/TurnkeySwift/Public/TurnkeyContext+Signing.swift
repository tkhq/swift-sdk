import Foundation
import TurnkeyTypes
import TurnkeyHttp

extension TurnkeyContext {
    
    /// Signs a raw payload using the currently selected session’s credentials.
    ///
    /// Uses the active session to sign arbitrary data with the specified key and encoding parameters.
    ///
    /// - Parameters:
    ///   - signWith: The key ID or alias to sign with.
    ///   - payload: The raw data to be signed.
    ///   - encoding: The encoding of the payload (e.g., `utf8`, `hex`, `base64url`).
    ///   - hashFunction: The hash function to apply before signing.
    ///
    /// - Returns: A `SignRawPayloadResult` containing the signature components and metadata.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidSession` if no active session is found.
    ///   - `TurnkeySwiftError.invalidResponse` if the server response is malformed.
    ///   - `TurnkeySwiftError.failedToSignPayload` if the signing operation fails.
    public func signRawPayload(
        signWith: String,
        payload: String,
        encoding: PayloadEncoding,
        hashFunction: HashFunction
    ) async throws -> SignRawPayloadResult {
        
        guard
            authState == .authenticated,
            let client = client,
            let sessionKey = selectedSessionKey,
            let stored = try JwtSessionStore.load(key: sessionKey)
        else {
            throw TurnkeySwiftError.invalidSession
        }
        
        
        do {
            let resp = try await client.signRawPayload(TSignRawPayloadBody(
                organizationId: stored.decoded.organizationId,
                encoding: encoding,
                hashFunction: hashFunction,
                payload: payload,
                signWith: signWith
            ))
            
            return SignRawPayloadResult(r: resp.r, s: resp.s, v: resp.v)
            
        } catch {
            throw TurnkeySwiftError.failedToSignPayload(underlying: error)
        }
    }
    
    /// Signs a plaintext message using the currently selected session’s credentials.
    ///
    /// Determines the encoding and hash function based on the provided wallet account and applies
    /// optional Ethereum message prefixing before signing.
    ///
    /// - Parameters:
    ///   - signWith: The wallet account to use for signing.
    ///   - message: The plaintext message to sign.
    ///   - encoding: Optional override for payload encoding.
    ///   - hashFunction: Optional override for hash function.
    ///   - addEthereumPrefix: Optional flag to prefix Ethereum messages (defaults to true for Ethereum accounts).
    ///
    /// - Returns: A `SignRawPayloadResult` containing the signature components.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidSession` if no active session is found.
    ///   - `TurnkeySwiftError.invalidResponse` if the server response is malformed.
    ///   - `TurnkeySwiftError.failedToSignPayload` if the signing operation fails.
    public func signMessage(
        signWith account: WalletAccount,
        message: String,
        encoding: PayloadEncoding? = nil,
        hashFunction: HashFunction? = nil,
        addEthereumPrefix: Bool? = nil
    ) async throws -> SignRawPayloadResult {
        return try await signMessage(
            signWith: account.address,
            addressFormat: account.addressFormat,
            message: message,
            encoding: encoding,
            hashFunction: hashFunction,
            addEthereumPrefix: addEthereumPrefix
        )
    }
    
    /// Signs a plaintext message using the currently selected session’s credentials.
    ///
    /// Resolves encoding and hashing defaults from the address format, applies Ethereum
    /// prefixing when required, and performs signing using the selected session key.
    ///
    /// - Parameters:
    ///   - signWith: The address or key identifier to sign with.
    ///   - addressFormat: The address format associated with the signing key.
    ///   - message: The plaintext message to sign.
    ///   - encoding: Optional override for payload encoding.
    ///   - hashFunction: Optional override for hash function.
    ///   - addEthereumPrefix: Optional flag to prefix Ethereum messages (defaults to true for Ethereum accounts).
    ///
    /// - Returns: A `SignRawPayloadResult` containing the signature components.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidSession` if no active session is found.
    ///   - `TurnkeySwiftError.invalidResponse` if the server response is malformed.
    ///   - `TurnkeySwiftError.failedToSignPayload` if the signing operation fails.
    public func signMessage(
        signWith: String,
        addressFormat: AddressFormat,
        message: String,
        encoding: PayloadEncoding? = nil,
        hashFunction: HashFunction? = nil,
        addEthereumPrefix: Bool? = nil
    ) async throws -> SignRawPayloadResult {
        guard
            authState == .authenticated,
            let client = client,
            let sessionKey = selectedSessionKey,
            let stored = try JwtSessionStore.load(key: sessionKey)
        else {
            throw TurnkeySwiftError.invalidSession
        }
        
        // Determine defaults from address format
        let defaults = AddressFormatDefaults.defaults(for: addressFormat)
        let finalEncoding = encoding ?? defaults.encoding
        let finalHash = hashFunction ?? defaults.hashFunction
        
        // Start with UTF-8 message bytes
        var messageBytes = Data(message.utf8)
        
        // Apply Ethereum prefix if applicable
        if addressFormat == .address_format_ethereum {
            let shouldPrefix = addEthereumPrefix ?? true
            if shouldPrefix {
                messageBytes = MessageEncodingHelper.ethereumPrefixed(messageData: messageBytes)
            }
        }
        
        let payload = MessageEncodingHelper.encodeMessageBytes(messageBytes, as: finalEncoding)
        
        do {
            let resp = try await client.signRawPayload(TSignRawPayloadBody(
                organizationId: stored.decoded.organizationId,
                encoding: finalEncoding,
                hashFunction: finalHash,
                payload: payload,
                signWith: signWith
            ))
            
            return SignRawPayloadResult(r: resp.r, s: resp.s, v: resp.v)
        } catch {
            throw TurnkeySwiftError.failedToSignPayload(underlying: error)
        }
    }
}
