import Foundation

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

    guard let client else {
      throw TurnkeySwiftError.invalidSession
    }

    guard let sessionKey = selectedSessionKey else {
      throw TurnkeySwiftError.invalidSession
    }

    guard let dto = try JwtSessionStore.load(key: sessionKey) else {
      throw TurnkeySwiftError.invalidSession
    }

    do {
      let resp = try await client.signRawPayload(
        organizationId: dto.organizationId,
        signWith: signWith,
        payload: payload,
        encoding: encoding,
        hashFunction: hashFunction
      )

      guard let result = try resp.ok.body.json.activity.result.signRawPayloadResult else {
        throw TurnkeySwiftError.invalidResponse
      }

      return result
    } catch {
      throw TurnkeySwiftError.failedToSignPayload(underlying: error)
    }
  }
}
