import Foundation
import CryptoSwift
import BigInt


struct Ethereum {
    static let rpcURL = URL(string: "https://rpc.sepolia.org")!
    static let coingeckoURL = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd")!
    
    static func getBalance(for address: String) async throws -> Double {
        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "eth_getBalance",
            "params": [address, "latest"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct Response: Decodable {
            let result: String?
            let error: RPCError?
        }
        
        struct RPCError: Decodable {
            let code: Int
            let message: String
        }
        
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        
        if let error = decoded.error {
            throw NSError(domain: "eth.rpc", code: error.code, userInfo: [NSLocalizedDescriptionKey: error.message])
        }
        
        guard let result = decoded.result else {
            throw NSError(domain: "eth.rpc", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing result in response"])
        }
        
        let weiHex = result.stripHexPrefix()
        guard let wei = UInt64(weiHex, radix: 16) else {
            throw NSError(domain: "eth.rpc", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid hex: \(weiHex)"])
        }
        
        return Double(wei) / pow(10, 18)
    }
    
    static func getETHPriceUSD() async throws -> Double {
        let (data, _) = try await URLSession.shared.data(from: coingeckoURL)
        
        struct PriceResponse: Decodable {
            let ethereum: [String: Double]
        }
        
        let response = try JSONDecoder().decode(PriceResponse.self, from: data)
        return response.ethereum["usd"] ?? 0
    }
    
    static func keccak256Digest(of message: String) -> Data {
        Data(message.utf8).sha3(.keccak256)
    }
    
    
    
}

private extension String {
    func stripHexPrefix() -> String {
        hasPrefix("0x") ? String(dropFirst(2)) : self
    }
}
