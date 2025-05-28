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
    map { String(format: "%02x", $0) }.joined()
  }

  public func base64URLEncodedString() -> String {
    let base64String = self.base64EncodedString()
    return
      base64String
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .trimmingCharacters(in: CharacterSet(charactersIn: "="))
  }

  public init?(base64URLEncoded: String) {
    let paddedBase64 =
      base64URLEncoded
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")

    let paddingLength = (4 - paddedBase64.count % 4) % 4
    let paddedBase64String = paddedBase64 + String(repeating: "=", count: paddingLength)

    guard let data = Data(base64Encoded: paddedBase64String) else {
      return nil
    }

    self = data
  }

  public static func decodeHex(_ hex: String) throws -> Data {
    guard hex.count % 2 == 0 else {
      throw TurnkeyDecodingError.oddLengthString
    }

    var data = Data()
    var bytePair = ""

    for char in hex {
      bytePair.append(char)
      if bytePair.count == 2 {
        guard let byte = UInt8(bytePair, radix: 16) else {
          throw TurnkeyDecodingError.invalidHexCharacter
        }
        data.append(byte)
        bytePair = ""
      }
    }

    return data
  }
}
