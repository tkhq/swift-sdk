import SwiftUI
import TurnkeyHttp
import TurnkeySwift
import TurnkeyEncoding

struct SignMessageView: View {
    let walletAddress: String

    @EnvironmentObject private var coordinator: NavigationCoordinator
    @EnvironmentObject private var sessions: SessionManager

    @State private var message = "I love Turnkey"
    @State private var signatureR: String?
    @State private var signatureS: String?
    @State private var signatureV: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Input field
            VStack(alignment: .leading, spacing: 8) {
                Text("Message to Sign")
                    .font(.system(size: 14))
                    .foregroundColor(.black)

                TextEditor(text: $message)
                    .font(.system(size: 14))
                    .frame(height: 100)
                    .padding(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                    .background(Color.white)
                    .cornerRadius(8)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }

            // Sign button
            if signatureR == nil {
                Button("Sign", action: handleSignPressed)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }

            // Signature display
            if let r = signatureR, let s = signatureS, let v = signatureV {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Signature (r, s, v)")
                        .font(.system(size: 14))
                        .foregroundColor(.black)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("r: \(r)")
                        Text("s: \(s)")
                        Text("v: \(v)")
                    }
                    .font(.system(size: 12))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                // Done button
                Button("Done", action: handleDonePressed)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(10)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Sign Message")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func handleSignPressed() {
        Task {
            do {
                let digest = Ethereum.keccak256Digest(of: message)
                let digestHex = digest.toHexString()

                let result = try await sessions.signRawPayload(
                    signWith: walletAddress,
                    payload: digestHex,
                    encoding: .PAYLOAD_ENCODING_HEXADECIMAL,
                    hashFunction: .HASH_FUNCTION_NO_OP
                )

                await MainActor.run {
                    signatureR = result.r
                    signatureS = result.s
                    signatureV = result.v
                }
            } catch {
                print("Failed to sign message:", error)
            }
        }
    }

    private func handleDonePressed() {
        coordinator.pop()
    }
}

#Preview {
    SignMessageView(walletAddress: "0x123")
        .environmentObject(NavigationCoordinator())
}
