import Foundation

public enum TurnkeyDecodingError: Error {
  case invalidHexCharacter
  case oddLengthString
}

extension TurnkeyDecodingError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .invalidHexCharacter:
      return "The input contains characters that are not valid hexadecimal digits."
    case .oddLengthString:
      return "Hex string must have an even number of characters."
    }
  }
}
