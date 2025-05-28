import Foundation

public enum TurnkeyDecodingError: Error {
  case oddLengthString
  case invalidHexCharacter
}
