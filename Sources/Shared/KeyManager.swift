//  KeyManager.swift
//  Abstraction over key storage/signing backends (Secure Enclave or Keychain).
//
import Foundation

/// Abstracts the minimal operations `SessionManager` needs from a key backend.
public protocol KeyManager {
  /// Generate a new key-pair and return the persistent tag used to retrieve it later.
  func createKeypair() throws -> String

  /// Sign arbitrary data with the private key identified by `tag`.
  func sign(tag: String, data: Data) throws -> Data

  /// Retrieve the raw public-key bytes (ANSI X9.63) for the key identified by `tag`.
  func publicKey(tag: String) throws -> Data
}
