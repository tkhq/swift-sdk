import AuthenticationServices
import CryptoKit
import Foundation
import Testing

@testable import TurnkeyCrypto
@testable import TurnkeyEncoding
@testable import TurnkeyStamper

#if canImport(UIKit)
  import UIKit
#endif
#if canImport(AppKit)
  import AppKit
#endif

struct TurnkeyStamperConfigInitTests {

  @Test
  func testApiKeyConfigInitializerAndStamp() async throws {
    let pair = TurnkeyCrypto.generateP256KeyPair()
    let cfg = ApiKeyStamperConfig(
      apiPublicKey: pair.publicKeyCompressed, apiPrivateKey: pair.privateKey)
    let stamper = Stamper(config: cfg)
    let result = try await stamper.stamp(payload: "hello")
    #expect(result.stampHeaderName == "X-Stamp")
    #expect(!result.stampHeaderValue.isEmpty)
  }

  @Test
  @MainActor
  func testPasskeyConfigInitializer() throws {
    #if canImport(UIKit)
      let window = UIWindow(frame: .zero)
      let cfg = PasskeyStamperConfig(rpId: "example.com", presentationAnchor: window)
      _ = Stamper(config: cfg)
    #elseif canImport(AppKit)
      let window = NSWindow()
      let cfg = PasskeyStamperConfig(rpId: "example.com", presentationAnchor: window)
      _ = Stamper(config: cfg)
    #else
      throw Skip("Passkey anchor type not supported on this platform.")
    #endif
  }

  @Test
  func testSecureStorageConfigInitializerCreatesKeyAndStamps() async throws {
    // Use a prompt-free config; defaults suffice
    let cfg = SecureStorageStamperConfig()
    let stamper = try Stamper(config: cfg)
    let result = try await stamper.stamp(payload: "hello")
    #expect(result.stampHeaderName == "X-Stamp")
    #expect(!result.stampHeaderValue.isEmpty)
  }

  @Test
  func testOnDevicePreferenceAutoCreatesKeyAndStamps() async throws {
    let stamper = try Stamper(onDevicePreference: .auto)
    let result = try await stamper.stamp(payload: "hello")
    #expect(result.stampHeaderName == "X-Stamp")
    #expect(!result.stampHeaderValue.isEmpty)
  }

  @Test(arguments: [AttestedStampScheme.p256OIDC, .p256VerificationToken])
  func testAttestedStamperSignsPayload(_ scheme: AttestedStampScheme) async throws {
    let pair = TurnkeyCrypto.generateP256KeyPair()
    let stamper = Stamper(
      config: ApiKeyStamperConfig(
        apiPublicKey: pair.publicKeyCompressed,
        apiPrivateKey: pair.privateKey
      )
    )
    let attestedStamper = AttestedStamper(
      attestedIdentity: "verification-token",
      scheme: scheme,
      stamper: stamper
    )

    let result = try await attestedStamper.stamp(payload: "hello")
    #expect(result.stampHeaderName == "X-Stamp-Attested")

    let stampData = try #require(Data(base64URLEncoded: result.stampHeaderValue))
    let stamp = try #require(
      JSONSerialization.jsonObject(with: stampData) as? [String: String]
    )
    #expect(stamp["publicKeyAttestation"] == "verification-token")
    #expect(stamp["scheme"] == scheme.rawValue)
    #expect(stamp["publicKey"] == pair.publicKeyCompressed)
    let signatureHex = try #require(stamp["signature"])
    let signatureData = try #require(Data(hexString: signatureHex))
    let publicKeyData = try #require(Data(hexString: pair.publicKeyUncompressed))
    let key = try P256.Signing.PublicKey(x963Representation: publicKeyData)
    let signature = try P256.Signing.ECDSASignature(derRepresentation: signatureData)
    #expect(key.isValidSignature(signature, for: SHA256.hash(data: Data("hello".utf8))))
    #expect(!key.isValidSignature(signature, for: SHA256.hash(data: Data("changed".utf8))))
  }
}
