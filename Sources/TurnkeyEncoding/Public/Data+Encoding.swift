import Foundation

extension Data {
    
    /// Initializes `Data` from a hex-encoded string.
    ///
    /// - Parameter hexString: A string containing hex characters.
    /// - Returns: `nil` if the string is not valid hex or has an odd length.
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
    
    /// Returns a hex-encoded string representation of the data.
    ///
    /// - Returns: A lowercase hex string
    public func toHexString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
    
    /// Encodes the data into a base64 URL-safe string (RFC 4648).
    ///
    /// - Returns: A base64 string using `-` and `_` instead of `+` and `/`, with `=` padding removed.
    public func base64URLEncodedString() -> String {
        let base64String = self.base64EncodedString()
        return base64String
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }
    
    /// Initializes `Data` from a base64 URL-safe encoded string.
    ///
    /// - Parameter base64URLEncoded: A base64 string using `-` and `_` instead of `+` and `/`.
    /// - Returns: `nil` if the string is invalid base64 or can't be decoded.
    public init?(base64URLEncoded: String) {
        let paddedBase64 = base64URLEncoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let paddingLength = (4 - paddedBase64.count % 4) % 4
        let paddedBase64String = paddedBase64 + String(repeating: "=", count: paddingLength)
        
        guard let data = Data(base64Encoded: paddedBase64String) else {
            return nil
        }
        
        self = data
    }
    
    /// Decodes a hex string into a `Data` instance.
    ///
    /// - Parameter hex: A hex-encoded string (must be even-length).
    /// - Throws: `TurnkeyDecodingError.oddLengthString` or `TurnkeyDecodingError.invalidHexCharacter`.
    /// - Returns: The decoded data.
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
    
    /// Generates a `Data` instance with cryptographically secure random bytes.
    ///
    /// - Parameter count: The number of random bytes to generate.
    /// - Returns: Randomly generated `Data` of the specified length.
    public static func random(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }
}
