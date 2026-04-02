internal enum TurnkeyConstants {
  static let productionSignerPublicKey =
    "04cf288fe433cc4e1aa0ce1632feac4ea26bf2f5a09dcfe5a42c398e06898710330f0572882f4dbdf0f5304b8fc8703acd69adca9a4bbf7f5d00d20a5e364b2569"

  static let productionTlsFetcherSignPublicKey =
    "046b4f88421f76b6ba418afc2ea1d8ced671337d7db6b80478a60d8531bf8f17fa9a512f0fef96fc0c9b4cd9dff70b34992e520ce04c79d931f6ff6296b547d201"

  static let hpkeInfo = "turnkey_hpke".data(using: .utf8)!
}
