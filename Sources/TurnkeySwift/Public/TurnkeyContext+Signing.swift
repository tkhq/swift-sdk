import Foundation
import TurnkeyTypes
import TurnkeyHttp

extension TurnkeyContext {
    
    /// Signs a raw payload using the currently selected session's credentials.
    ///
    /// - Parameters:
    ///   - signWith: The key ID or alias to sign with.
    ///   - payload: The raw data to be signed.
    ///   - encoding: The encoding of the payload (e.g., `utf8`, `hex`, `base64url`).
    ///   - hashFunction: The hash function to apply prior to signing.
    ///
    /// - Returns: A `SignRawPayloadResult` containing the signature and metadata.
    ///
    /// - Throws: `TurnkeySwiftError.invalidSession` if no session is selected,
    ///           `TurnkeySwiftError.invalidResponse` if the server response is malformed,
    ///           or `TurnkeySwiftError.failedToSignPayload` if the signing operation fails.
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
            let dto = try JwtSessionStore.load(key: sessionKey)
        else {
            throw TurnkeySwiftError.invalidSession
        }
        
        
        do {
            let resp = try await client.signRawPayload(TSignRawPayloadBody(
                organizationId: dto.organizationId,
                encoding: encoding,
                hashFunction: hashFunction,
                payload: payload,
                signWith: signWith
            ))
            
            guard let result = resp.activity.result.signRawPayloadResult else {
                throw TurnkeySwiftError.invalidResponse
            }
            
            return result
            
        } catch {
            throw TurnkeySwiftError.failedToSignPayload(underlying: error)
        }
    }

    /// Signs a plaintext message using the currently selected session's credentials.
    ///
    /// Behavior mirrors JS SDK for embedded wallets:
    /// - Ethereum: optionally prefixes with "\x19Ethereum Signed Message:\n" + len(messageBytes)
    /// - Defaults for encoding and hashFunction are inferred from the address format
    ///
    /// - Parameters:
    ///   - signWith: Wallet account to use for signing.
    ///   - message: UTF-8 plaintext message to sign.
    ///   - encoding: Optional override for payload encoding.
    ///   - hashFunction: Optional override for hash function.
    ///   - addEthereumPrefix: Optional override for Ethereum message prefixing (defaults to true for Ethereum accounts).
    ///
    /// - Returns: A `SignRawPayloadResult` containing the signature components.
    ///
    /// - Throws: `TurnkeySwiftError.invalidSession` if no session is selected,
    ///           `TurnkeySwiftError.invalidResponse` if the server response is malformed,
    ///           or `TurnkeySwiftError.failedToSignPayload` if the signing operation fails.
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

    /// Signs a plaintext message using the currently selected session's credentials.
    /// See the other overload for behavior details.
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
            let dto = try JwtSessionStore.load(key: sessionKey)
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
                organizationId: dto.organizationId,
                encoding: finalEncoding,
                hashFunction: finalHash,
                payload: payload,
                signWith: signWith
            ))

            guard let result = resp.activity.result.signRawPayloadResult else {
                throw TurnkeySwiftError.invalidResponse
            }
            return result
        } catch {
            throw TurnkeySwiftError.failedToSignPayload(underlying: error)
        }
    }
}
