import Foundation

public enum CryptoError: Error {
    case decodingFailed(Error)
    case invalidCompressedKeyLength
    case invalidHexString(String)
    case invalidPrivateKey(Error)
    case invalidPrivateLength(expected: Int, found: Int)
    case invalidPublicKey
    case invalidPublicLength(expected: Int, found: Int)
    case invalidSignatureEncoding
    case invalidUTF8
    
    case missingCiphertext
    case missingEncappedPublic
    case orgIdMismatch(expected: String, found: String?)
    case signerMismatch(expected: String, found: String)
    case signatureVerificationFailed
    case userIdMismatch(expected: String, found: String?)
}

extension CryptoError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .decodingFailed(let error):
            return "Failed to decode expected JSON structure: \(error.localizedDescription)"
        case .invalidCompressedKeyLength:
            return "Bundle too small – first 33 bytes (compressed pub-key) missing."
        case .invalidHexString(let string):
            return "String “\(string)” is not valid hex."
        case .invalidPrivateKey(let error):
            return "Invalid private key: \(error.localizedDescription)"
        case .invalidPrivateLength(let expected, let found):
            return "Private key length \(found) bytes – expected \(expected)."
        case .invalidPublicKey:
            return "Could not parse SEC-1 public key."
        case .invalidPublicLength(let expected, let found):
            return "Public-key length \(found) bytes – expected \(expected)."
        case .invalidSignatureEncoding:
            return "ECDSA signature isn’t valid DER."
        case .invalidUTF8:
            return "Byte-sequence is not valid UTF-8 text."
        case .missingCiphertext:
            return "Signed payload lacked “ciphertext”."
        case .missingEncappedPublic:
            return "Signed payload lacked “encappedPublic”."
        case .orgIdMismatch(let expected, let found):
            return "OrganizationId mismatch – expected \(expected), got \(found ?? "nil")."
        case .signerMismatch(let expected, let found):
            return "Signer pub-key mismatch – expected \(expected), got \(found)."
        case .signatureVerificationFailed:
            return "Signature verification returned “false”."
        case .userIdMismatch(let expected, let found):
            return "UserId mismatch – expected \(expected), got \(found ?? "nil")."
        }
    }
}
