import SwiftUI
import TurnkeyHttp
import TurnkeySwift

struct ImportWalletView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @EnvironmentObject private var turnkey: TurnkeyContext
    @EnvironmentObject private var toast: ToastContext

    @State private var walletName = ""
    @State private var seedPhrase = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Wallet Name")
                        .font(.system(size: 14))
                        .foregroundColor(.black)

                    TextField("Enter wallet name", text: $walletName)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3))
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Seed Phrase")
                        .font(.system(size: 14))
                        .foregroundColor(.black)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $seedPhrase)
                            .font(.system(size: 14))
                            .padding(12)
                            .background(Color.clear)
                            .cornerRadius(8)
                            .disableAutocorrection(true)
                            .autocapitalization(.none)
                    }
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3))
                    )
                }
            }
            .padding(.horizontal)

            Button(action: handleImportWallet) {
                Text("Import Wallet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()
        }
        .navigationTitle("Import Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .padding()
    }

    private func handleImportWallet() {
        Task {
            do {
                try await turnkey.importWallet(
                    walletName: walletName,
                    mnemonic: seedPhrase,
                    accounts: Constants.Turnkey.defaultEthereumAccounts
                )
            } catch {
                toast.show(message: "Failed to import wallet.", type: .error)
            }
        }
        coordinator.pop()
    }
}
