import SwiftUI
import TurnkeySwift
import TurnkeyEncoding

struct KeyManagerView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    struct ManagedKeyPair: Identifiable, Hashable {
        var id: String { publicKeyHex }
        let publicKeyHex: String
        let authDescription: String
    }
    
    @State private var keyPairs: [ManagedKeyPair] = []
    @State private var showCreateModal: Bool = false
    @State private var selectedCreateOption: PolicyOption = .none
    @State private var isSigning: Bool = false
    @State private var signingPublicKey: String? = nil
    @State private var messageToSign: String = ""
    @State private var signatureHex: String? = nil
    @State private var signError: String? = nil
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(keyPairs) { pair in
                            KeyPairCardView(
                                publicKeyHex: pair.publicKeyHex,
                                authDescription: pair.authDescription,
                                onSign: { beginSign(publicKeyHex: pair.publicKeyHex) },
                                onDelete: { deleteKey(publicKeyHex: pair.publicKeyHex) }
                            )
                            .padding()
                        }
                        Color.clear.frame(height: 44)
                    }
                }
                .onAppear {
                    reloadPairs()
                }
            }
            
            VStack {
                Spacer()
                Button(action: {
                    showCreateModal = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)
                }
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Enclave Manager")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { coordinator.pop() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateModal) {
            CreateKeySheet(
                selectedOption: $selectedCreateOption,
                onCancel: { showCreateModal = false },
                onCreate: {
                    let policy = optionToAuthPolicy(selectedCreateOption)
                    createKey(authPolicy: policy)
                    showCreateModal = false
                }
            )
            .presentationDetents([PresentationDetent.medium])
        }
        .sheet(isPresented: $isSigning, onDismiss: { resetSignState() }) {
            SignMessageSheet(
                publicKeyHex: signingPublicKey ?? "",
                message: $messageToSign,
                signatureHex: $signatureHex,
                errorText: $signError,
                onCancel: {
                    isSigning = false
                },
                onSign: {
                    performSign()
                }
            )
            .presentationDetents([.medium, .large])
        }
    }
    
    fileprivate enum PolicyOption: String, CaseIterable, Identifiable {
        case none
        case userPresence
        case biometryAny
        case biometryCurrentSet
        var id: String { rawValue }
    }
    
    private func reloadPairs() {
        do {
            let pairs = try EnclaveManager.listKeyPairs()
            // We cannot reliably inspect the original access control flags here.
            // Default to "None" for existing keys; newly created keys in this view set their description explicitly.
            let mapped = pairs.map { ManagedKeyPair(publicKeyHex: $0.publicKeyHex, authDescription: "None") }
            keyPairs = mapped
        } catch {
            // Silent fail in demo UI
        }
    }
    
    private func createKey(authPolicy: EnclaveManager.AuthPolicy) {
        do {
            let pair = try EnclaveManager.createKeyPair(authPolicy: authPolicy)
            let item = ManagedKeyPair(publicKeyHex: pair.publicKeyHex, authDescription: authPolicyDescription(authPolicy))
            keyPairs.insert(item, at: 0)
        } catch {
            // Silent fail in demo UI
        }
    }
    
    private func optionToAuthPolicy(_ option: PolicyOption) -> EnclaveManager.AuthPolicy {
        switch option {
        case .none: return .none
        case .userPresence: return .userPresence
        case .biometryAny: return .biometryAny
        case .biometryCurrentSet: return .biometryCurrentSet
        }
    }
    
    private func optionDescription(_ option: PolicyOption) -> String {
        switch option {
        case .none: return "None"
        case .userPresence: return "User Presence"
        case .biometryAny: return "Biometry Any"
        case .biometryCurrentSet: return "Biometry Current Set"
        }
    }
    
    private func deleteKey(publicKeyHex: String) {
        do {
            try EnclaveManager.deleteKeyPair(publicKeyHex: publicKeyHex)
            keyPairs.removeAll { $0.publicKeyHex == publicKeyHex }
        } catch {
            // Silent fail in demo UI
        }
    }
    
    private func beginSign(publicKeyHex: String) {
        signingPublicKey = publicKeyHex
        messageToSign = ""
        signatureHex = nil
        signError = nil
        isSigning = true
    }
    
    private func performSign() {
        guard let pk = signingPublicKey else { return }
        do {
            let manager = try EnclaveManager(publicKeyHex: pk)
            let data = Data(messageToSign.utf8)
            let sig = try manager.sign(message: data, algorithm: .ecdsaSignatureDigestX962SHA256)
            signatureHex = sig.toHexString()
            signError = nil
        } catch {
            signatureHex = nil
            signError = error.localizedDescription
        }
    }
    
    private func resetSignState() {
        signingPublicKey = nil
        messageToSign = ""
        signatureHex = nil
        signError = nil
    }
    
    private func authPolicyDescription(_ policy: EnclaveManager.AuthPolicy) -> String {
        switch policy {
        case .none: return "None"
        case .userPresence: return "User Presence"
        case .biometryAny: return "Biometry Any"
        case .biometryCurrentSet: return "Biometry Current Set"
        }
    }
}

private struct KeyPairCardView: View {
    let publicKeyHex: String
    let authDescription: String
    let onSign: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Public Key")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(publicKeyHex)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .lineLimit(2)
                .truncationMode(.middle)
            
            HStack {
                Text("Auth: \(authDescription)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack {
                Button(action: onSign) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Sign Message")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.red)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

private struct SignMessageSheet: View {
    let publicKeyHex: String
    @Binding var message: String
    @Binding var signatureHex: String?
    @Binding var errorText: String?
    let onCancel: () -> Void
    let onSign: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Signing Key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(publicKeyHex)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Message")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter message to sign", text: $message)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                if let error = errorText {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                if let sig = signatureHex {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Signature (DER, hex)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ScrollView {
                            Text(sig)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 160)
                    }
                }
                
                Spacer()
                
                HStack {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                    }
                    
                    Button(action: onSign) {
                        Text("Sign")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Sign Message")
        }
    }
}

private struct CreateKeySheet: View {
    @Binding var selectedOption: KeyManagerView.PolicyOption
    let onCancel: () -> Void
    let onCreate: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auth Mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("Auth Mode", selection: $selectedOption) {
                        ForEach(KeyManagerView.PolicyOption.allCases) { option in
                            Text(label(for: option)).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Spacer()
                
                HStack {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                    }
                    
                    Button(action: onCreate) {
                        Text("Create")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Create Key")
        }
    }
    
    private func label(for option: KeyManagerView.PolicyOption) -> String {
        switch option {
        case .none: return "None"
        case .userPresence: return "User Presence"
        case .biometryAny: return "Biometry Any"
        case .biometryCurrentSet: return "Biometry Current Set"
        }
    }
}


