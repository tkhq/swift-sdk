// Generated using Sourcery 2.3.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

public struct AuthProxyClient {
  public static let baseURLString = "https://authproxy.turnkey.com"

  private let underlyingClient: any APIProtocol

  internal init(underlyingClient: any APIProtocol) {
    self.underlyingClient = underlyingClient
  }
  public func getAccount(
    filterType: String,
    filterValue: String
  ) async throws
    -> Operations.GetAccount.Output.Ok
  {

    // Create the GetAccountRequest
    let getAccountRequest = Components.Schemas.GetAccountRequest(
      filterType: filterType, filterValue: filterValue
    )

    let input = Operations.GetAccount.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getAccountRequest)
    )

    return try await call { try await underlyingClient.GetAccount(input) }

  }
  public func oAuth2Authenticate(
    provider: Components.Schemas.Oauth2Provider,
    authCode: String,
    redirectUri: String,
    codeVerifier: String,
    nonce: String?,
    clientId: String
  ) async throws
    -> Operations.OAuth2Authenticate.Output.Ok
  {

    // Create the OAuth2AuthenticateRequest
    let oAuth2AuthenticateRequest = Components.Schemas.OAuth2AuthenticateRequest(
      provider: provider, authCode: authCode, redirectUri: redirectUri, codeVerifier: codeVerifier,
      nonce: nonce, clientId: clientId
    )

    let input = Operations.OAuth2Authenticate.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(oAuth2AuthenticateRequest)
    )

    return try await call { try await underlyingClient.OAuth2Authenticate(input) }

  }
  public func oAuthLogin(
    oidcToken: String,
    publicKey: String,
    invalidateExisting: Bool?,
    organizationId: String?
  ) async throws
    -> Operations.OAuthLogin.Output.Ok
  {

    // Create the OAuthLoginRequest
    let oAuthLoginRequest = Components.Schemas.OAuthLoginRequest(
      oidcToken: oidcToken, publicKey: publicKey, invalidateExisting: invalidateExisting,
      organizationId: organizationId
    )

    let input = Operations.OAuthLogin.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(oAuthLoginRequest)
    )

    return try await call { try await underlyingClient.OAuthLogin(input) }

  }
  public func initOtp(
    otpType: String,
    contact: String
  ) async throws
    -> Operations.InitOtp.Output.Ok
  {

    // Create the InitOtpRequest
    let initOtpRequest = Components.Schemas.InitOtpRequest(
      otpType: otpType, contact: contact
    )

    let input = Operations.InitOtp.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(initOtpRequest)
    )

    return try await call { try await underlyingClient.InitOtp(input) }

  }
  public func otpLogin(
    verificationToken: String,
    publicKey: String,
    invalidateExisting: Bool?,
    organizationId: String?,
    clientSignature: String?
  ) async throws
    -> Operations.OtpLogin.Output.Ok
  {

    // Create the OtpLoginRequest
    let otpLoginRequest = Components.Schemas.OtpLoginRequest(
      verificationToken: verificationToken, publicKey: publicKey,
      invalidateExisting: invalidateExisting, organizationId: organizationId,
      clientSignature: clientSignature
    )

    let input = Operations.OtpLogin.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(otpLoginRequest)
    )

    return try await call { try await underlyingClient.OtpLogin(input) }

  }
  public func verifyOtp(
    otpId: String,
    otpCode: String,
    publicKey: String?
  ) async throws
    -> Operations.VerifyOtp.Output.Ok
  {

    // Create the VerifyOtpRequest
    let verifyOtpRequest = Components.Schemas.VerifyOtpRequest(
      otpId: otpId, otpCode: otpCode, publicKey: publicKey
    )

    let input = Operations.VerifyOtp.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(verifyOtpRequest)
    )

    return try await call { try await underlyingClient.VerifyOtp(input) }

  }
  public func signup(
    userEmail: String?,
    userPhoneNumber: String?,
    userTag: String?,
    userName: String?,
    organizationName: String?,
    verificationToken: String?,
    apiKeys: [Components.Schemas.ApiKeyParamsV2],
    authenticators: [Components.Schemas.AuthenticatorParamsV2],
    oauthProviders: [Components.Schemas.OauthProviderParams],
    wallet: Components.Schemas.WalletParams?
  ) async throws
    -> Operations.Signup.Output.Ok
  {

    // Create the SignupRequest
    let signupRequest = Components.Schemas.SignupRequest(
      userEmail: userEmail, userPhoneNumber: userPhoneNumber, userTag: userTag, userName: userName,
      organizationName: organizationName, verificationToken: verificationToken, apiKeys: apiKeys,
      authenticators: authenticators, oauthProviders: oauthProviders, wallet: wallet
    )

    let input = Operations.Signup.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(signupRequest)
    )

    return try await call { try await underlyingClient.Signup(input) }

  }
  public func getWalletKitConfig() async throws
    -> Operations.GetWalletKitConfig.Output.Ok
  {

    // Create the GetWalletKitConfigRequest
    let getWalletKitConfigRequest = Components.Schemas.GetWalletKitConfigRequest()

    let input = Operations.GetWalletKitConfig.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getWalletKitConfigRequest)
    )

    return try await call { try await underlyingClient.GetWalletKitConfig(input) }

  }
}
