import CryptoKit
import Foundation

extension Data {
  public init?(hexString: String) {
    let len = hexString.count / 2
    var data = Data(capacity: len)
    for i in 0..<len {
      let j = hexString.index(hexString.startIndex, offsetBy: i * 2)
      let k = hexString.index(j, offsetBy: 2)
      let bytes = hexString[j..<k]
      if var num = UInt8(bytes, radix: 16) {
        data.append(&num, count: 1)
      } else {
        return nil
      }
    }
    self = data
  }

  public func toHexString() -> String {
    return map { String(format: "%02x", $0) }.joined()
  }

  public func base64URLEncodedString() -> String {
    let base64String = self.base64EncodedString()
    let base64URLString =
      base64String
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    return base64URLString
  }
  /// Initializes `Data` by decoding a base64 URL encoded string.
  /// - Parameter base64URLEncoded: The base64 URL encoded string.
  /// - Returns: An optional `Data` instance if the string is valid and successfully decoded, otherwise `nil`.
  public init?(base64URLEncoded: String) {
    let paddedBase64 =
      base64URLEncoded
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    // Adjust the string to ensure it's a multiple of 4 for valid base64 decoding
    let paddingLength = (4 - paddedBase64.count % 4) % 4
    let paddedBase64String = paddedBase64 + String(repeating: "=", count: paddingLength)
    guard let data = Data(base64Encoded: paddedBase64String) else {
      return nil
    }
    self = data
  }
}

extension String {
  public var hex: some Sequence<UInt8> {
    self[...].hex
  }

  public var hexData: Data {
    return Data(hex)
  }
}

extension Substring {
  public var hex: some Sequence<UInt8> {
    sequence(
      state: self,
      next: { remainder in
        guard remainder.count > 2 else { return nil }
        let nextTwo = remainder.prefix(2)
        remainder.removeFirst(2)
        return UInt8(nextTwo, radix: 16)
      })
  }
}

enum KeyError: Error {
  case representationUnavailable(String)
}

public enum PublicKeyRepresentation {
  case raw
  case x963
  case compressed
  case compact
}

extension P256.Signing.PublicKey {
  /// Converts the public key into the specified string representation.
  ///
  /// - Parameter representation: The desired representation of the key.
  /// - Returns: A string representation of the public key in the specified format.
  /// - Throws: `KeyError.representationUnavailable` if the desired representation is not available.
  public func toString(representation: PublicKeyRepresentation) throws -> String {
    switch representation {
    case .raw:
      return rawRepresentation.toHexString()
    case .x963:
      return x963Representation.toHexString()
    case .compressed:
      if #available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *) {
        return compressedRepresentation.toHexString()
      } else {
        throw KeyError.representationUnavailable("Compressed representation is unavailable.")
      }
    case .compact:
      return compactRepresentation?.toHexString() ?? ""
    }
  }
}

public enum PrivateKeyRepresentation {
  case raw
  case x963
}

extension P256.Signing.PrivateKey {
  /// Converts the private key into the specified string representation.
  ///
  /// - Parameter representation: The desired representation of the key.
  /// - Returns: A string representation of the private key in the specified format.
  /// - Throws: `KeyError.representationUnavailable` if the desired representation is not available.
  public func toString(representation: PrivateKeyRepresentation) throws -> String {
    switch representation {
    case .raw:
      return rawRepresentation.toHexString()
    case .x963:
      return x963Representation.toHexString()
    }
  }
}
