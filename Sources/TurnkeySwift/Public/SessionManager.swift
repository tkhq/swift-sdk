import Combine
import CryptoKit
import Foundation
import TurnkeyCrypto
import TurnkeyHttp

#if canImport(UIKit)
  import UIKit
#endif

#if canImport(AppKit)
  import AppKit
#endif

public final class SessionManager: ObservableObject {

  // ────────────────── singleton ──────────────────
  public static let shared = SessionManager()
  private init() {
    PendingKeysStore.purge(ttlHours: 24, secureAccount: secureAccount)
    SessionRegistry.purgeExpiredSessions(secureAccount: secureAccount)

    // Defer session restore to run *after* init
    Task { [weak self] in
      await self?.rescheduleAllSessionExpiries()
      await self?.restoreSelectedSession()
    }

    if let notification = Self.foregroundNotification {
      Task.detached { [secureAccount] in
        for await _ in NotificationCenter.default.notifications(named: notification) {
          PendingKeysStore.purge(ttlHours: 24, secureAccount: secureAccount)
          SessionRegistry.purgeExpiredSessions(secureAccount: secureAccount)
        }
      }
    }
  }

  // ────────────────── observable state ───────────
  @Published public private(set) var client: TurnkeyClient?
  @Published public private(set) var selectedSessionKey: String?
  @Published public private(set) var user: SessionUser?

  // ────────────────── constants ──────────────────
  private let secureAccount = "p256-private"

  // ────────────────── in-RAM expiry timers ───────
  private var expiryTasks: [String: Task<Void, Never>] = [:]

  // MARK: - Notification (platform-aware)
  private static var foregroundNotification: Notification.Name? {
    #if os(iOS) || os(tvOS) || os(visionOS)
      return UIApplication.willEnterForegroundNotification
    #elseif os(macOS)
      return NSApplication.didBecomeActiveNotification
    #else
      return nil  // watchOS or unsupported
    #endif
  }

  // MARK: - Key-pair generation
  @discardableResult
  public func createKeyPair() throws -> String {
    let (_, publicKey, privateKey) = TurnkeyCrypto.generateP256KeyPair()

    try KeyPairStore.save(privateHex: privateKey, for: publicKey)
    PendingKeysStore.add(publicKey)
    return publicKey
  }

  public func createSession(
    jwt: String,
    sessionKey: String = "com.turnkey.sdk.session"
  ) async throws {
    let dto = try JWTDecoder.decode(jwt, as: TurnkeySession.self)
    try JWTSessionStore.save(dto, key: sessionKey)
    SessionRegistry.add(sessionKey)

    guard let privHex = KeyPairStore.getPrivateHex(for: dto.publicKey) else {
      throw SessionStoreError.keyNotFound
    }

    if selectedSessionKey == nil {
      _ = try await setSelectedSession(key: sessionKey)
    }

    scheduleExpiryTimer(for: sessionKey, expTimestamp: dto.exp)
  }

  public func signRawPayload(
    signWith: String,
    payload: String,
    encoding: Components.Schemas.PayloadEncoding,
    hashFunction: Components.Schemas.HashFunction
  ) async throws -> Components.Schemas.SignRawPayloadResult {
    guard let client = client,
      let sessionKey = selectedSessionKey,
      let dto = JWTSessionStore.load(key: sessionKey)
    else {
      throw SessionStoreError.invalidSession
    }

    do {
      let response = try await client.signRawPayload(
        organizationId: dto.organizationId,
        signWith: signWith,
        payload: payload,
        encoding: encoding,
        hashFunction: hashFunction
      )

      guard
        let signRawPayloadResult = try response.ok.body.json.activity.result.signRawPayloadResult
      else {
        throw SessionStoreError.invalidResponse
      }

      return signRawPayloadResult
    } catch {
      print("Failed to sign payload:", error)
      throw error
    }
  }

  public func refreshUser() async {
    guard let client = client,
      let sessionKey = selectedSessionKey,
      let dto = JWTSessionStore.load(key: sessionKey)
    else {
      return
    }

    do {
      let updatedUser = try await fetchSessionUser(
        using: client,
        organizationId: dto.organizationId,
        userId: dto.userId
      )
      await MainActor.run {
        self.user = updatedUser
      }
    } catch {
      print("Failed to refresh user:", error)
    }
  }

  public func updateUser(email: String? = nil, phone: String? = nil) async throws {
    guard let client = client,
      let user = user
    else {
      throw SessionStoreError.invalidSession
    }

    let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    let trimmedPhone = phone?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty

    do {
      let response = try await client.updateUser(
        organizationId: user.organizationId,
        userId: user.id,
        userName: nil,
        userEmail: trimmedEmail,
        userTagIds: [],
        userPhoneNumber: trimmedPhone
      )

      let updatedUserId = try response.ok.body.json.activity.result.updateUserResult?.userId
      if updatedUserId != nil {
        await refreshUser()
      }
    } catch let error as TurnkeyError {
      if case let .apiError(_, payload) = error,
        let data = payload,
        let json = String(data: data, encoding: .utf8)
      {
        print("Server error payload:\n\(json)")
      }
      throw error
    }
  }

  public func createWallet(
    walletName: String,
    accounts: [Components.Schemas.WalletAccountParams],
    mnemonicLength: Int32? = nil
  ) async throws {
    guard let client = client,
      let user = user
    else {
      throw SessionStoreError.invalidSession
    }

    do {
      let response = try await client.createWallet(
        organizationId: user.organizationId,
        walletName: walletName,
        accounts: accounts,
        mnemonicLength: mnemonicLength
      )

      let walletId = try response.ok.body.json.activity.result.createWalletResult?.walletId
      if walletId != nil {
        await refreshUser()
      }
    } catch let error as TurnkeyError {
      if case let .apiError(_, payload) = error,
        let data = payload,
        let json = String(data: data, encoding: .utf8)
      {
        print("Server error payload:\n\(json)")
      }
      throw error
    }
  }

  public func exportWallet(walletId: String) async throws -> String {
    // Generate a temporary keypair
    let (targetPublicKey, _, embeddedPrivateKey) = TurnkeyCrypto.generateP256KeyPair()

    guard let client = client,
      let user = user
    else {
      throw SessionStoreError.invalidSession
    }

    // Make exportWallet API call
    let response = try await client.exportWallet(
      organizationId: user.organizationId,
      walletId: walletId,
      targetPublicKey: targetPublicKey,
      language: nil
    )

    guard
      let exportBundle = try response.ok.body.json.activity.result.exportWalletResult?.exportBundle
    else {
      throw SessionStoreError.invalidResponse
    }

    // Decrypt export bundle using the embedded key
    return try TurnkeyCrypto.decryptExportBundle(
      exportBundle: exportBundle,
      organizationId: user.organizationId,
      embeddedPrivateKey: embeddedPrivateKey,
      // TODO: REMOVE ME
      dangerouslyOverrideSignerPublicKey:
        "04bce6666ca6c12e0e00a503a52c301319687dca588165b551d369496bd1189235bd8302ae5e001fde51d1e22baa1d44249f2de9705c63797316fc8b7e3969a665",
      returnMnemonic: true
    )
  }

  @discardableResult
  public func importWallet(
    walletName: String,
    mnemonic: String,
    accounts: [Components.Schemas.WalletAccountParams]
  ) async throws -> Components.Schemas.Activity {
    guard
      let client = client,
      let user = user
    else { throw SessionStoreError.invalidSession }

    let initResp = try await client.initImportWallet(
      organizationId: user.organizationId,
      userId: user.id
    )

    guard
      let importBundle = try initResp.ok.body.json
        .activity.result.initImportWalletResult?.importBundle
    else { throw SessionStoreError.invalidResponse }

    let encryptedBundle = try TurnkeyCrypto.encryptWalletToBundle(
      mnemonic: mnemonic,
      importBundle: importBundle,
      userId: user.id,
      organizationId: user.organizationId,
      dangerouslyOverrideSignerPublicKey:
        "04bce6666ca6c12e0e00a503a52c301319687dca588165b551d369496bd1189235bd8302ae5e001fde51d1e22baa1d44249f2de9705c63797316fc8b7e3969a665"
    )

    let resp = try await client.importWallet(
      organizationId: user.organizationId,
      userId: user.id,
      walletName: walletName,
      encryptedBundle: encryptedBundle,
      accounts: accounts
    )

    let activity = try resp.ok.body.json.activity

    if activity.result.importWalletResult?.walletId != nil {
      await refreshUser()
    }

    return activity
  }

  // MARK: - Clear session
  public func clearSession(for key: String? = nil) {
    let sessionKey = key ?? selectedSessionKey
    guard let sessionKey else { return }

    expiryTasks[sessionKey]?.cancel()
    expiryTasks.removeValue(forKey: sessionKey)

    if let dto = JWTSessionStore.load(key: sessionKey) {
      KeyPairStore.delete(for: dto.publicKey)
      PendingKeysStore.remove(dto.publicKey)
    }

    JWTSessionStore.delete(key: sessionKey)
    SessionRegistry.remove(sessionKey)

    // 🧠 Update observable state on main thread
    Task { @MainActor in
      if selectedSessionKey == sessionKey {
        selectedSessionKey = nil
        SelectedSessionStore.clear()
        client = nil
        user = nil
      }
    }
  }

  @discardableResult
  public func setSelectedSession(key: String) async throws -> TurnkeyClient {
    guard let dto = JWTSessionStore.load(key: key) else {
      throw SessionStoreError.keyNotFound
    }

    guard let privHex = KeyPairStore.getPrivateHex(for: dto.publicKey) else {
      throw SessionStoreError.keyNotFound
    }

    let cli = TurnkeyClient(
      apiPrivateKey: privHex, apiPublicKey: dto.publicKey, baseUrl: "http://localhost:8081")

    let fetchedUser = try await fetchSessionUser(
      using: cli, organizationId: dto.organizationId, userId: dto.userId)

    await MainActor.run {
      SelectedSessionStore.set(key)
      self.selectedSessionKey = key
      self.client = cli
      self.user = fetchedUser
    }

    return cli
  }

  private func restoreSelectedSession() async {
    guard let key = SelectedSessionStore.get(),
      JWTSessionStore.load(key: key) != nil
    else { return }

    try? await setSelectedSession(key: key)
  }

  private func rescheduleAllSessionExpiries() async {
    for key in SessionRegistry.all() {
      guard let dto = JWTSessionStore.load(key: key) else { continue }
      scheduleExpiryTimer(for: key, expTimestamp: dto.exp)
    }
  }

  private func selectSessionKeyIfNeeded(_ key: String) async {
    if selectedSessionKey == nil {
      _ = try? await setSelectedSession(key: key)
    }
  }

  private func scheduleExpiryTimer(
    for sessionKey: String,
    expTimestamp: TimeInterval
  ) {
    expiryTasks[sessionKey]?.cancel()

    let delay = expTimestamp - Date().timeIntervalSince1970 - 5
    guard delay > 0 else {
      clearSession(for: sessionKey)
      return
    }

    expiryTasks[sessionKey] = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      self?.clearSession(for: sessionKey)
    }
  }

  private func fetchSessionUser(
    using client: TurnkeyClient,
    organizationId: String,
    userId: String
  ) async throws -> SessionUser {
    guard !organizationId.isEmpty, !userId.isEmpty else {
      throw SessionStoreError.invalidResponse
    }

    do {
      // Fetch user and wallet list concurrently
      async let userResponse = client.getUser(organizationId: organizationId, userId: userId)
      async let walletsResponse = client.getWallets(organizationId: organizationId)

      let user = try await userResponse.body.json.user
      let walletsRaw = try await walletsResponse.body.json.wallets

      // Fetch wallet accounts concurrently
      let wallets = try await withThrowingTaskGroup(of: SessionUser.UserWallet.self) { group in
        for wallet in walletsRaw {
          group.addTask {
            let accounts = try await client.getWalletAccounts(
              organizationId: organizationId,
              walletId: wallet.walletId,
              paginationOptions: nil
            ).body.json.accounts.map {
              SessionUser.UserWallet.WalletAccount(
                id: $0.walletAccountId,
                curve: $0.curve,
                pathFormat: $0.pathFormat,
                path: $0.path,
                addressFormat: $0.addressFormat,
                address: $0.address,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
              )
            }

            return SessionUser.UserWallet(
              id: wallet.walletId,
              name: wallet.walletName,
              accounts: accounts
            )
          }
        }

        var collected: [SessionUser.UserWallet] = []
        for try await result in group {
          collected.append(result)
        }
        return collected
      }

      return SessionUser(
        id: user.userId,
        userName: user.userName,
        email: user.userEmail,
        phoneNumber: user.userPhoneNumber,
        organizationId: organizationId,
        wallets: wallets
      )

    } catch let error as TurnkeyError {
      if case let .apiError(_, payload) = error,
        let data = payload,
        let json = String(data: data, encoding: .utf8)
      {
        print("Server error payload:\n\(json)")
      }
      throw error
    }
  }

}
