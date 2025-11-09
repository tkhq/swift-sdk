import Testing
@testable import TurnkeyStamper
@testable import TurnkeyCrypto
import AuthenticationServices
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
    let cfg = ApiKeyStamperConfig(apiPublicKey: pair.publicKeyCompressed, apiPrivateKey: pair.privateKey)
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
}


