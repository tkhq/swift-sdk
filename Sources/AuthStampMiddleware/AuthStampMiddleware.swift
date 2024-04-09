import OpenAPIRuntime
import Foundation
import HTTPTypes
import CryptoKit

package struct AuthStampMiddleware {
    private let apiPrivateKey: String
    private let apiPublicKey: String

    package init(apiPrivateKey: String, apiPublicKey: String) {
        self.apiPrivateKey = apiPrivateKey
        self.apiPublicKey = apiPublicKey
    }
}

extension AuthStampMiddleware: ClientMiddleware {

    package func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        
        var request = request

        // Define the maximum number of bytes you're willing to collect
        let maxBytes = 1_000_000
        
        var bodyString = ""
        if let body = body {
            bodyString = try await String(collecting: body, upTo: maxBytes)
            
            let stamp = try await turnkeyStamp(data: bodyString)
            
            let stampHeader = HTTPField(name: HTTPField.Name("X-Stamp")!, value: stamp)
            request.headerFields.append(stampHeader)
        }

        return try await next(request, body, baseURL)
    }

    func turnkeyStamp(data: String) async throws -> String {
        // Convert the hex string to Data
        guard let privateKeyData = Data(hexString: apiPrivateKey) else {
            fatalError("Invalid hex string")
        }


        guard let privateKey = try? P256.Signing.PrivateKey(rawRepresentation: privateKeyData) else {
            throw TurnkeyError.invalidPrivateKey
        }

        let derivedPublicKey = privateKey.publicKey.compressedRepresentation.toHexString()
        _ = privateKey.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()

        if derivedPublicKey != apiPublicKey {
            throw TurnkeyError.mismatchedPublicKey(expected: apiPublicKey, actual: derivedPublicKey)
        }
        
        let dataHash = SHA256.hash(data: data.data(using: .utf8)!)
        let signature = try privateKey.signature(for: dataHash)
        let signatureHex = signature.derRepresentation.toHexString()
        
        let stamp: [String: Any] = [
            "publicKey": apiPublicKey,
            "scheme": "SIGNATURE_SCHEME_TK_API_P256",
            "signature": signatureHex
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: stamp, options: [])
        let base64Stamp = jsonData.base64URLEncodedString()
        
        return base64Stamp
    }

    private func decodeHex(_ hex: String) throws -> Data {
        guard hex.count % 2 == 0 else {
            throw DecodingError.oddLengthString
        }
        
        var data = Data()
        var bytePair = ""
        
        for char in hex {
            bytePair += String(char)
            if bytePair.count == 2 {
                guard let byte = UInt8(bytePair, radix: 16) else {
                    throw DecodingError.invalidHexCharacter
                }
                data.append(byte)
                bytePair = ""
            }
        }
        
        return data
    }

}

enum TurnkeyError: Error {
    case invalidPrivateKey
    case mismatchedPublicKey(expected: String, actual: String)
}

enum DecodingError: Error {
    case oddLengthString
    case invalidHexCharacter
}

extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        for i in 0..<len {
            let j = hexString.index(hexString.startIndex, offsetBy: i*2)
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
    func toHexString() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }
    func base64URLEncodedString() -> String {
        let base64String = self.base64EncodedString()
        let base64URLString = base64String
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        return base64URLString
    }
}

extension String {
    var hex: some Sequence<UInt8> {
        self[...].hex
    }

    var hexData: Data {
        return Data(hex)
    }
}

extension Substring {
    var hex: some Sequence<UInt8> {
        sequence(state: self, next: { remainder in
            guard remainder.count > 2 else { return nil }
            let nextTwo = remainder.prefix(2)
            remainder.removeFirst(2)
            return UInt8(nextTwo, radix: 16)
        })
    }
}
