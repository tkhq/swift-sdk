import Testing
@testable import TurnkeyStamper
@testable import TurnkeyCrypto
import AuthenticationServices
import CryptoKit
import TurnkeyEncoding
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct TurnkeyStamperSignTests {

  @Test
  func testApiKeySignReturnsHex() async throws {
    let pair = TurnkeyCrypto.generateP256KeyPair()
    let cfg = ApiKeyStamperConfig(apiPublicKey: pair.publicKeyCompressed, apiPrivateKey: pair.privateKey)
    let stamper = Stamper(config: cfg)
    let sig = try await stamper.sign(payload: "hello")
    #expect(!sig.isEmpty)
    let hexChars = "0123456789abcdefABCDEF"
    #expect(sig.allSatisfy { hexChars.contains($0) })
    // Verify signature using uncompressed public key and SHA-256 digest of message
    let messageData = Data("hello".utf8)
    let digest = SHA256.hash(data: messageData)
    if
      let pubData = Data(hexString: pair.publicKeyUncompressed),
      let sigData = Data(hexString: sig),
      let pubKey = try? P256.Signing.PublicKey(x963Representation: pubData),
      let signature = try? P256.Signing.ECDSASignature(derRepresentation: sigData)
    {
      #expect(pubKey.isValidSignature(signature, for: digest))
    } else {
      #expect(Bool(false), "Failed to construct public key or signature for verification")
    }
  }

  @Test
  @MainActor
  func testPasskeySignThrows() async throws {
    #if canImport(UIKit)
    let window = UIWindow(frame: .zero)
    let cfg = PasskeyStamperConfig(rpId: "example.com", presentationAnchor: window)
    let stamper = Stamper(config: cfg)
    do {
      _ = try await stamper.sign(payload: "hello")
      #expect(Bool(false), "Expected sign() to throw for passkey mode")
    } catch let e as StampError {
      switch e {
      case .signNotSupportedForPasskey:
        // expected
        break
      default:
        #expect(Bool(false), "Unexpected StampError: \(e)")
      }
    } catch {
      #expect(Bool(false), "Unexpected error: \(error)")
    }
    #elseif canImport(AppKit)
    let window = NSWindow()
    let cfg = PasskeyStamperConfig(rpId: "example.com", presentationAnchor: window)
    let stamper = Stamper(config: cfg)
    do {
      _ = try await stamper.sign(payload: "hello")
      #expect(Bool(false), "Expected sign() to throw for passkey mode")
    } catch let e as StampError {
      switch e {
      case .signNotSupportedForPasskey:
        // expected
        break
      default:
        #expect(Bool(false), "Unexpected StampError: \(e)")
      }
    } catch {
      #expect(Bool(false), "Unexpected error: \(error)")
    }
    #else
    throw Skip("Passkey anchor type not supported on this platform.")
    #endif
  }

  @Test
  func testSecureStorageSignReturnsHex() async throws {
    // Create a known keypair first so we have the public key available for verification
    let pub = try Stamper.createSecureStorageKeyPair()
    let stamper = try Stamper(apiPublicKey: pub, onDevicePreference: .secureStorage)
    let sig = try await stamper.sign(payload: "hello")
    #expect(!sig.isEmpty)
    let hexChars = "0123456789abcdefABCDEF"
    #expect(sig.allSatisfy { hexChars.contains($0) })
    // Verify signature using compressed public key and SHA-256 digest of message
    let messageData = Data("hello".utf8)
    let digest = SHA256.hash(data: messageData)
    if
      let pubData = Data(hexString: pub),
      let sigData = Data(hexString: sig),
      let pubKey = try? P256.Signing.PublicKey(compressedRepresentation: pubData),
      let signature = try? P256.Signing.ECDSASignature(derRepresentation: sigData)
    {
      #expect(pubKey.isValidSignature(signature, for: digest))
    } else {
      #expect(Bool(false), "Failed to construct public key or signature for verification")
    }
  }
}


