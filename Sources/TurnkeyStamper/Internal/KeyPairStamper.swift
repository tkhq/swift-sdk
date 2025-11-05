import Foundation

/// Protocol defining the core key pair management interface for stampers.
///
/// Both `SecureEnclaveStamper` and `SecureStorageStamper` conform to this protocol,
/// ensuring consistent API surface for key generation, deletion, listing, and stamping.
///
/// Note: Each stamper may provide additional config-based overloads beyond this protocol
/// to support their specific features (e.g., SecureStorage has config overloads for all
/// operations to support access groups and access control policies).
protocol KeyPairStamper {
  /// Configuration type for this stamper (e.g., `SecureEnclaveConfig`, `SecureStorageConfig`)
  associatedtype Config
  
  /// List all stored public keys (compressed hex format).
  static func listKeyPairs() throws -> [String]
  
  /// Clear all stored key pairs.
  static func clearKeyPairs() throws
  
  /// Create a new key pair with default configuration, returning the public key (compressed hex).
  static func createKeyPair() throws -> String
  
  /// Create a new key pair with custom configuration, returning the public key (compressed hex).
  static func createKeyPair(config: Config) throws -> String
  
  /// Delete a specific key pair by its public key.
  static func deleteKeyPair(publicKeyHex: String) throws
  
  /// Generate a cryptographic stamp for the given payload using the specified key.
  static func stamp(payload: String, publicKeyHex: String) throws -> String
}
