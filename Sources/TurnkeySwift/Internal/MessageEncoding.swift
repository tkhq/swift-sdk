import Foundation
import TurnkeyHttp

enum MessageEncodingHelper {
    static func ethereumPrefixed(messageData: Data) -> Data {
        // "\x19Ethereum Signed Message:\n" + message length (decimal) + message
        let prefix = "\u{0019}Ethereum Signed Message:\n" + String(messageData.count)
        var prefixed = Data(prefix.utf8)
        prefixed.append(messageData)
        return prefixed
    }

    static func encodeMessageBytes(_ bytes: Data, as encoding: PayloadEncoding) -> String {
        switch encoding {
        case .PAYLOAD_ENCODING_HEXADECIMAL:
            return "0x" + bytes.map { String(format: "%02x", $0) }.joined()
        case .PAYLOAD_ENCODING_TEXT_UTF8:
            return String(decoding: bytes, as: UTF8.self)
        @unknown default:
            return "0x" + bytes.map { String(format: "%02x", $0) }.joined()
        }
    }
}


