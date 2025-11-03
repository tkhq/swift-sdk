import AuthenticationServices
import CryptoKit
import Foundation
import LocalAuthentication
import TurnkeyPasskeys

public class Stamper {
  private let apiPublicKey: String?
  private let apiPrivateKey: String?
  private let presentationAnchor: ASPresentationAnchor?
  private let passkeyManager: PasskeyStamper?
  
  // Selected stamping backend
  private enum StampingMode {
    case apiKey(pub: String, priv: String)
    case passkey(manager: PasskeyStamper)
    case secureEnclave(publicKey: String)
    case secureStorage(publicKey: String)
  }
  private let mode: StampingMode?

  public init() {
    self.apiPublicKey = nil
    self.apiPrivateKey = nil
    self.presentationAnchor = nil
    self.passkeyManager = nil
    self.mode = nil
  }

  /// Initializes the stamper with an API key pair for signature stamping.
  ///
  /// - Parameters:
  ///   - apiPublicKey: The public key in hex format.
  ///   - apiPrivateKey: The corresponding private key in hex format.
  public init(apiPublicKey: String, apiPrivateKey: String) {
    self.apiPublicKey = apiPublicKey
    self.apiPrivateKey = apiPrivateKey
    self.presentationAnchor = nil
    self.passkeyManager = nil
    self.mode = .apiKey(pub: apiPublicKey, priv: apiPrivateKey)
  }

  /// Initializes the stamper with a passkey setup for WebAuthn-based signing.
  ///
  /// - Parameters:
  ///   - rpId: The relying party ID used in the passkey challenge.
  ///   - presentationAnchor: The anchor used for displaying authentication UI.
  public init(rpId: String, presentationAnchor: ASPresentationAnchor) {
    self.apiPublicKey = nil
    self.apiPrivateKey = nil
    self.presentationAnchor = presentationAnchor
    self.passkeyManager = PasskeyStamper(rpId: rpId, presentationAnchor: presentationAnchor)
    self.mode = .passkey(manager: self.passkeyManager!)
  }

  /// Initializes the stamper for hardware/software-stored private key signing using only a public key.
  ///
  /// Selection rules:
  /// - Prefer Secure Enclave if available; otherwise use Secure Storage.
  /// - Validates that the private key for the provided public key already exists in the chosen backend.
  ///
  /// - Parameter apiPublicKey: The public key (compressed hex) whose private key resides on-device.
  /// - Throws: `StampError.secureEnclaveUnavailable` or `StampError.keyNotFound(publicKeyHex:)` when appropriate.
  public init(apiPublicKey: String) throws {
    self.presentationAnchor = nil
    self.passkeyManager = nil
    self.apiPrivateKey = nil
    self.apiPublicKey = apiPublicKey

    if SecureEnclaveStamper.isSupported() {
      // Ensure the enclave holds the corresponding private key
      let existing = try SecureEnclaveStamper.listKeyPairs()
      guard existing.contains(apiPublicKey) else {
        throw StampError.keyNotFound(publicKeyHex: apiPublicKey)
      }
      self.mode = .secureEnclave(publicKey: apiPublicKey)
    } else {
      // Fallback to secure storage
      let existing = try SecureStorageStamper.listKeyPairs()
      guard existing.contains(apiPublicKey) else {
        throw StampError.keyNotFound(publicKeyHex: apiPublicKey)
      }
      self.mode = .secureStorage(publicKey: apiPublicKey)
    }
  }

  /// Generates a signed stamp for the given payload using either API key or passkey credentials.
  ///
  /// - Parameter payload: The raw string payload to be signed.
  /// - Returns: A tuple containing the header name and the base64url-encoded stamp.
  /// - Throws: `StampError` if credentials are missing or signing fails.
  public func stamp(payload: String) async throws -> (
    stampHeaderName: String, stampHeaderValue: String
  ) {
    guard let payloadData = payload.data(using: .utf8) else {
      throw StampError.invalidPayload
    }

    let payloadHash = SHA256.hash(data: payloadData)

    // Route based on configured mode first
    if let mode = self.mode {
      switch mode {
      case let .apiKey(pub, priv):
        let stamp = try ApiKeyStamper.stamp(
          payload: payloadHash, publicKeyHex: pub, privateKeyHex: priv)
        return ("X-Stamp", stamp)
      case let .passkey(manager):
        let stamp = try await PasskeyStampBuilder.stamp(
          payload: payloadHash, passkeyManager: manager)
        return ("X-Stamp-WebAuthn", stamp)
      case let .secureEnclave(publicKey):
        let stamp = try SecureEnclaveStamper.stamp(
          payload: payload, publicKeyHex: publicKey)
        return ("X-Stamp", stamp)
      case let .secureStorage(publicKey):
        let stamp = try SecureStorageStamper.stamp(
          payload: payload, publicKeyHex: publicKey)
        return ("X-Stamp", stamp)
      }
    }

    // Backward compatibility: derive from legacy properties if possible
    if let pub = apiPublicKey, let priv = apiPrivateKey {
      let stamp = try ApiKeyStamper.stamp(
        payload: payloadHash, publicKeyHex: pub, privateKeyHex: priv)
      return ("X-Stamp", stamp)
    }
    if let manager = passkeyManager {
      let stamp = try await PasskeyStampBuilder.stamp(
        payload: payloadHash, passkeyManager: manager)
      return ("X-Stamp-WebAuthn", stamp)
    }

    throw StampError.missingCredentials
  }
}

// MARK: - Public key management helpers
public extension Stamper {
  /// Create a new on-device API key pair.
  ///
  /// Prefers Secure Enclave when supported; otherwise falls back to Secure Storage.
  /// Returns the compressed public key hex. The private key remains on-device.
  static func createOnDeviceKeyPair() throws -> String {
    if SecureEnclaveStamper.isSupported() {
      return try createSecureEnclaveKeyPair()
    }
    return try createSecureStorageKeyPair()
  }

  /// Create a new API key pair inside Secure Enclave. Throws if enclave is unavailable.
  static func createSecureEnclaveKeyPair() throws -> String {
    return try SecureEnclaveStamper.createKeyPair()
  }

  /// Create a new API key pair stored in Secure Storage (Keychain).
  static func createSecureStorageKeyPair() throws -> String {
    return try SecureStorageStamper.createKeyPair()
  }

  /// Delete an on-device API key pair.
  ///
  /// Prefers Secure Enclave when supported; otherwise falls back to Secure Storage.
  /// Returns true if the key pair was deleted successfully.
  static func deleteOnDeviceKeyPair(publicKeyHex: String) throws {
    if SecureEnclaveStamper.isSupported() {
      return try deleteSecureEnclaveKeyPair(publicKeyHex: publicKeyHex)
    }
    return try deleteSecureStorageKeyPair(publicKeyHex: publicKeyHex)
  }

  /// Delete an API key pair inside Secure Enclave.
  static func deleteSecureEnclaveKeyPair(publicKeyHex: String) throws {
    return try SecureEnclaveStamper.deleteKeyPair(publicKeyHex: publicKeyHex)
  }

  /// Delete an API key pair stored in Secure Storage (Keychain).
  static func deleteSecureStorageKeyPair(publicKeyHex: String) throws {
    return try SecureStorageStamper.deleteKeyPair(publicKeyHex: publicKeyHex)
  }

  /// Exists an on-device API key pair.
  ///
  /// Prefers Secure Enclave when supported; otherwise falls back to Secure Storage.
  /// Returns true if the key pair exists.
  static func existsOnDeviceKeyPair(publicKeyHex: String) throws -> Bool {
    if SecureEnclaveStamper.isSupported() {
      return try existsSecureEnclaveKeyPair(publicKeyHex: publicKeyHex)
    }
    return try existsSecureStorageKeyPair(publicKeyHex: publicKeyHex)
  }

  /// Exists an API key pair inside Secure Enclave.
  static func existsSecureEnclaveKeyPair(publicKeyHex: String) throws -> Bool {
      return try SecureEnclaveStamper.listKeyPairs().contains(where: { $0 == publicKeyHex })
  }

  /// Exists an API key pair stored in Secure Storage (Keychain).
  static func existsSecureStorageKeyPair(publicKeyHex: String) throws -> Bool {
    return try SecureStorageStamper.listKeyPairs().contains(where: { $0 == publicKeyHex })
  }
}

/// we need this extention  to `Stamper` to be used safely across concurrency boundaries
extension Stamper: @unchecked Sendable {}

extension SHA256Digest {
  var hexEncoded: String {
    self.map { String(format: "%02x", $0) }.joined()
  }
}
