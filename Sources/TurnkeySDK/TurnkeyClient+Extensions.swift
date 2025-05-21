// Sources/TurnkeySDK/TurnkeyClient+Convenience.swift

import AuthenticationServices
import CryptoKit
import Foundation
import Middleware
import OpenAPIURLSession
import Shared

extension TurnkeyClient {
  /// Initializes a `TurnkeyClient` with a proxy server URL.
  /// - Parameter proxyURL: The URL of the proxy server.
  public init(proxyURL: String) {
    self.init(
      underlyingClient: Client(
        serverURL: URL(string: TurnkeyClient.baseURLString)!,
        transport: URLSessionTransport(),
        middlewares: [ProxyMiddleware(proxyURL: URL(string: proxyURL)!)]
      )
    )
  }

  /// Initializes a `TurnkeyClient` with API keys for authentication.
  public init(
    apiPrivateKey: String, apiPublicKey: String, baseUrl: String = TurnkeyClient.baseURLString
  ) {
    let stamper = Stamper(apiPublicKey: apiPublicKey, apiPrivateKey: apiPrivateKey)
    self.init(
      underlyingClient: Client(
        serverURL: URL(string: baseUrl)!,
        transport: URLSessionTransport(),
        middlewares: [AuthStampMiddleware(stamper: stamper)]
      )
    )
  }

  /// Initializes a `TurnkeyClient` using on-device session credentials.
  public init() {
    let stamper = Stamper()
    self.init(
      underlyingClient: Client(
        serverURL: URL(string: TurnkeyClient.baseURLString)!,
        transport: URLSessionTransport(),
        middlewares: [AuthStampMiddleware(stamper: stamper)]
      )
    )
  }

  /// Creates an instance of the TurnkeyClient that uses passkeys for authentication.
  public init(
    rpId: String, presentationAnchor: ASPresentationAnchor,
    baseUrl: String = TurnkeyClient.baseURLString
  ) {
    let stamper = Stamper(rpId: rpId, presentationAnchor: presentationAnchor)
    self.init(
      underlyingClient: Client(
        serverURL: URL(string: baseUrl)!,
        transport: URLSessionTransport(),
        middlewares: [AuthStampMiddleware(stamper: stamper)]
      )
    )
  }

  /// Authentication result type for flows that return keys.
  public struct AuthResult {
    var whoamiResponse: Components.Schemas.GetWhoamiResponse
    var apiPublicKey: String
    var apiPrivateKey: String
  }

  /// Performs email-based authentication for an organization.
  public func emailAuth(
    organizationId: String,
    email: String,
    apiKeyName: String?,
    expirationSeconds: String?,
    emailCustomization: Components.Schemas.EmailCustomizationParams?,
    invalidateExisting: Bool?
  ) async throws -> (Operations.EmailAuth.Output, (String) async throws -> AuthResult) {
    let (ephemeralPrivateKey, targetPublicKey) = try AuthHelpers.generateEphemeralKeyAgreement()

    let response = try await emailAuth(
      organizationId: organizationId,
      email: email,
      targetPublicKey: targetPublicKey,
      apiKeyName: apiKeyName,
      expirationSeconds: expirationSeconds,
      emailCustomization: emailCustomization,
      invalidateExisting: invalidateExisting
    )
    let authResponseOrganizationId = try response.ok.body.json.activity.organizationId

    let verify: (String) async throws -> AuthResult = { encryptedBundle in
      let (privateKey, publicKey) = try TurnkeyCrypto.decryptCredentialBundle(
        encryptedBundle: encryptedBundle,
        ephemeralPrivateKey: ephemeralPrivateKey
      )

      let apiPublicKey = try publicKey.toString(representation: PublicKeyRepresentation.compressed)
      let apiPrivateKey = try privateKey.toString(representation: PrivateKeyRepresentation.raw)

      let turnkeyClient = TurnkeyClient(apiPrivateKey: apiPrivateKey, apiPublicKey: apiPublicKey)

      let whoamiResponse = try await turnkeyClient.getWhoami(
        organizationId: authResponseOrganizationId
      )

      return AuthResult(
        whoamiResponse: try whoamiResponse.body.json,
        apiPublicKey: apiPublicKey,
        apiPrivateKey: apiPrivateKey
      )
    }

    return (response, verify)
  }

  /// Asynchronously logs in using on-device credentials and configures the client to sign requests.
  public func login(
    userId: String? = nil,
    organizationId: String? = nil,
    expirationSeconds: Int = 3600
  ) async throws -> TurnkeyClient {
    if let session = SessionManager.shared.loadActiveSession(), session.expiresAt > Date() {
      return TurnkeyClient()
    }

    let storedSession = SessionManager.shared.loadSessionIgnoringExpiration()
    guard let orgIdForSession = organizationId ?? storedSession?.organizationId else {
      throw NSError(
        domain: "TurnkeyClient", code: 1,
        userInfo: [
          NSLocalizedDescriptionKey: "organizationId is required when no previous session exists"
        ])
    }

    let (ephemeralPrivateKey, targetPublicKey) = try AuthHelpers.generateEphemeralKeyAgreement()
    let sessionResponse = try await createReadWriteSession(
      organizationId: orgIdForSession,
      targetPublicKey: targetPublicKey,
      userId: userId,
      apiKeyName: "session-key",
      expirationSeconds: String(expirationSeconds)
    )
    let responseBody = try sessionResponse.ok.body.json
    guard let result = responseBody.activity.result.createReadWriteSessionResultV2 else {
      throw NSError(
        domain: "TurnkeyClient", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Missing createReadWriteSessionResultV2"])
    }
    let organizationId = result.organizationId
    let userId = result.userId

    let (decryptedPrivateKey, decryptedPublicKey) = try TurnkeyCrypto.decryptCredentialBundle(
      encryptedBundle: result.credentialBundle,
      ephemeralPrivateKey: ephemeralPrivateKey
    )
    let tempApiPublicKey = try decryptedPublicKey.toString(
      representation: PublicKeyRepresentation.compressed)
    let tempApiPrivateKey = try decryptedPrivateKey.toString(
      representation: PrivateKeyRepresentation.raw)

    let tempClient = TurnkeyClient(apiPrivateKey: tempApiPrivateKey, apiPublicKey: tempApiPublicKey)

    let keyManager = SecureEnclaveKeyManager()
    let keyTag = try keyManager.createKeypair()
    let publicKeyData = try keyManager.publicKey(tag: keyTag)
    let publicKeyHex = publicKeyData.toHexString()

    let apiKeyParams = [
      Components.Schemas.ApiKeyParamsV2(
        apiKeyName: "Session Key \(Int(Date().timeIntervalSince1970))",
        publicKey: publicKeyHex,
        curveType: .API_KEY_CURVE_P256,
        expirationSeconds: String(expirationSeconds)
      )
    ]
    _ = try await tempClient.createApiKeys(
      organizationId: organizationId,
      apiKeys: apiKeyParams,
      userId: userId
    )

    let expiresAt = Date().addingTimeInterval(TimeInterval(expirationSeconds))
    let newSession = Session(
      keyTag: keyTag, expiresAt: expiresAt, userId: userId, organizationId: organizationId)
    try SessionManager.shared.save(session: newSession)

    return TurnkeyClient()
  }
}
