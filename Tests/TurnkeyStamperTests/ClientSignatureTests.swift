import Foundation
import Testing
import TurnkeyTypes

@testable import TurnkeySwift

struct ClientSignatureTests {
  private let verificationToken =
    "eyJhbGciOiJub25lIn0.eyJjb250YWN0IjoiYWxpY2VAZXhhbXBsZS5jb20iLCJleHAiOiIxNzAwMDAwMDAwIiwiaWQiOiJ0b2tlbi1pZCIsInB1YmxpY19rZXkiOiJ0b2tlbi1wdWJsaWMta2V5IiwidmVyaWZpY2F0aW9uX3R5cGUiOiJPVFBfVFlQRV9FTUFJTCIsIm9yZ2FuaXphdGlvbl9pZCI6Im9yZy1pZCJ9.signature"

  @Test
  func loginV2SignatureMatchesDirectOtpLoginRequest() throws {
    let result = try ClientSignature.forLoginV2(
      verificationToken: verificationToken,
      organizationId: "org-id",
      sessionPublicKey: "session-public-key",
      invalidateExisting: true,
      expirationSeconds: "3600"
    )
    let request = TOtpLoginBody(
      organizationId: "org-id",
      clientSignature: clientSignature(for: result),
      expirationSeconds: "3600",
      invalidateExisting: true,
      publicKey: "session-public-key",
      verificationToken: verificationToken
    )

    let payload = try jsonObject(result.message)
    let usage = try #require(payload["loginV2"] as? [String: Any])

    #expect(result.clientSignaturePublicKey == "token-public-key")
    #expect(payload["tokenId"] as? String == "token-id")
    #expect(payload["type"] as? String == "USAGE_TYPE_LOGIN")
    #expect(usage["organizationId"] as? String == request.organizationId)
    #expect(usage["publicKey"] as? String == request.publicKey)
    #expect(usage["invalidateExisting"] as? Bool == request.invalidateExisting)
    #expect(usage["expirationSeconds"] as? String == request.expirationSeconds)
    #expect(usage["sessionProfileId"] == nil)
  }

  @Test
  func authProxyOtpLoginSignatureRemainsLegacyWhenExpirationIsUnknown() throws {
    let result = try TurnkeyContext.clientSignatureForAuthProxyOtpLogin(
      verificationToken: verificationToken
    )

    let payload = try jsonObject(result.message)

    #expect(payload["login"] != nil)
    #expect(payload["loginV2"] == nil)
  }

  @Test
  func loginV2SignaturePreservesOptionalFieldPresence() throws {
    let result = try ClientSignature.forLoginV2(
      verificationToken: verificationToken,
      organizationId: "org-id",
      invalidateExisting: false,
      sessionProfileId: "session-profile-id"
    )

    let payload = try jsonObject(result.message)
    let usage = try #require(payload["loginV2"] as? [String: Any])

    #expect(usage["invalidateExisting"] as? Bool == false)
    #expect(usage["expirationSeconds"] == nil)
    #expect(usage["sessionProfileId"] as? String == "session-profile-id")
  }

  @Test
  func loginV2SignatureRejectsEmptyOrganizationId() {
    #expect(throws: TurnkeySwiftError.self) {
      try ClientSignature.forLoginV2(
        verificationToken: verificationToken,
        organizationId: "  "
      )
    }
  }

  @Test
  func signupV3SignatureMatchesCreateSubOrganizationRequest() throws {
    let rootUser = v1RootUserParamsV5(
      apiKeys: [],
      authenticators: [],
      oauthProviders: [],
      userName: ""
    )
    let wallet = v1WalletParams(accounts: [], walletName: "")
    let result = try ClientSignature.forSignupV3(
      verificationToken: verificationToken,
      parentOrganizationId: "parent-org-id",
      subOrganizationName: "",
      rootUsers: [rootUser],
      rootQuorumThreshold: 1,
      wallet: wallet,
      disableEmailRecovery: true,
      disableEmailAuth: false,
      disableSmsAuth: true,
      disableOtpEmailAuth: false
    )
    let request = TCreateSubOrganizationBody(
      organizationId: "parent-org-id",
      clientSignature: clientSignature(for: result),
      disableEmailAuth: false,
      disableEmailRecovery: true,
      disableOtpEmailAuth: false,
      disableSmsAuth: true,
      rootQuorumThreshold: 1,
      rootUsers: [rootUser],
      subOrganizationName: "",
      verificationToken: verificationToken,
      wallet: wallet
    )

    let payload = try jsonObject(result.message)
    let usage = try #require(payload["signupV3"] as? [String: Any])
    let rootUsers = try #require(usage["rootUsers"] as? [[String: Any]])
    let encodedRootUser = try #require(rootUsers.first)
    let encodedWallet = try #require(usage["wallet"] as? [String: Any])

    #expect(result.clientSignaturePublicKey == "token-public-key")
    #expect(payload["tokenId"] as? String == "token-id")
    #expect(payload["type"] as? String == "USAGE_TYPE_SIGNUP")
    #expect(usage["parentOrganizationId"] as? String == request.organizationId)
    #expect(usage["subOrganizationName"] as? String == request.subOrganizationName)
    #expect(usage["rootQuorumThreshold"] as? Int == request.rootQuorumThreshold)
    #expect(encodedRootUser["userName"] as? String == "")
    #expect((encodedRootUser["apiKeys"] as? [Any])?.isEmpty == true)
    #expect((encodedRootUser["authenticators"] as? [Any])?.isEmpty == true)
    #expect((encodedRootUser["oauthProviders"] as? [Any])?.isEmpty == true)
    #expect((encodedWallet["accounts"] as? [Any])?.isEmpty == true)
    #expect(encodedWallet["walletName"] as? String == "")
    #expect(usage["disableEmailRecovery"] as? Bool == request.disableEmailRecovery)
    #expect(usage["disableEmailAuth"] as? Bool == request.disableEmailAuth)
    #expect(usage["disableSmsAuth"] as? Bool == request.disableSmsAuth)
    #expect(usage["disableOtpEmailAuth"] as? Bool == request.disableOtpEmailAuth)
  }

  private func clientSignature(
    for result: (message: String, clientSignaturePublicKey: String)
  ) -> v1ClientSignature {
    v1ClientSignature(
      message: result.message,
      publicKey: result.clientSignaturePublicKey,
      scheme: .client_signature_scheme_api_p256,
      signature: "signature"
    )
  }

  private func jsonObject(_ message: String) throws -> [String: Any] {
    let data = try #require(message.data(using: .utf8))
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }
}
