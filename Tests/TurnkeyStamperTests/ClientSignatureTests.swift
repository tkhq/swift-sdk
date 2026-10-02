import Foundation
import Testing
import TurnkeySwift
import TurnkeyTypes

struct ClientSignatureTests {
  private let verificationToken =
    "eyJhbGciOiJub25lIn0.eyJjb250YWN0IjoiYWxpY2VAZXhhbXBsZS5jb20iLCJleHAiOiIxNzAwMDAwMDAwIiwiaWQiOiJ0b2tlbi1pZCIsInB1YmxpY19rZXkiOiJ0b2tlbi1wdWJsaWMta2V5IiwidmVyaWZpY2F0aW9uX3R5cGUiOiJPVFBfVFlQRV9FTUFJTCIsIm9yZ2FuaXphdGlvbl9pZCI6Im9yZy1pZCJ9.signature"

  @Test
  func loginV2SignatureBindsTheFinalLoginRequest() throws {
    let result = try ClientSignature.forLoginV2(
      verificationToken: verificationToken,
      organizationId: "org-id",
      sessionPublicKey: "session-public-key",
      invalidateExisting: true,
      expirationSeconds: "3600",
      sessionProfileId: "session-profile-id"
    )

    let payload = try jsonObject(result.message)
    let usage = try #require(payload["loginV2"] as? [String: Any])

    #expect(result.clientSignaturePublicKey == "token-public-key")
    #expect(payload["tokenId"] as? String == "token-id")
    #expect(payload["type"] as? String == "USAGE_TYPE_LOGIN")
    #expect(usage["organizationId"] as? String == "org-id")
    #expect(usage["publicKey"] as? String == "session-public-key")
    #expect(usage["invalidateExisting"] as? Bool == true)
    #expect(usage["expirationSeconds"] as? String == "3600")
    #expect(usage["sessionProfileId"] as? String == "session-profile-id")
  }

  @Test
  func signupV3SignatureEmitsRequiredEmptyStringsAndArrays() throws {
    let rootUser = v1RootUserParamsV5(
      apiKeys: [],
      authenticators: [],
      oauthProviders: [],
      userName: ""
    )
    let result = try ClientSignature.forSignupV3(
      verificationToken: verificationToken,
      parentOrganizationId: "",
      subOrganizationName: "",
      rootUsers: [rootUser],
      rootQuorumThreshold: 1,
      wallet: v1WalletParams(accounts: [], walletName: ""),
      disableEmailRecovery: true,
      disableEmailAuth: false,
      disableSmsAuth: true,
      disableOtpEmailAuth: false
    )

    let payload = try jsonObject(result.message)
    let usage = try #require(payload["signupV3"] as? [String: Any])
    let rootUsers = try #require(usage["rootUsers"] as? [[String: Any]])
    let encodedRootUser = try #require(rootUsers.first)
    let wallet = try #require(usage["wallet"] as? [String: Any])

    #expect(result.clientSignaturePublicKey == "token-public-key")
    #expect(payload["tokenId"] as? String == "token-id")
    #expect(payload["type"] as? String == "USAGE_TYPE_SIGNUP")
    #expect(usage["parentOrganizationId"] as? String == "")
    #expect(usage["subOrganizationName"] as? String == "")
    #expect(usage["rootQuorumThreshold"] as? Int == 1)
    #expect(encodedRootUser["userName"] as? String == "")
    #expect((encodedRootUser["apiKeys"] as? [Any])?.isEmpty == true)
    #expect((encodedRootUser["authenticators"] as? [Any])?.isEmpty == true)
    #expect((encodedRootUser["oauthProviders"] as? [Any])?.isEmpty == true)
    #expect((wallet["accounts"] as? [Any])?.isEmpty == true)
    #expect(wallet["walletName"] as? String == "")
    #expect(usage["disableEmailRecovery"] as? Bool == true)
    #expect(usage["disableEmailAuth"] as? Bool == false)
    #expect(usage["disableSmsAuth"] as? Bool == true)
    #expect(usage["disableOtpEmailAuth"] as? Bool == false)
  }

  private func jsonObject(_ message: String) throws -> [String: Any] {
    let data = try #require(message.data(using: .utf8))
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }
}
