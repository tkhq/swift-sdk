import Foundation
import CryptoKit
import Shared

/// In-memory `KeyManager` implementation for unit tests.
/// Avoids Keychain/Secure Enclave access so tests run anywhere (CI, macOS, simulator).
final class InMemoryKeyManagerMock: KeyManager {
    private struct Pair { var priv: Data; var pub: Data }
    private var store: [String: Pair] = [:]

    func createKeypair() throws -> String {
        let tag = UUID().uuidString
        var priv = Data(count: 32)
        _ = priv.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        // Fake uncompressed public key (0x04 + random XY)
        var pub = Data([0x04])
        var xy = Data(count: 64)
        _ = xy.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 64, $0.baseAddress!) }
        pub.append(xy)
        store[tag] = Pair(priv: priv, pub: pub)
        return tag
    }

    func publicKey(tag: String) throws -> Data {
        guard let pair = store[tag] else { throw NSError(domain: "InMem", code: 1) }
        return pair.pub
    }

    func sign(tag: String, data: Data) throws -> Data {
        // Produce predictable 64-byte signature for assertions
        let hash = SHA256.hash(data: data)
        return Data(hash) + Data(repeating: 0, count: 32 - 0) // pad to 64 bytes
    }
}
