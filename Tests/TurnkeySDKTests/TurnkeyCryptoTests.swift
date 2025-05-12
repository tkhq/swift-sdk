import CryptoKit
import XCTest

@testable import Shared

final class TurnkeyCryptoTests: XCTestCase {

  private let mockSenderPrivateKey =
    "67ee05fc3bdf4161bc70701c221d8d77180294cefcfcea64ba83c4d4c732fcb9"

  private let mockPrivateKeyHex =
    "20fa65df11f24833790ae283fc9a0c215eecbbc589549767977994dc69d05a56"

  private let mockCredentialBundle =
    "w99a5xV6A75TfoAUkZn869fVyDYvgVsKrawMALZXmrauZd8hEv66EkPU1Z42CUaHESQjcA5bqd8dynTGBMLWB9ewtXWPEVbZvocB4Tw2K1vQVp7uwjf"

  func testDecryptCredentialBundle() throws {
    let receiverPriv = try P256.KeyAgreement.PrivateKey(
      rawRepresentation: Data(hexString: mockPrivateKeyHex)!)

    let (signingPriv, signingPub) = try TurnkeyCrypto.decryptCredentialBundle(
      encryptedBundle: mockCredentialBundle,
      ephemeralPrivateKey: receiverPriv)

    XCTAssertEqual(
      signingPriv.rawRepresentation.count, 32,
      "Private scalar should be 32 bytes")

    XCTAssertEqual(
      signingPriv.rawRepresentation,
      Data(hexString: mockSenderPrivateKey),
      "Decrypted private key should equal mockSenderPrivateKey"
    )

    XCTAssertEqual(
      signingPub.x963Representation.count, 65,
      "Uncompressed public key should be 65 bytes")

    XCTAssertEqual(
      signingPriv.publicKey.x963Representation,
      signingPub.x963Representation,
      "Returned publicKey must equal privateKey.publicKey")
  }

  func testDecryptExportBundleMnemonic() throws {

    let exportBundle = """
      {
        "version": "v1.0.0",
        "data": "7b22656e6361707065645075626c6963223a2230343434313065633837653566653266666461313561313866613337376132316133633431633334373666383631333362343238306164373631303266343064356462326463353362343730303763636139336166666330613535316464353134333937643039373931636664393233306663613330343862313731663364363738222c2263697068657274657874223a22656662303538626633666634626534653232323330326266326636303738363062343237346232623031616339343536643362613638646135613235363236303030613839383262313465306261663061306465323966353434353461333739613362653664633364386339343938376131353638633764393566396663346239316265663232316165356562383432333361323833323131346431373962646664636631643066376164656231353766343131613439383430222c226f7267616e697a6174696f6e4964223a2266396133316336342d643630342d343265342d396265662d613737333039366166616437227d",
        "dataSignature": "304502203a7dc258590a637e76f6be6ed1a2080eed5614175060b9073f5e36592bdaf610022100ab9955b603df6cf45408067f652da48551652451b91967bf37dd094d13a7bdd4",
        "enclaveQuorumPublic": "04cf288fe433cc4e1aa0ce1632feac4ea26bf2f5a09dcfe5a42c398e06898710330f0572882f4dbdf0f5304b8fc8703acd69adca9a4bbf7f5d00d20a5e364b2569"
      }
      """.trimmingCharacters(in: .whitespacesAndNewlines)

    let embeddedKeyHex =
      "ffc6090f14bcf260e5dfe63f45412e60a477bb905956d7cc90195b71c2a544b3"

    let organizationId = "f9a31c64-d604-42e4-9bef-a773096afad7"
    let expectedMnemonic =
      "leaf lady until indicate praise final route toast cake minimum insect unknown"

    let embeddedPriv = try P256.KeyAgreement.PrivateKey(
      rawRepresentation: Data(hexString: embeddedKeyHex)!)

    let result = try TurnkeyCrypto.decryptExportBundle(
      exportBundle: exportBundle,
      organizationId: organizationId,
      embeddedKey: embeddedPriv,
      keyFormat: .other,
      returnMnemonic: true
    )

    XCTAssertEqual(result, expectedMnemonic)
  }

  func testEncryptWalletToBundle() throws {

    let mnemonic =
      "leaf lady until indicate praise final route toast cake minimum insect unknown"

    let importBundle = """
      {
        "version":"v1.0.0",
        "data":"7b227461726765745075626c6963223a2230343937363965366266636162333235303534356666633537353361396138393061663431653833366432613933333633353461303165623737346135616265616563393465656430663734396665303366393966646566663839643033386630643534366538636539323164383732373562376437396161383730656133393061222c226f7267616e697a6174696f6e4964223a2266396133316336342d643630342d343265342d396265662d613737333039366166616437222c22757365724964223a2237643461383835642d343636382d343063342d386633352d333333303165313165376435227d",
        "dataSignature":"3045022100fefc56c6bf4142ff54ce085b8103e79c7ac571dad16a145e9c99ec6d081b97ff0220203bd0d0f6048cd139aa3eb79ccace5425c2f1347401b2c18c66b728f540f17e",
        "enclaveQuorumPublic":"04cf288fe433cc4e1aa0ce1632feac4ea26bf2f5a09dcfe5a42c398e06898710330f0572882f4dbdf0f5304b8fc8703acd69adca9a4bbf7f5d00d20a5e364b2569"
      }
      """

    let userId = "7d4a885d-4668-40c4-8f35-33301e11e7d5"
    let organizationId = "f9a31c64-d604-42e4-9bef-a773096afad7"

    let outputJSON = try TurnkeyCrypto.encryptWalletToBundle(
      mnemonic: mnemonic,
      importBundle: importBundle,
      userId: userId,
      organizationId: organizationId)

    struct HpkeBundle: Decodable {
      let encappedPublic: String
      let ciphertext: String
    }
    let bundle = try JSONDecoder().decode(
      HpkeBundle.self, from: Data(outputJSON.utf8))

    XCTAssertEqual(
      bundle.encappedPublic.count, 130,
      "encappedPublic should be 65‑byte hex")
    XCTAssertNotNil(
      Data(hexString: bundle.encappedPublic),
      "encappedPublic must decode from hex")

    XCTAssertFalse(bundle.ciphertext.isEmpty, "ciphertext should not be empty")
    XCTAssertEqual(
      bundle.ciphertext.count.isMultiple(of: 2), true,
      "ciphertext hex length must be even")
    XCTAssertNotNil(
      Data(hexString: bundle.ciphertext),
      "ciphertext must decode from hex")
  }

}
