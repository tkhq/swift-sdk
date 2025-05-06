//
//  SessionManager.swift
//  Tracks active Secure-Enclave keys & their expiration.
//  NOTE: Initial stub for Step-0; logic will be filled in subsequent steps.
//

import CryptoKit
import Foundation
import Security

/// Represents a session with a key tag and expiration date.
public struct Session: Codable, Equatable {
  public let keyTag: String
  public let expiresAt: Date

  public init(keyTag: String, expiresAt: Date) {
    self.keyTag = keyTag
    self.expiresAt = expiresAt
  }
}

/// Coordinates session lifecycle on device.
public final class SessionManager {
  public static let shared = SessionManager()

  private init() {}

  /// Key under which session data is stored in the Keychain
  private let sessionKey = "com.turnkey.sdk.session"

  /// Saves a session to the Keychain as JSON.
  public func save(session: Session) throws {
    let encoder = JSONEncoder()
    let data = try encoder.encode(session)

    // Query for existing item
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: sessionKey,
    ]

    // Attributes to update or add
    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
    ]

    // Attempt to update existing item
    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      // If item not found, add new item
      var newItem = query
      newItem.merge(attributes) { (_, new) in new }
      let addStatus = SecItemAdd(newItem as CFDictionary, nil)
      if addStatus != errSecSuccess {
        throw NSError(domain: "SessionManager", code: Int(addStatus), userInfo: nil)
      }
    } else if status != errSecSuccess {
      throw NSError(domain: "SessionManager", code: Int(status), userInfo: nil)
    }
  }

  /// Loads the active session from the Keychain.
  public func loadActiveSession() -> Session? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: sessionKey,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else {
      return nil
    }
    let decoder = JSONDecoder()
    if let session = try? decoder.decode(Session.self, from: data) {
      // Check if session is still valid
      if session.expiresAt > Date() {
        return session
      } else {
        // Session expired, delete and return nil
        _ = try? deleteSession()
        return nil
      }
    }
    return nil
  }

  /// Deletes the session from the Keychain.
  public func deleteSession() throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: sessionKey,
    ]
    let status = SecItemDelete(query as CFDictionary)
    if status != errSecSuccess && status != errSecItemNotFound {
      throw NSError(domain: "SessionManager", code: Int(status), userInfo: nil)
    }
  }

  /// Returns the currently active session if present & unexpired.
  public func activeSession() -> Session? {
    return loadActiveSession()
  }

  /// Forces deletion of the stored session and any associated key material.
  public func resetSession() {
    try? deleteSession()
  }

  /// Ensures a valid session is available, creating a new one if necessary.
  @discardableResult
  public func ensureActiveSession() throws -> Session {
    if let session = loadActiveSession() {
      return session
    } else {
      // Create a new session by generating a key using SecureEnclaveKeyManager
      let keyManager = SecureEnclaveKeyManager()
      let tag = try keyManager.createKeypair()
      // Create a new session with a 7-day expiration (604800 seconds)
      let newSession = Session(keyTag: tag, expiresAt: Date().addingTimeInterval(604800))
      try save(session: newSession)
      return newSession
    }
  }

  /// Signs the given request data by hashing it and then using the active session's key from the Secure Enclave.
  /// - Parameter request: The request data to sign.
  /// - Returns: A tuple containing the signature and the corresponding public key.
  /// - Throws: Propagates any errors from key generation, signing, or public key retrieval.
  public func signRequest(_ request: Data) throws -> (signature: Data, publicKey: Data) {
    // Canonicalize the request by computing its SHA256 hash
    let hash = SHA256.hash(data: request)
    let hashData = Data(hash)

    // Ensure there is an active session, creating one if necessary
    let session = try ensureActiveSession()

    // Initialize the secure enclave key manager
    let keyManager = SecureEnclaveKeyManager()

    // Sign the hash using the key associated with the current session
    let signature = try keyManager.sign(tag: session.keyTag, data: hashData)

    // Retrieve the public key for the current session
    let publicKey = try keyManager.publicKey(tag: session.keyTag)

    return (signature, publicKey)
  }
}
