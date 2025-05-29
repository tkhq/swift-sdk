# TurnkeyEncoding

This package contains encoding and decoding utilities used internally across other Turnkey Swift SDK modules. It includes helpers for working with hex strings, base64url encoding, and converting between data formats.

While you are free to use the exported functions in your own apps, please note that the interface is considered internal and may change significantly in future versions.

---

## Features

* Hex string to `Data` conversion and vice versa
* Base64URL encoding/decoding support
* Utilities for string sanitization (e.g. `.nonEmpty`)
* Common error types for decoding failures

---

## Requirements

* iOS 13+ / macOS 10.15+
* Swift 5.7+

---
