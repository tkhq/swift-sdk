import AuthenticationServices
import CryptoKit
import Foundation
import LocalAuthentication
import TurnkeyPasskeys

public enum OnDeviceStamperPreference {
  case auto
  case secureEnclave
  case secureStorage
}

public class Stamper {
  private let apiPublicKey: String?
  private let apiPrivateKey: String?
  private let presentationAnchor: ASPresentationAnchor?
  private let passkeyManager: PasskeyStamper?
  private var configuration: StamperConfiguration? = nil
  
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

  /// Initializes the stamper using a passkey configuration.
  ///
  /// - Parameter config: Passkey stamper configuration.
  public convenience init(config: PasskeyStamperConfig) {
    self.init(rpId: config.rpId, presentationAnchor: config.presentationAnchor)
    self.configuration = .passkey(config)
  }

  /// Initializes the stamper for on-device key signing using only a public key, with a selectable backend.
  ///
  /// - Parameters:
  ///   - apiPublicKey: The public key (compressed hex) whose private key resides on-device.
  ///   - onDevicePreference: Preferred backend selection. `.auto` prefers Secure Enclave when supported; otherwise uses Secure Storage.
  /// - Throws:
  ///   - `StampError.secureEnclaveUnavailable` when `.secureEnclave` is selected but the device does not support it.
  ///   - `StampError.keyNotFound(publicKeyHex:)` if the private key for the given public key is not found in the selected backend.
  public init(apiPublicKey: String, onDevicePreference: OnDeviceStamperPreference = .auto) throws {
    self.presentationAnchor = nil
    self.passkeyManager = nil
    self.apiPrivateKey = nil
    self.apiPublicKey = apiPublicKey

    switch onDevicePreference {
    case .auto:
      if SecureEnclaveStamper.isSupported() {
        let existing = try SecureEnclaveStamper.listKeyPairs()
        guard existing.contains(apiPublicKey) else {
          throw StampError.keyNotFound(publicKeyHex: apiPublicKey)
        }
        self.mode = .secureEnclave(publicKey: apiPublicKey)
      } else {
        let existing = try SecureStorageStamper.listKeyPairs()
        guard existing.contains(apiPublicKey) else {
          throw StampError.keyNotFound(publicKeyHex: apiPublicKey)
        }
        self.mode = .secureStorage(publicKey: apiPublicKey)
      }
    case .secureEnclave:
      guard SecureEnclaveStamper.isSupported() else {
        throw StampError.secureEnclaveUnavailable
      }
      let existing = try SecureEnclaveStamper.listKeyPairs()
      guard existing.contains(apiPublicKey) else {
        throw StampError.keyNotFound(publicKeyHex: apiPublicKey)
      }
      self.mode = .secureEnclave(publicKey: apiPublicKey)
    case .secureStorage:
      let existing = try SecureStorageStamper.listKeyPairs()
      guard existing.contains(apiPublicKey) else {
        throw StampError.keyNotFound(publicKeyHex: apiPublicKey)
      }
      self.mode = .secureStorage(publicKey: apiPublicKey)
    }
  }

  /// Initializes the stamper using an API key pair configuration.
  ///
  /// - Parameter config: API key stamper configuration.
  public convenience init(config: ApiKeyStamperConfig) {
    self.init(apiPublicKey: config.apiPublicKey, apiPrivateKey: config.apiPrivateKey)
    self.configuration = .apiKey(config)
  }

  /// Initializes the stamper by creating a new on-device key pair in Secure Enclave with the provided configuration.
  ///
  /// - Parameter config: Secure Enclave key creation configuration.
  /// - Throws: `StampError.secureEnclaveUnavailable` if enclave unsupported; underlying errors on key creation or initialization.
  public convenience init(config: SecureEnclaveStamperConfig) throws {
    guard SecureEnclaveStamper.isSupported() else { throw StampError.secureEnclaveUnavailable }
    let internalConfig = Self.mapSecureEnclaveConfig(config)
    let publicKey = try SecureEnclaveStamper.createKeyPair(config: internalConfig)
    try self.init(apiPublicKey: publicKey, onDevicePreference: .secureEnclave)
    self.configuration = .secureEnclave(config)
  }

  /// Initializes the stamper by creating a new on-device key pair in Secure Storage with the provided configuration.
  ///
  /// - Parameter config: Secure Storage (Keychain) key creation configuration.
  /// - Throws: Underlying errors on key creation or initialization.
  public convenience init(config: SecureStorageStamperConfig) throws {
    let internalConfig = Self.mapSecureStorageConfig(config)
    let publicKey = try SecureStorageStamper.createKeyPair(config: internalConfig)
    try self.init(apiPublicKey: publicKey, onDevicePreference: .secureStorage)
    self.configuration = .secureStorage(config)
  }

  /// Initializes the stamper by creating a new on-device key pair using the preferred backend.
  ///
  /// - Parameter onDevicePreference: `.auto` prefers Secure Enclave when supported; otherwise Secure Storage.
  /// - Throws: `StampError.secureEnclaveUnavailable` when `.secureEnclave` selected but unsupported; underlying errors otherwise.
  public convenience init(onDevicePreference: OnDeviceStamperPreference = .auto) throws {
    let selected: OnDeviceStamperPreference =
      onDevicePreference == .auto
      ? (SecureEnclaveStamper.isSupported() ? .secureEnclave : .secureStorage)
      : onDevicePreference

    switch selected {
    case .secureEnclave, .auto:
      if SecureEnclaveStamper.isSupported() {
        let pub = try SecureEnclaveStamper.createKeyPair()
        try self.init(apiPublicKey: pub, onDevicePreference: .secureEnclave)
        self.configuration = .secureEnclave(SecureEnclaveStamperConfig())
      } else if selected == .secureEnclave {
        throw StampError.secureEnclaveUnavailable
      } else {
        fallthrough
      }
    case .secureStorage:
      let pub = try SecureStorageStamper.createKeyPair()
      try self.init(apiPublicKey: pub, onDevicePreference: .secureStorage)
      self.configuration = .secureStorage(SecureStorageStamperConfig())
    }
  }

  /// Initializes the stamper for hardware/software-stored private key signing using only a public key.
  ///
  /// Selection rules:
  /// - Prefer Secure Enclave if available; otherwise use Secure Storage.
  /// - Validates that the private key for the provided public key already exists in the chosen backend.
  ///
  /// - Parameter apiPublicKey: The public key (compressed hex) whose private key resides on-device.
  /// - Throws: `StampError.secureEnclaveUnavailable` or `StampError.keyNotFound(publicKeyHex:)` when appropriate.
  public convenience init(apiPublicKey: String) throws {
    try self.init(apiPublicKey: apiPublicKey, onDevicePreference: .auto)
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
        if case let .secureStorage(cfg) = self.configuration {
          let stamp = try SecureStorageStamper.stamp(
            payload: payload,
            publicKeyHex: publicKey,
            config: Self.mapSecureStorageConfig(cfg)
          )
          return ("X-Stamp", stamp)
        } else {
          let stamp = try SecureStorageStamper.stamp(
            payload: payload, publicKeyHex: publicKey)
          return ("X-Stamp", stamp)
        }
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

  /// Signs the given payload and returns only the signature (DER-encoded ECDSA in hex).
  ///
  /// - Parameter payload: The raw string payload to sign.
  /// - Returns: Signature as a hex string.
  /// - Throws: `StampError` if credentials are missing, invalid, or if passkey mode is used.
  public func sign(payload: String) async throws -> String {
    guard let payloadData = payload.data(using: .utf8) else {
      throw StampError.invalidPayload
    }
    let payloadHash = SHA256.hash(data: payloadData)

    // Route based on configured mode first
    if let mode = self.mode {
      switch mode {
      case let .apiKey(_, priv):
        return try ApiKeyStamper.sign(payload: payloadHash, privateKeyHex: priv)
      case .passkey:
        throw StampError.signNotSupportedForPasskey
      case let .secureEnclave(publicKey):
        return try SecureEnclaveStamper.sign(payload: payload, publicKeyHex: publicKey)
      case let .secureStorage(publicKey):
        if case let .secureStorage(cfg) = self.configuration {
          return try SecureStorageStamper.sign(
            payload: payload,
            publicKeyHex: publicKey,
            config: Self.mapSecureStorageConfig(cfg)
          )
        } else {
          return try SecureStorageStamper.sign(
            payload: payload,
            publicKeyHex: publicKey
          )
        }
      }
    }

    // Backward compatibility: derive from legacy properties if possible
    if let _ = apiPublicKey, let priv = apiPrivateKey {
      return try ApiKeyStamper.sign(payload: payloadHash, privateKeyHex: priv)
    }
    if passkeyManager != nil {
      throw StampError.signNotSupportedForPasskey
    }
    throw StampError.missingCredentials
  }
}

// MARK: - Config mappers
private extension Stamper {
  static func mapSecureEnclaveConfig(_ config: SecureEnclaveStamperConfig) -> SecureEnclaveStamper.SecureEnclaveConfig {
    let mappedPolicy: SecureEnclaveStamper.SecureEnclaveConfig.AuthPolicy
    switch config.authPolicy {
    case .none: mappedPolicy = .none
    case .userPresence: mappedPolicy = .userPresence
    case .biometryAny: mappedPolicy = .biometryAny
    case .biometryCurrentSet: mappedPolicy = .biometryCurrentSet
    }
    return SecureEnclaveStamper.SecureEnclaveConfig(authPolicy: mappedPolicy)
  }

  static func mapSecureStorageConfig(_ config: SecureStorageStamperConfig) -> SecureStorageStamper.SecureStorageConfig {
    let accessibility: SecureStorageStamper.SecureStorageConfig.Accessibility
    switch config.accessibility {
    case .whenUnlockedThisDeviceOnly: accessibility = .whenUnlockedThisDeviceOnly
    case .afterFirstUnlockThisDeviceOnly: accessibility = .afterFirstUnlockThisDeviceOnly
    case .whenPasscodeSetThisDeviceOnly: accessibility = .whenPasscodeSetThisDeviceOnly
    }

    let acp: SecureStorageStamper.SecureStorageConfig.AccessControlPolicy
    switch config.accessControlPolicy {
    case .none: acp = .none
    case .userPresence: acp = .userPresence
    case .biometryAny: acp = .biometryAny
    case .biometryCurrentSet: acp = .biometryCurrentSet
    case .devicePasscode: acp = .devicePasscode
    }

    return SecureStorageStamper.SecureStorageConfig(
      accessibility: accessibility,
      accessControlPolicy: acp,
      authPrompt: config.authPrompt,
      biometryReuseWindowSeconds: config.biometryReuseWindowSeconds,
      synchronizable: config.synchronizable,
      accessGroup: config.accessGroup
    )
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
