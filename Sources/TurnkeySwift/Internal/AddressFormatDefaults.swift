import Foundation
import TurnkeyHttp

// Maps AddressFormat to default payload encoding and hash function.
// Values mirror sdk-core addressFormatConfig for parity across platforms.
struct AddressFormatDefaults {
    struct Defaults {
        let encoding: PayloadEncoding
        let hashFunction: HashFunction
    }

    static func defaults(for addressFormat: AddressFormat) -> Defaults {
        switch addressFormat {
        case .ADDRESS_FORMAT_UNCOMPRESSED,
             .ADDRESS_FORMAT_COMPRESSED:
            return .init(encoding: .PAYLOAD_ENCODING_HEXADECIMAL, hashFunction: .HASH_FUNCTION_SHA256)

        case .ADDRESS_FORMAT_ETHEREUM:
            return .init(encoding: .PAYLOAD_ENCODING_HEXADECIMAL, hashFunction: .HASH_FUNCTION_KECCAK256)

        case .ADDRESS_FORMAT_SOLANA,
             .ADDRESS_FORMAT_SUI,
             .ADDRESS_FORMAT_APTOS,
             .ADDRESS_FORMAT_TON_V3R2,
             .ADDRESS_FORMAT_TON_V4R2,
             .ADDRESS_FORMAT_TON_V5R1,
             .ADDRESS_FORMAT_XLM:
            return .init(encoding: .PAYLOAD_ENCODING_HEXADECIMAL, hashFunction: .HASH_FUNCTION_NOT_APPLICABLE)

        case .ADDRESS_FORMAT_COSMOS,
             .ADDRESS_FORMAT_SEI:
            return .init(encoding: .PAYLOAD_ENCODING_TEXT_UTF8, hashFunction: .HASH_FUNCTION_SHA256)

        case .ADDRESS_FORMAT_TRON,
             .ADDRESS_FORMAT_BITCOIN_MAINNET_P2PKH,
             .ADDRESS_FORMAT_BITCOIN_MAINNET_P2SH,
             .ADDRESS_FORMAT_BITCOIN_MAINNET_P2WPKH,
             .ADDRESS_FORMAT_BITCOIN_MAINNET_P2WSH,
             .ADDRESS_FORMAT_BITCOIN_MAINNET_P2TR,
             .ADDRESS_FORMAT_BITCOIN_TESTNET_P2PKH,
             .ADDRESS_FORMAT_BITCOIN_TESTNET_P2SH,
             .ADDRESS_FORMAT_BITCOIN_TESTNET_P2WPKH,
             .ADDRESS_FORMAT_BITCOIN_TESTNET_P2WSH,
             .ADDRESS_FORMAT_BITCOIN_TESTNET_P2TR,
             .ADDRESS_FORMAT_BITCOIN_SIGNET_P2PKH,
             .ADDRESS_FORMAT_BITCOIN_SIGNET_P2SH,
             .ADDRESS_FORMAT_BITCOIN_SIGNET_P2WPKH,
             .ADDRESS_FORMAT_BITCOIN_SIGNET_P2WSH,
             .ADDRESS_FORMAT_BITCOIN_SIGNET_P2TR,
             .ADDRESS_FORMAT_BITCOIN_REGTEST_P2PKH,
             .ADDRESS_FORMAT_BITCOIN_REGTEST_P2SH,
             .ADDRESS_FORMAT_BITCOIN_REGTEST_P2WPKH,
             .ADDRESS_FORMAT_BITCOIN_REGTEST_P2WSH,
             .ADDRESS_FORMAT_BITCOIN_REGTEST_P2TR,
             .ADDRESS_FORMAT_DOGE_MAINNET,
             .ADDRESS_FORMAT_DOGE_TESTNET,
             .ADDRESS_FORMAT_XRP:
            return .init(encoding: .PAYLOAD_ENCODING_HEXADECIMAL, hashFunction: .HASH_FUNCTION_SHA256)
        }
    }
}


