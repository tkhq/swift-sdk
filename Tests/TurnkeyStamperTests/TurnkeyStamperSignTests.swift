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
  func testApiKeySignRawReturns64ByteHexAndVerifies() async throws {
    let pair = TurnkeyCrypto.generateP256KeyPair()
    let cfg = ApiKeyStamperConfig(apiPublicKey: pair.publicKeyCompressed, apiPrivateKey: pair.privateKey)
    let stamper = Stamper(config: cfg)
    let sigRawHex = try await stamper.sign(payload: "hello", format: .raw)
    #expect(!sigRawHex.isEmpty)
    let hexChars = "0123456789abcdefABCDEF"
    #expect(sigRawHex.allSatisfy { hexChars.contains($0) })
    #expect(sigRawHex.count == 128) // 64 bytes R||S in hex
    let messageData = Data("hello".utf8)
    let digest = SHA256.hash(data: messageData)
    if
      let pubData = Data(hexString: pair.publicKeyUncompressed),
      let rawData = Data(hexString: sigRawHex),
      let pubKey = try? P256.Signing.PublicKey(x963Representation: pubData),
      let signature = try? P256.Signing.ECDSASignature(rawRepresentation: rawData)
    {
      #expect(pubKey.isValidSignature(signature, for: digest))
    } else {
      #expect(Bool(false), "Failed to construct public key or signature for verification (raw)")
    }
  }

  @Test
  func testApiKeySignRawRoundTripsViaDER() async throws {
    let pair = TurnkeyCrypto.generateP256KeyPair()
    let cfg = ApiKeyStamperConfig(apiPublicKey: pair.publicKeyCompressed, apiPrivateKey: pair.privateKey)
    let stamper = Stamper(config: cfg)
    let sigRawHex = try await stamper.sign(payload: "hello", format: .raw)
    if
      let rawData = Data(hexString: sigRawHex),
      let sig = try? P256.Signing.ECDSASignature(rawRepresentation: rawData)
    {
      let der = sig.derRepresentation
      let sig2 = try? P256.Signing.ECDSASignature(derRepresentation: der)
      #expect(sig2?.rawRepresentation == rawData)
    } else {
      #expect(Bool(false), "Failed to parse RAW or DER for round-trip")
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

  @Test
  func testSecureStorageSignRawReturns64ByteHexAndVerifies() async throws {
    let pub = try Stamper.createSecureStorageKeyPair()
    let stamper = try Stamper(apiPublicKey: pub, onDevicePreference: .secureStorage)
    let sigRawHex = try await stamper.sign(payload: "hello", format: .raw)
    #expect(!sigRawHex.isEmpty)
    let hexChars = "0123456789abcdefABCDEF"
    #expect(sigRawHex.allSatisfy { hexChars.contains($0) })
    #expect(sigRawHex.count == 128)
    let messageData = Data("hello".utf8)
    let digest = SHA256.hash(data: messageData)
    if
      let pubData = Data(hexString: pub),
      let rawData = Data(hexString: sigRawHex),
      let pubKey = try? P256.Signing.PublicKey(compressedRepresentation: pubData),
      let signature = try? P256.Signing.ECDSASignature(rawRepresentation: rawData)
    {
      #expect(pubKey.isValidSignature(signature, for: digest))
    } else {
      #expect(Bool(false), "Failed to construct public key or signature for verification (raw)")
    }
  }

  @Test
  func testSecureEnclaveSignRawIfSupported() async throws {
    if !SecureEnclaveStamper.isSupported() {
      // Skip-like behavior without relying on Skip type; treat as no-op on unsupported platforms.
      return
    }
    let pub = try Stamper.createSecureEnclaveKeyPair()
    let stamper = try Stamper(apiPublicKey: pub, onDevicePreference: .secureEnclave)
    let sigDerHex = try await stamper.sign(payload: "hello") // default .der
    let sigRawHex = try await stamper.sign(payload: "hello", format: .raw)
    // Validate DER verifies
    do {
      let messageData = Data("hello".utf8)
      let digest = SHA256.hash(data: messageData)
      if
        let pubData = Data(hexString: pub),
        let derData = Data(hexString: sigDerHex),
        let pubKey = try? P256.Signing.PublicKey(compressedRepresentation: pubData),
        let sigDer = try? P256.Signing.ECDSASignature(derRepresentation: derData)
      {
        #expect(pubKey.isValidSignature(sigDer, for: digest))
      } else {
        #expect(Bool(false), "Failed to construct DER signature/public key for verification (SE)")
      }
    }
    // Validate RAW verifies
    do {
      let messageData = Data("hello".utf8)
      let digest = SHA256.hash(data: messageData)
      if
        let pubData = Data(hexString: pub),
        let rawData = Data(hexString: sigRawHex),
        let pubKey = try? P256.Signing.PublicKey(compressedRepresentation: pubData),
        let sigRaw = try? P256.Signing.ECDSASignature(rawRepresentation: rawData)
      {
        #expect(pubKey.isValidSignature(sigRaw, for: digest))
      } else {
        #expect(Bool(false), "Failed to construct RAW signature/public key for verification (SE)")
      }
    }
  }
}


