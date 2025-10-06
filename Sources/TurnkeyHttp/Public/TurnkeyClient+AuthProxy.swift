// Generated using Sourcery 2.2.7 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession
import TurnkeyAuthProxyAPI

extension TurnkeyClient {

  public func proxyGetAccount(
    filterType: String, filterValue: String, verificationToken: String?
  ) async throws -> Operations.GetAccount.Output.Ok {

    guard let authProxyClient else {
      throw TurnkeyRequestError.clientNotConfigured("authProxyClient")
    }

    // Create the ProxyGetAccountRequest
    let getAccountRequest = Components.Schemas.ProxyGetAccountRequest(
      filterType: filterType, filterValue: filterValue, verificationToken: verificationToken
    )

    let input = Operations.GetAccount.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getAccountRequest)
    )

    return try await call { try await authProxyClient.GetAccount(input) }

  }
  public func proxyOAuth2Authenticate(
    provider: Components.Schemas.ProxyOauth2Provider, authCode: String, redirectUri: String,
    codeVerifier: String, nonce: String?, clientId: String
  ) async throws -> Operations.OAuth2Authenticate.Output.Ok {

    guard let authProxyClient else {
      throw TurnkeyRequestError.clientNotConfigured("authProxyClient")
    }

    // Create the ProxyOAuth2AuthenticateRequest
    let oAuth2AuthenticateRequest = Components.Schemas.ProxyOAuth2AuthenticateRequest(
      provider: provider, authCode: authCode, redirectUri: redirectUri, codeVerifier: codeVerifier,
      nonce: nonce, clientId: clientId
    )

    let input = Operations.OAuth2Authenticate.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(oAuth2AuthenticateRequest)
    )

    return try await call { try await authProxyClient.OAuth2Authenticate(input) }

  }
  public func proxyOAuthLogin(
    oidcToken: String, publicKey: String, invalidateExisting: Bool?, organizationId: String?
  ) async throws -> Operations.OAuthLogin.Output.Ok {

    guard let authProxyClient else {
      throw TurnkeyRequestError.clientNotConfigured("authProxyClient")
    }

    // Create the ProxyOAuthLoginRequest
    let oAuthLoginRequest = Components.Schemas.ProxyOAuthLoginRequest(
      oidcToken: oidcToken, publicKey: publicKey, invalidateExisting: invalidateExisting,
      organizationId: organizationId
    )

    let input = Operations.OAuthLogin.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(oAuthLoginRequest)
    )

    return try await call { try await authProxyClient.OAuthLogin(input) }

  }
  public func proxyInitOtp(
    otpType: String, contact: String
  ) async throws -> Operations.InitOtp.Output.Ok {

    guard let authProxyClient else {
      throw TurnkeyRequestError.clientNotConfigured("authProxyClient")
    }

    // Create the ProxyInitOtpRequest
    let initOtpRequest = Components.Schemas.ProxyInitOtpRequest(
      otpType: otpType, contact: contact
    )

    let input = Operations.InitOtp.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(initOtpRequest)
    )

    return try await call { try await authProxyClient.InitOtp(input) }

  }
  public func proxyOtpLogin(
    verificationToken: String, publicKey: String, invalidateExisting: Bool?,
    organizationId: String?, clientSignature: String?
  ) async throws -> Operations.OtpLogin.Output.Ok {

    guard let authProxyClient else {
      throw TurnkeyRequestError.clientNotConfigured("authProxyClient")
    }

    // Create the ProxyOtpLoginRequest
    let otpLoginRequest = Components.Schemas.ProxyOtpLoginRequest(
      verificationToken: verificationToken, publicKey: publicKey,
      invalidateExisting: invalidateExisting, organizationId: organizationId,
      clientSignature: clientSignature
    )

    let input = Operations.OtpLogin.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(otpLoginRequest)
    )

    return try await call { try await authProxyClient.OtpLogin(input) }

  }
  public func proxyVerifyOtp(
    otpId: String, otpCode: String, publicKey: String?
  ) async throws -> Operations.VerifyOtp.Output.Ok {

    guard let authProxyClient else {
      throw TurnkeyRequestError.clientNotConfigured("authProxyClient")
    }

    // Create the ProxyVerifyOtpRequest
    let verifyOtpRequest = Components.Schemas.ProxyVerifyOtpRequest(
      otpId: otpId, otpCode: otpCode, publicKey: publicKey
    )

    let input = Operations.VerifyOtp.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(verifyOtpRequest)
    )

    return try await call { try await authProxyClient.VerifyOtp(input) }

  }
  public func proxySignup(
    userEmail: String?, userPhoneNumber: String?, userTag: String?, userName: String?,
    organizationName: String?, verificationToken: String?,
    apiKeys: [Components.Schemas.ProxyApiKeyParamsV2],
    authenticators: [Components.Schemas.ProxyAuthenticatorParamsV2],
    oauthProviders: [Components.Schemas.ProxyOauthProviderParams],
    wallet: Components.Schemas.ProxyWalletParams?
  ) async throws -> Operations.Signup.Output.Ok {

    guard let authProxyClient else {
      throw TurnkeyRequestError.clientNotConfigured("authProxyClient")
    }

    // Create the ProxySignupRequest
    let signupRequest = Components.Schemas.ProxySignupRequest(
      userEmail: userEmail, userPhoneNumber: userPhoneNumber, userTag: userTag, userName: userName,
      organizationName: organizationName, verificationToken: verificationToken, apiKeys: apiKeys,
      authenticators: authenticators, oauthProviders: oauthProviders, wallet: wallet
    )

    let input = Operations.Signup.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(signupRequest)
    )

    return try await call { try await authProxyClient.Signup(input) }

  }
  public func proxyGetWalletKitConfig() async throws -> Operations.GetWalletKitConfig.Output.Ok {

    guard let authProxyClient else {
      throw TurnkeyRequestError.clientNotConfigured("authProxyClient")
    }

    // Create the ProxyGetWalletKitConfigRequest
    let getWalletKitConfigRequest = Components.Schemas.ProxyGetWalletKitConfigRequest()

    let input = Operations.GetWalletKitConfig.Input(
      headers: .init(accept: [.init(contentType: .json)]),
      body: .json(getWalletKitConfigRequest)
    )

    return try await call { try await authProxyClient.GetWalletKitConfig(input) }

  }
}
