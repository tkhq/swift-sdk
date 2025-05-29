
# TurnkeyCrypto

This package provides a collection of cryptographic utilities used across our applications, particularly for working with keys, encryption, and decryption using Apple's CryptoKit and HPKE.

It includes support for:

* Generating and serializing P-256 key pairs
* Decrypting credential and export bundles (HPKE)
* Encrypting mnemonics into enclave-compatible bundles
* Verifying enclave signatures using ECDSA

These utilities are designed to work alongside Turnkey’s enclave-based infrastructure for secure key management and wallet recovery.

---

## Requirements

* iOS 17+ / macOS 14+
* CryptoKit (built-in)
* TurnkeyEncoding (internal dependency)

---

