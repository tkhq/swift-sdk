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
        case .address_format_uncompressed,
             .address_format_compressed:
            return .init(encoding: .payload_encoding_hexadecimal, hashFunction: .hash_function_sha256)

        case .address_format_ethereum:
            return .init(encoding: .payload_encoding_hexadecimal, hashFunction: .hash_function_keccak256)

        case .address_format_solana,
             .address_format_sui,
             .address_format_aptos,
             .address_format_ton_v3r2,
             .address_format_ton_v4r2,
             .address_format_ton_v5r1,
             .address_format_xlm:
            return .init(encoding: .payload_encoding_hexadecimal, hashFunction: .hash_function_not_applicable)

        case .address_format_cosmos,
             .address_format_sei:
            return .init(encoding: .payload_encoding_text_utf8, hashFunction: .hash_function_sha256)

        case .address_format_tron,
             .address_format_bitcoin_mainnet_p2pkh,
             .address_format_bitcoin_mainnet_p2sh,
             .address_format_bitcoin_mainnet_p2wpkh,
             .address_format_bitcoin_mainnet_p2wsh,
             .address_format_bitcoin_mainnet_p2tr,
             .address_format_bitcoin_testnet_p2pkh,
             .address_format_bitcoin_testnet_p2sh,
             .address_format_bitcoin_testnet_p2wpkh,
             .address_format_bitcoin_testnet_p2wsh,
             .address_format_bitcoin_testnet_p2tr,
             .address_format_bitcoin_signet_p2pkh,
             .address_format_bitcoin_signet_p2sh,
             .address_format_bitcoin_signet_p2wpkh,
             .address_format_bitcoin_signet_p2wsh,
             .address_format_bitcoin_signet_p2tr,
             .address_format_bitcoin_regtest_p2pkh,
             .address_format_bitcoin_regtest_p2sh,
             .address_format_bitcoin_regtest_p2wpkh,
             .address_format_bitcoin_regtest_p2wsh,
             .address_format_bitcoin_regtest_p2tr,
             .address_format_doge_mainnet,
             .address_format_doge_testnet,
             .address_format_xrp:
            return .init(encoding: .payload_encoding_hexadecimal, hashFunction: .hash_function_sha256)
        }
    }
}


