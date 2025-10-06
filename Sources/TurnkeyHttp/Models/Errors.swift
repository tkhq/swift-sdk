import Foundation
import HTTPTypes

public enum TurnkeyRequestError: LocalizedError, Sendable, Equatable {

  case apiError(statusCode: Int?, payload: Data?)
  case sdkError(Error)
  case network(Error)
  case invalidResponse
  case clientNotConfigured(String)
  case unknown(Error)

  public var statusCode: Int? {
    if case let .apiError(code, _) = self { return code }
    return nil
  }

  public var payload: Data? {
    if case let .apiError(_, data) = self { return data }
    return nil
  }

  public var fullMessage: String {
    if case let .apiError(code, data?) = self {
      // try to pretty-print JSON
      if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let json = try? JSONSerialization.data(
          withJSONObject: obj,
          options: [.sortedKeys, .prettyPrinted]
        ),
        let str = String(data: json, encoding: .utf8)
      {
        return "Status \(code ?? -1):\n\(str)"
      }

      // fallback
      // try raw UTF-8 string
      if let str = String(data: data, encoding: .utf8) {
        return "Status \(code ?? -1):\n\(str)"
      }

      // fallback
      // show byte count
      return "Status \(code ?? -1): <\(data.count) bytes>"
    }

    // this should never happen
    return errorDescription ?? "Unknown error"
  }

  public var errorDescription: String? {
    switch self {
    case let .apiError(_, data?):
      return fullMessage
    case .apiError:
      return "Turnkey API returned an error response."
    case .sdkError(let e):
      return e.localizedDescription
    case .network(let e):
      return e.localizedDescription
    case .invalidResponse:
      return "Invalid response from server."
    case .clientNotConfigured(let client):
      return "The required client (\(client)) is not configured."
    case .unknown(let e):
      return e.localizedDescription
    }
  }

  public init(httpResponse: HTTPResponse, body: Data?) {
    let code = httpResponse.status.code
    if (400..<600).contains(code) {
      self = .apiError(statusCode: code, payload: body)
    } else {
      self = .unknown(NSError(domain: "TurnkeyError", code: code, userInfo: nil))
    }
  }

  public init(_ error: Error) {
    self = error as? TurnkeyRequestError ?? .unknown(error)
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case let (.apiError(c1, d1), .apiError(c2, d2)):
      return c1 == c2 && d1 == d2
    case (.invalidResponse, .invalidResponse):
      return true
    default:
      return false
    }
  }
}
