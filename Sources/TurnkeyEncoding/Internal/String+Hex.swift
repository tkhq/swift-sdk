import Foundation

extension String {

  /// Converts a hex-encoded string into a sequence of bytes.
  ///
  /// - Returns: A sequence of `UInt8` values parsed from the hex string.
  /// - Note: Non-hex characters or odd-length strings may result in incorrect output.
  public var hex: some Sequence<UInt8> {
    self[...].hex
  }

  /// Converts the hex string into `Data`.
  ///
  /// - Returns: A `Data` instance representing the bytes in the hex string.
  public var hexData: Data {
    Data(hex)
  }

  /// Returns the string if it is not empty after trimming whitespace and newlines.
  ///
  /// - Returns: A trimmed string, or `nil` if the result is empty.
  public var nonEmpty: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
