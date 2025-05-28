import Foundation

struct JWTDecoder {
  static func decode<T: Decodable>(_ jwt: String, as type: T.Type) throws -> T {
    // split the JWT into three Base-64URL sections
    let parts = jwt.split(separator: ".")
    guard parts.count == 3 else { throw SessionStoreError.invalidJWT }

    // take the payload part and convert to base-64
    var b = parts[1]
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    b.append(String(repeating: "=", count: (4 - b.count % 4) % 4))

    // decode
    guard let data = Data(base64Encoded: b) else { throw SessionStoreError.invalidJWT }
    return try JSONDecoder().decode(T.self, from: data)
  }
}
