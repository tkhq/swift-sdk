import Foundation
import HTTPTypes

/// A unified SDK-level error type that surfaces common failure modes in a
/// structured, test-friendly way.  Internal implementation-specific errors
/// (e.g. `StampError`, `AuthError`) should be bridged to `TurnkeyError` at the
/// public API boundary.
public enum TurnkeyError: LocalizedError, Sendable {
  // MARK: – Cases
  /// Any error returned by the Turnkey HTTP API (status ≥ 400).
  case apiError(statusCode: Int?, payload: Data?)

  /// Non-HTTP failures produced inside the SDK (crypto, key-chain, etc.).
  case sdkError(Error)

  /// Transport-level or other underlying error (URLSession / NIO etc.).
  case network(Error)

  /// Response could not be decoded or was missing expected content.
  case invalidResponse

  /// Catch-all – should be bridged to a more specific case where possible.
  case unknown(Error)

  // MARK: – Accessors
  public var statusCode: Int? {
    switch self {
    case let .apiError(statusCode, _): return statusCode
    default: return nil
    }
  }

  public var payload: Data? {
    switch self {
    case let .apiError(_, payload): return payload
    default: return nil
    }
  }

  // MARK: – LocalizedError
  public var errorDescription: String? {
    switch self {
    case .apiError: return "Turnkey API returned an error response."
    case .sdkError(let err): return err.localizedDescription
    case let .network(error): return error.localizedDescription
    case .invalidResponse: return "Invalid response from server."
    case let .unknown(error): return error.localizedDescription
    }
  }

  // MARK: – Convenience initialisers
  /// Maps an HTTP response into a `TurnkeyError`. Should only be used for
  /// non-success (\u003E=400) responses.
  public init(httpResponse: HTTPResponse, body: Data?) {
    let code = httpResponse.status.code
    switch code {
    case 400..<600:
      self = .apiError(statusCode: code, payload: body)
    default:
      self = .unknown(NSError(domain: "TurnkeyError", code: code, userInfo: nil))
    }
  }

  /// Bridge helper for `Stamper` errors etc.
  public init(_ error: Error) {
    if let error = error as? TurnkeyError {
      self = error
    } else {
      self = .unknown(error)
    }
  }
}

// MARK: – Equatable
extension TurnkeyError: Equatable {
  public static func == (lhs: TurnkeyError, rhs: TurnkeyError) -> Bool {
    switch (lhs, rhs) {
    case let (.apiError(s1, p1), .apiError(s2, p2)):
      return s1 == s2 && p1 == p2
    case (.invalidResponse, .invalidResponse):
      return true
    case (.sdkError, .sdkError):
      return false  // cannot compare underlying Error values reliably
    default:
      return false  // Cases with embedded Error are not equatable
    }
  }
}
