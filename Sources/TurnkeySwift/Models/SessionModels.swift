import Foundation
import TurnkeyTypes

public enum AuthState{
    case loading
    case authenticated
    case unAuthenticated
}

public enum SessionType: String, Codable {
    case readWrite = "SESSION_TYPE_READ_WRITE"
    case readOnly = "SESSION_TYPE_READ_ONLY"
}

// this is what the jwt returned by Turnkey decodes to
public struct TurnkeySession: Codable, Equatable {
    public let exp: TimeInterval
    public let publicKey: String
    public let sessionType: SessionType
    public let userId: String
    public let organizationId: String
    
    enum CodingKeys: String, CodingKey {
        case exp
        case publicKey = "public_key"
        case sessionType = "session_type"
        case userId = "user_id"
        case organizationId = "organization_id"
    }
}

// TurnkeySession with an added raw JWT token
// for people that are doing backend authentication
public struct Session: Codable, Equatable, Identifiable {
    public let exp: TimeInterval
    public let publicKey: String
    public let sessionType: SessionType
    public let userId: String
    public let organizationId: String
    public let token: String?

    public var id: String { publicKey }

    enum CodingKeys: String, CodingKey {
        case exp
        case publicKey = "public_key"
        case sessionType = "session_type"
        case userId = "user_id"
        case organizationId = "organization_id"
        case token
    }
}




public struct Wallet: Identifiable, Codable {
    public let walletId: String
    public let walletName: String
    public let createdAt: String
    public let updatedAt: String
    public let exported: Bool
    public let imported: Bool
    public let accounts: [v1WalletAccount]
    
    public var id: String { walletId }
}

