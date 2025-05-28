public enum KeyFormat {
  case other
  case solana
}

public struct BundleOuter: Decodable {
  let enclaveQuorumPublic: String
  let dataSignature: String
  let data: String
}

public struct SignedInner: Decodable {
  let organizationId: String?
  let userId: String?
  let encappedPublic: String?
  let targetPublic: String?
  let ciphertext: String?
}
