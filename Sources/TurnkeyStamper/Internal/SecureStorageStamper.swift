import CryptoKit
import Foundation
import Security
import LocalAuthentication
import TurnkeyEncoding
import TurnkeyCrypto
import TurnkeyKeyManager

/// A Keychain-backed stamper that stores private keys in the iOS Keychain as Generic Password entries with:
/// - service = public key (hex, compressed)
/// - account = "TurnkeySecureStorageStamper"
/// - label = "TurnkeyApiKeyPair"
///
/// Note:
/// Keychain queries must match how items were stored (e.g., access group, iCloud synchronizable,
/// and whether access control requiring user presence/biometry was applied). If you store with
/// non-default attributes or an access control policy, use the config-based overloads of
/// `listKeyPairs`, `clearKeyPairs`, `deleteKeyPair`, and `stamp` to ensure lookups and auth UI
/// behave as intended. If you use the defaults, the no-config methods are sufficient.
///
/// Unlike `SecureEnclaveStamper`, this stamper supports importing external key pairs via
/// `importKeyPair` methods.
enum SecureStorageStamper: KeyPairStamper {
  typealias Config = SecureStorageConfig
  
  private static let account = "TurnkeySecureStorageStamper"
  private static let label = "TurnkeyApiKeyPair"

  /// Configuration for how keys are stored and accessed from the Keychain.
  ///
  /// Defaults:
  /// - `accessibility`: `.afterFirstUnlockThisDeviceOnly` (available after first unlock, not migrated)
  /// - `accessControlPolicy`: `.none` (no per-access user prompt)
  /// - `authPrompt`: `nil` (system default prompt if needed)
  /// - `biometryReuseWindowSeconds`: `0` (no reuse window)
  /// - `synchronizable`: `false` (do not sync via iCloud Keychain)
  /// - `accessGroup`: `nil` (no shared access group)
  typealias SecureStorageConfig = SecureStorageManager.Config

  // MARK: - Public API

  static func listKeyPairs() throws -> [String] {
    return try SecureStorageManager.listKeyPairs()
  }

  /// List stored public keys using the provided config to scope lookups (e.g., access group,
  /// iCloud Keychain). Use when you stored with non-default attributes.
  static func listKeyPairs(config: SecureStorageConfig) throws -> [String] {
    return try SecureStorageManager.listKeyPairs(config: config)
  }

  static func clearKeyPairs() throws {
    for publicKey in try SecureStorageManager.listKeyPairs() {
      try SecureStorageManager.deleteKeyPair(publicKeyHex: publicKey)
    }
  }

  /// Clear stored keys using the provided config to target the correct domain (e.g., access group,
  /// iCloud Keychain). Use when you stored with non-default attributes.
  static func clearKeyPairs(config: SecureStorageConfig) throws {
    for publicKey in try SecureStorageManager.listKeyPairs(config: config) {
      try SecureStorageManager.deleteKeyPair(publicKeyHex: publicKey, config: config)
    }
  }

  static func createKeyPair() throws -> String {
    return try SecureStorageManager.createKeyPair()
  }

  static func createKeyPair(config: SecureStorageConfig) throws -> String {
    return try SecureStorageManager.createKeyPair(config: config)
  }

  /// Import an external key pair into Secure Storage with default configuration.
  ///
  /// - Parameter externalKeyPair: A tuple containing the public key (compressed hex) and private key (hex).
  /// - Returns: The public key (compressed hex) that was imported.
  static func importKeyPair(
    externalKeyPair: (publicKey: String, privateKey: String)
  ) throws -> String {
    return try SecureStorageManager.importKeyPair(externalKeyPair: externalKeyPair)
  }

  /// Import an external key pair into Secure Storage with custom configuration.
  ///
  /// - Parameters:
  ///   - externalKeyPair: A tuple containing the public key (compressed hex) and private key (hex).
  ///   - config: Configuration for keychain storage (accessibility, access control, etc.).
  /// - Returns: The public key (compressed hex) that was imported.
  static func importKeyPair(
    externalKeyPair: (publicKey: String, privateKey: String),
    config: SecureStorageConfig
  ) throws -> String {
    return try SecureStorageManager.importKeyPair(externalKeyPair: externalKeyPair, config: config)
  }

  static func deleteKeyPair(publicKeyHex: String) throws {
    try SecureStorageManager.deleteKeyPair(publicKeyHex: publicKeyHex)
  }

  /// Delete a specific key using the provided config to match how it was stored (e.g., access group,
  /// iCloud Keychain). Use when you stored with non-default attributes.
  /// Note: Does not throw if the key isn't found (treat as success).
  static func deleteKeyPair(publicKeyHex: String, config: SecureStorageConfig) throws {
    try SecureStorageManager.deleteKeyPair(publicKeyHex: publicKeyHex, config: config)
  }

  /// Sign an arbitrary payload with the private key stored in Secure Storage.
  ///
  /// - Parameters:
  ///   - payload: Raw string payload to sign.
  ///   - publicKeyHex: Compressed public key hex identifying the key.
  ///   - format: Desired signature format. Defaults to `.der`.
  /// - Returns: ECDSA signature as a hex string in the requested format.
  static func sign(
    payload: String,
    publicKeyHex: String,
    format: Stamper.SignatureFormat = .der
  ) throws -> String {
    guard let payloadData = payload.data(using: .utf8) else {
      throw SecureStorageStamperError.payloadEncodingFailed
    }
    let digest = SHA256.hash(data: payloadData)
    guard let privateKeyHex = try SecureStorageManager.getPrivateKey(publicKeyHex: publicKeyHex, config: nil) else {
      throw SecureStorageStamperError.privateKeyNotFound(publicKeyHex: publicKeyHex)
    }
    return try ApiKeyStamper.sign(
      payload: digest,
      privateKeyHex: privateKeyHex,
      format: format
    )
  }

  /// Sign an arbitrary payload with the private key stored in Secure Storage using a specific configuration.
  ///
  /// Use this when keys were stored with non-default attributes (e.g., access group, access control).
  /// - Parameters:
  ///   - payload: Raw string payload to sign.
  ///   - publicKeyHex: Compressed public key hex identifying the key.
  ///   - config: Storage configuration to match how the key was stored.
  ///   - format: Desired signature format. Defaults to `.der`.
  /// - Returns: ECDSA signature as a hex string in the requested format.
  static func sign(
    payload: String,
    publicKeyHex: String,
    config: SecureStorageConfig,
    format: Stamper.SignatureFormat = .der
  ) throws -> String {
    guard let payloadData = payload.data(using: .utf8) else {
      throw SecureStorageStamperError.payloadEncodingFailed
    }
    let digest = SHA256.hash(data: payloadData)
    guard let privateKeyHex = try SecureStorageManager.getPrivateKey(publicKeyHex: publicKeyHex, config: config) else {
      throw SecureStorageStamperError.privateKeyNotFound(publicKeyHex: publicKeyHex)
    }
    return try ApiKeyStamper.sign(
      payload: digest,
      privateKeyHex: privateKeyHex,
      format: format
    )
  }

  static func stamp(
    payload: String,
    publicKeyHex: String
  ) throws -> String {
    let signatureHex = try sign(payload: payload, publicKeyHex: publicKeyHex)
    let stamp: [String: Any] = [
      "publicKey": publicKeyHex,
      "scheme": "SIGNATURE_SCHEME_TK_API_P256",
      "signature": signatureHex,
    ]
    let jsonData = try JSONSerialization.data(withJSONObject: stamp, options: [])
    return jsonData.base64URLEncodedString()
  }

  /// Generate a stamp while honoring access control and scoping (e.g., access group, iCloud). If the
  /// key was saved with an access control policy, supply `authPrompt` and optionally a reuse window
  /// via `config` so the system can present authentication UI.
  static func stamp(
    payload: String,
    publicKeyHex: String,
    config: SecureStorageConfig
  ) throws -> String {
    let signatureHex = try sign(payload: payload, publicKeyHex: publicKeyHex, config: config)
    let stamp: [String: Any] = [
      "publicKey": publicKeyHex,
      "scheme": "SIGNATURE_SCHEME_TK_API_P256",
      "signature": signatureHex,
    ]
    let jsonData = try JSONSerialization.data(withJSONObject: stamp, options: [])
    return jsonData.base64URLEncodedString()
  }

}


