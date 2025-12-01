import Foundation
import SwiftUI
import TurnkeySwift

struct OtpInitRequest: Codable { let otpType: String; let contact: String; let userIdentifier: String }
struct OtpInitResponse: Codable { let otpId: String }
struct OtpVerifyRequest: Codable {
    let otpId: String
    let otpCode: String
    let otpType: String
    let contact: String
    let publicKey: String
    let expirationSeconds: String
}
struct OtpVerifyResponse: Codable { let token: String? }

func postJSON<T: Encodable, U: Decodable>(_ url: URL, body: T) async throws -> U {
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try JSONEncoder().encode(body)
    let (data, _) = try await URLSession.shared.data(for: req)
    return try JSONDecoder().decode(U.self, from: data)
}

struct OtpLoginView: View {
    @EnvironmentObject private var turnkey: TurnkeyContext
    @Environment(\.dismiss) private var dismiss
    
    let contact: String
    @State private var otpDigits: [String] = Array(repeating: "", count: 6)
    @State private var otpId: String?
    @State private var isSending: Bool = false
    @State private var isVerifying: Bool = false
    @State private var errorMessage: String?
    
    let baseURL: String
    
    private var isEmail: Bool { contact.contains("@") }
    private var otpCode: String { otpDigits.joined() }
    
    var body: some View {
        VStack {
            Spacer()
            
            if otpId == nil {
                // Step 1: Collect contact and send OTP
                VStack(spacing: 16) {
                    Image(systemName: isEmail ? "envelope.fill" : "ellipsis.bubble.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.black)
                    
                    Text("We will send a 6-digit code to")
                        .font(.body)
                        .multilineTextAlignment(.center)
                    
                    Text(contact)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                
                Spacer()
                
                Button(action: handleSendCode) {
                    Text(isSending ? "Sending..." : "Send Code")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(contact.isEmpty || isSending ? Color.gray : Color.blue)
                        .cornerRadius(10)
                }
                .disabled(contact.isEmpty || isSending)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            } else {
                // Step 2: Enter OTP, match OtpView styling
                VStack(spacing: 16) {
                    Image(systemName: isEmail ? "envelope.fill" : "ellipsis.bubble.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.black)
                    
                    Text("Enter the 6-digit code we \(isEmail ? "emailed" : "texted") to")
                        .font(.body)
                        .multilineTextAlignment(.center)
                    
                    Text(contact)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    OTPSixDigitInput(digits: $otpDigits)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                    }
                    
                    Button(action: handleVerifyAndLogin) {
                        Text(isVerifying ? "Continuing..." : "Continue")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(otpCode.count == 6 && !isVerifying ? Color.blue : Color.gray)
                            .cornerRadius(10)
                    }
                    .disabled(otpCode.count != 6 || isVerifying)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea(.keyboard)
        .navigationTitle("Login with OTP")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }
    
    private func handleSendCode() {
        Task {
            isSending = true
            defer { isSending = false }
            do {
                let initResp: OtpInitResponse = try await postJSON(
                    URL(string: "\(baseURL)/auth/sendOtp")!,
                    body: OtpInitRequest(
                        otpType: isEmail ? "OTP_TYPE_EMAIL" : "OTP_TYPE_SMS",
                        contact: contact,
                        userIdentifier: contact
                    )
                )
                otpId = initResp.otpId
                print("[OTP] Sent code to \(contact). otpId=\(initResp.otpId)")
            } catch {
                errorMessage = "Failed to send code: \(error.localizedDescription)"
                print("[OTP] Failed to send code: \(error)")
            }
        }
    }
    
    private func handleVerifyAndLogin() {
        Task {
            guard let otpId else { return }
            isVerifying = true
            defer { isVerifying = false }
            do {
                // 1) Generate public key for the session
                let publicKey = try turnkey.createKeyPair()
                let pkPreview = publicKey.count > 12 ? String(publicKey.prefix(12)) + "..." : publicKey
                print("[OTP] Generated public key: \(pkPreview)")
                
                // 2) Verify OTP on backend which also logs in and returns token
                let verifyResp: OtpVerifyResponse = try await postJSON(
                    URL(string: "\(baseURL)/auth/verifyOtp")!,
                    body: OtpVerifyRequest(
                        otpId: otpId,
                        otpCode: otpCode,
                        otpType: isEmail ? "OTP_TYPE_EMAIL" : "OTP_TYPE_SMS",
                        contact: contact,
                        publicKey: publicKey,
                        expirationSeconds: "1800"
                    )
                )
                
                guard let token = verifyResp.token, !token.isEmpty else {
                    throw NSError(domain: "OtpLogin", code: 0, userInfo: [NSLocalizedDescriptionKey: "Server did not return a session token"])
                }
                let tokenPreview = token.count > 16 ? String(token.prefix(8)) + "..." + String(token.suffix(8)) : token
                print("[OTP] Received session token (preview): \(tokenPreview)")
                
                // 3) Store session locally
                try await turnkey.storeSession(jwt: token)
                print("[OTP] Stored session successfully.")
                
                // 3b) Notify sign-in completion (routes to home like passkey flow)
                NotificationCenter.default.post(name: .UserSignedIn, object: nil)
                
                // 4) Dismiss view
                dismiss()
            } catch {
                errorMessage = "OTP verification failed: \(error.localizedDescription)"
                print("[OTP] Verification/login failed: \(error)")
            }
        }
    }
}

// MARK: - Reusable OTP UI components (matching OtpView)

struct OTPSixDigitInput: View {
    @Binding var digits: [String]
    @FocusState private var focusedIndex: Int?
    
    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { index in
                OTPDigitBox(text: $digits[index], index: index, focusedIndex: _focusedIndex)
                    .onChange(of: digits[index]) {
                        digits[index] = digits[index]
                            .last
                            .flatMap { c in
                                let s = String(c)
                                return s.rangeOfCharacter(from: .alphanumerics) != nil ? s : nil
                            } ?? ""
                        
                        // move to next field if filled
                        if !digits[index].isEmpty && index < 5 {
                            focusedIndex = index + 1
                        }
                        // backspace to previous if deleted
                        if digits[index].isEmpty && index > 0 {
                            focusedIndex = index - 1
                        }
                    }
            }
        }
        .onAppear {
            focusedIndex = 0
        }
        .padding(.vertical, 20)
    }
}

struct OTPDigitBox: View {
    @Binding var text: String
    let index: Int
    @FocusState var focusedIndex: Int?
    
    var body: some View {
        TextField("", text: $text)
            .keyboardType(.asciiCapable)
            .textInputAutocapitalization(.characters)
            .disableAutocorrection(true)
            .textContentType(.oneTimeCode)
            .multilineTextAlignment(.center)
            .font(.title)
            .frame(width: 52, height: 64)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
            )
            .focused($focusedIndex, equals: index)
    }
}
