extension Substring {

  /// Converts the substring, assumed to be hex-encoded, into a sequence of bytes.
  ///
  /// - Returns: A sequence of `UInt8` values parsed from the hex representation.
  /// - Note: Parsing stops if fewer than 2 characters remain or if a pair cannot be parsed as hex.
  public var hex: some Sequence<UInt8> {
    sequence(
      state: self,
      next: { remainder in
        guard remainder.count >= 2 else { return nil }
        let nextTwo = remainder.prefix(2)
        remainder.removeFirst(2)
        return UInt8(nextTwo, radix: 16)
      }
    )
  }
}
