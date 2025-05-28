import Foundation
import TurnkeyHttp

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
      public let curve: Components.Schemas.Curve
      public let pathFormat: Components.Schemas.PathFormat
      public let path: String
      public let addressFormat: Components.Schemas.AddressFormat
      public let address: String
      public let createdAt: Components.Schemas.external_period_data_period_v1_period_Timestamp
      public let updatedAt: Components.Schemas.external_period_data_period_v1_period_Timestamp
    }
  }
}
