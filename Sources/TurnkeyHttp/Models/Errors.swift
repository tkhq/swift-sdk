import Foundation
import HTTPTypes

/// A unified SDK-level error type that surfaces common failure modes in a
/// structured, test-friendly way. Internal implementation-specific errors
/// (e.g., `StampError`, `AuthError`) should be bridged to `TurnkeyError` at the
/// public API boundary.
public enum TurnkeyError: LocalizedError, Sendable {

  /// Any error returned by the Turnkey HTTP API (status ≥ 400).
  case apiError(statusCode: Int?, payload: Data?)

  /// Non-HTTP failures produced inside the SDK (e.g., crypto, keychain).
  case sdkError(Error)

  /// Transport-level or underlying networking error (URLSession, etc.).
  case network(Error)

  /// Response was missing expected content or could not be decoded.
  case invalidResponse

  /// Fallback for uncategorized or unknown errors.
  case unknown(Error)

  /// Returns the associated HTTP status code for `.apiError`.
  public var statusCode: Int? {
    if case let .apiError(code, _) = self {
      return code
    }
    return nil
  }

  /// Returns the payload data for `.apiError`, if present.
  public var payload: Data? {
    if case let .apiError(_, data) = self {
      return data
    }
    return nil
  }

  /// Human-readable error description.
  public var errorDescription: String? {
    switch self {
    case .apiError:
      return "Turnkey API returned an error response."
    case .sdkError(let err):
      return err.localizedDescription
    case .network(let err):
      return err.localizedDescription
    case .invalidResponse:
      return "Invalid response from server."
    case .unknown(let err):
      return err.localizedDescription
    }
  }

  /// Creates a `TurnkeyError` from an HTTP response. Only use for status codes ≥ 400.
  public init(httpResponse: HTTPResponse, body: Data?) {
    let code = httpResponse.status.code
    if (400..<600).contains(code) {
      self = .apiError(statusCode: code, payload: body)
    } else {
      self = .unknown(NSError(domain: "TurnkeyError", code: code, userInfo: nil))
    }
  }

  /// Wraps any error as a `TurnkeyError`, preserving known `TurnkeyError`s.
  public init(_ error: Error) {
    if let err = error as? TurnkeyError {
      self = err
    } else {
      self = .unknown(error)
    }
  }
}

extension TurnkeyError: Equatable {
  public static func == (lhs: TurnkeyError, rhs: TurnkeyError) -> Bool {
    switch (lhs, rhs) {
    case let (.apiError(s1, p1), .apiError(s2, p2)):
      return s1 == s2 && p1 == p2
    case (.invalidResponse, .invalidResponse):
      return true
    // `.sdkError` and `.network`/`.unknown` are not reliably comparable
    default:
      return false
    }
  }
}
