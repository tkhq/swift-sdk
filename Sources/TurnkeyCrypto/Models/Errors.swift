import Foundation

public enum CryptoError: Error {
  case invalidCompressedKeyLength
  case invalidPrivateLength(expected: Int, found: Int)
  case invalidPublicLength(expected: Int, found: Int)
  case missingEncappedPublic
  case invalidPrivateKey(Error)

  case invalidHexString(String)
  case invalidSignatureEncoding
  case invalidUTF8

  case invalidPublicKey
  case orgIdMismatch(expected: String, found: String?)
  case signerMismatch(expected: String, found: String)
  case signatureVerificationFailed
  case userIdMismatch(expected: String, found: String?)
}

extension CryptoError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .invalidCompressedKeyLength:
      return "Bundle too small – first 33 bytes (compressed pub‑key) missing."
    case let .invalidHexString(s):
      return "String “\(s)” is not valid hex."
    case .missingEncappedPublic:
      return "Signed payload lacked “encappedPublic”."
    case let .invalidPrivateLength(e, f):
      return "Secret scalar length \(f) bytes – expected \(e)."
    case let .invalidPublicLength(e, f):
      return "Public‑key length \(f) bytes – expected \(e)."
    case let .signerMismatch(exp, got):
      return "Signer pub‑key mismatch – expected \(exp), got \(got)."
    case let .orgIdMismatch(exp, got):
      return "OrganizationId mismatch – expected \(exp), got \(got ?? "nil")."
    case let .userIdMismatch(exp, got):
      return "UserId mismatch – expected \(exp), got \(got ?? "nil")."
    case .invalidPublicKey:
      return "Could not parse SEC‑1 public key."
    case .invalidSignatureEncoding:
      return "ECDSA signature isn’t valid DER."
    case .signatureVerificationFailed:
      return "Signature verification returned “false”."
    case .invalidUTF8:
      return "Byte‑sequence is not valid UTF‑8 text."
    case let .invalidPrivateKey(err):
      return "Invalid private key: \(err.localizedDescription)"
    }
  }
}
