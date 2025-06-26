import Foundation

public enum AuthState{
    case loading
    case authenticated
    case unAuthenticated
}

public struct TurnkeySession: Codable, Equatable {
  public let exp: TimeInterval
  public let publicKey: String
  public let sessionType: String
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

public struct SessionUser: Identifiable, Codable {
  public let id: String
  public let userName: String
  public let email: String?
  public let phoneNumber: String?
  public let organizationId: String
  public let wallets: [UserWallet]

  public struct UserWallet: Codable {
    public let id: String
    public let name: String
    public let accounts: [WalletAccount]

    public struct WalletAccount: Codable {
      public let id: String
      public let curve: Curve
      public let pathFormat: PathFormat
      public let path: String
      public let addressFormat: AddressFormat
      public let address: String
      public let createdAt: Timestamp
      public let updatedAt: Timestamp
    }
  }
}
