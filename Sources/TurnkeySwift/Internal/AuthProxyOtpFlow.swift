import Foundation
import TurnkeyHttp
import TurnkeyTypes

/// The Auth Proxy operations required by an OTP authentication flow.
///
/// An `AuthProxyOtpFlow` receives one instance for its entire lifetime so its configuration lookup,
/// signatures, and requests always use the same Auth Proxy client snapshot.
internal protocol AuthProxyOtpClient {
  func proxyGetWalletKitConfig(_ input: ProxyTGetWalletKitConfigBody) async throws
    -> ProxyTGetWalletKitConfigResponse
  func proxyOtpLoginV2(_ input: ProxyTOtpLoginV2Body) async throws -> ProxyTOtpLoginV2Response
  func proxySignupV2(_ input: ProxyTSignupV2Body) async throws -> ProxyTSignupV2Response
}

extension TurnkeyClient: AuthProxyOtpClient {}

internal typealias AuthProxyOtpSigner = (String, String) async throws -> String

/// Executes OTP login and signup against one captured Auth Proxy client.
internal struct AuthProxyOtpFlow {
  private let client: any AuthProxyOtpClient
  private let sign: AuthProxyOtpSigner
  private let fetchWalletKitConfig: Bool

  init(
    client: any AuthProxyOtpClient,
    fetchWalletKitConfig: Bool,
    sign: @escaping AuthProxyOtpSigner
  ) {
    self.client = client
    self.fetchWalletKitConfig = fetchWalletKitConfig
    self.sign = sign
  }

  func loginWithOtp(
    verificationToken: String,
    organizationId: String?,
    invalidateExisting: Bool
  ) async throws -> String {
    try await loginWithOtp(
      verificationToken: verificationToken,
      organizationId: organizationId,
      invalidateExisting: invalidateExisting,
      walletKitConfig: await walletKitConfig()
    )
  }

  func signUpWithOtp(
    verificationToken: String,
    signupBody: ProxyTSignupV2Body,
    invalidateExisting: Bool
  ) async throws -> String {
    let walletKitConfig = await walletKitConfig()
    let signaturePayload: (message: String, clientSignaturePublicKey: String)

    if let parentOrganizationId = walletKitConfig?.organizationId,
      !parentOrganizationId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      hasStrictSignupInputs(signupBody)
    {
      signaturePayload = try ClientSignature.forSignupV3(
        verificationToken: verificationToken,
        parentOrganizationId: parentOrganizationId,
        signup: signupBody
      )
    } else {
      signaturePayload = try ClientSignature.forSignup(
        verificationToken: verificationToken,
        email: signupBody.userEmail,
        phoneNumber: signupBody.userPhoneNumber,
        apiKeys: signupBody.apiKeys,
        authenticators: signupBody.authenticators,
        oauthProviders: signupBody.oauthProviders
      )
    }

    let signedSignupBody = try await addingClientSignature(
      to: signupBody,
      signaturePayload: signaturePayload
    )
    let signupResponse = try await client.proxySignupV2(signedSignupBody)

    return try await loginWithOtp(
      verificationToken: verificationToken,
      organizationId: signupResponse.organizationId,
      invalidateExisting: invalidateExisting,
      walletKitConfig: walletKitConfig
    )
  }

  private func loginWithOtp(
    verificationToken: String,
    organizationId: String?,
    invalidateExisting: Bool,
    walletKitConfig: ProxyTGetWalletKitConfigResponse?
  ) async throws -> String {
    let signaturePayload: (message: String, clientSignaturePublicKey: String)

    if let organizationId,
      !organizationId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let expirationSeconds = walletKitConfig?.sessionExpirationSeconds,
      !expirationSeconds.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      signaturePayload = try ClientSignature.forLoginV2(
        verificationToken: verificationToken,
        organizationId: organizationId,
        invalidateExisting: invalidateExisting,
        expirationSeconds: expirationSeconds
      )
    } else {
      signaturePayload = try ClientSignature.forLogin(verificationToken: verificationToken)
    }

    let signature = try await sign(
      signaturePayload.message,
      signaturePayload.clientSignaturePublicKey
    )

    let clientSignature = v1ClientSignature(
      message: signaturePayload.message,
      publicKey: signaturePayload.clientSignaturePublicKey,
      scheme: .client_signature_scheme_api_p256,
      signature: signature
    )
    let response = try await client.proxyOtpLoginV2(
      ProxyTOtpLoginV2Body(
        clientSignature: clientSignature,
        invalidateExisting: invalidateExisting,
        organizationId: organizationId,
        publicKey: signaturePayload.clientSignaturePublicKey,
        verificationToken: verificationToken
      ))

    return response.session
  }

  private func walletKitConfig() async -> ProxyTGetWalletKitConfigResponse? {
    guard fetchWalletKitConfig else {
      return nil
    }

    do {
      return try await client.proxyGetWalletKitConfig(ProxyTGetWalletKitConfigBody())
    } catch {
      return nil
    }
  }

  private func addingClientSignature(
    to signupBody: ProxyTSignupV2Body,
    signaturePayload: (message: String, clientSignaturePublicKey: String)
  ) async throws -> ProxyTSignupV2Body {
    let signature = try await sign(
      signaturePayload.message,
      signaturePayload.clientSignaturePublicKey
    )
    let clientSignature = v1ClientSignature(
      message: signaturePayload.message,
      publicKey: signaturePayload.clientSignaturePublicKey,
      scheme: .client_signature_scheme_api_p256,
      signature: signature
    )

    return ProxyTSignupV2Body(
      apiKeys: signupBody.apiKeys,
      authenticators: signupBody.authenticators,
      clientSignature: clientSignature,
      oauthProviders: signupBody.oauthProviders,
      organizationName: signupBody.organizationName,
      userEmail: signupBody.userEmail,
      userName: signupBody.userName,
      userPhoneNumber: signupBody.userPhoneNumber,
      userTag: signupBody.userTag,
      verificationToken: signupBody.verificationToken,
      wallet: signupBody.wallet
    )
  }

  private func hasStrictSignupInputs(_ signupBody: ProxyTSignupV2Body) -> Bool {
    guard let organizationName = signupBody.organizationName,
      let userName = signupBody.userName
    else {
      return false
    }

    return !organizationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}
