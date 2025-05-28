public enum StampError: Error {
  case missingCredentials
  case assertionFailed
  case apiKeyStampError(APIKeyStampError)
  case unknownError(String)
  case passkeyManagerNotSet
  case invalidPayload
}

public enum APIKeyStampError: Error {
  case invalidPrivateKey
  case invalidPublicKey
  case mismatchedPublicKey(expected: String, actual: String)
  case invalidHexCharacter
  case signatureFailed
  case failedToSerializePayloadToJSON(Error)
}
