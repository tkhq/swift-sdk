import Foundation
import Testing

@testable import TurnkeySwift

struct SessionTests {
  @Test(arguments: ["SESSION_TYPE_READ_WRITE", "SESSION_TYPE_READ_ONLY", "Passkey recovery"])
  func sessionTypeRoundTrips(_ rawValue: String) throws {
    let data = try JSONEncoder().encode(rawValue)
    let type = try JSONDecoder().decode(SessionType.self, from: data)
    #expect(type.rawValue == rawValue)
    #expect(try JSONEncoder().encode(type) == data)
    if rawValue == "Passkey recovery" {
      #expect(type == .custom(rawValue))
    }
  }

  @Test(arguments: [false, true])
  func sessionClaimsSurviveStorage(_ scoped: Bool) throws {
    var claims: [String: Any] = [
      "exp": 2_000_000_000, "public_key": "public-key", "user_id": "same-user",
      "organization_id": "same-suborg", "session_type": "SESSION_TYPE_READ_WRITE",
    ]
    if scoped {
      claims["session_type"] = "Passkey recovery"
      claims["session_profile_id"] = "recovery-profile"
      claims["scope"] = "ACTIVITY_TYPE_CREATE_AUTHENTICATORS_V2"
    }
    let payload = try JSONSerialization.data(withJSONObject: claims)
      .base64EncodedString().replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    // Turnkey session JWTs have an empty signature segment.
    let jwt = "e30.\(payload)."
    let decoded = try JWTDecoder.decode(jwt, as: TurnkeySession.self)
    #expect(decoded.sessionType == (scoped ? .custom("Passkey recovery") : .readWrite))
    #expect(decoded.sessionProfileId == (scoped ? "recovery-profile" : nil))
    #expect(decoded.scope == (scoped ? "ACTIVITY_TYPE_CREATE_AUTHENTICATORS_V2" : nil))
    #expect(decoded.userId == "same-user")
    #expect(decoded.organizationId == "same-suborg")
    #expect(try JWTDecoder.decode("e30.\(payload).signature", as: TurnkeySession.self) == decoded)
    let stored = StoredSession(decoded: decoded, jwt: jwt)
    let restored = try JSONDecoder().decode(StoredSession.self, from: JSONEncoder().encode(stored))
    #expect(restored.decoded == decoded)
    #expect(restored.jwt == jwt)
    let session = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(decoded))
    #expect(session.sessionType == decoded.sessionType)
    #expect(session.sessionProfileId == decoded.sessionProfileId)
    #expect(session.scope == decoded.scope)
  }

  @Test(arguments: ["", "e30.payload", ".payload.", "e30..", "e30.payload.extra.segment"])
  func rejectsMalformedJwt(_ jwt: String) {
    #expect(throws: (any Error).self) { try JWTDecoder.decode(jwt, as: TurnkeySession.self) }
  }

}
