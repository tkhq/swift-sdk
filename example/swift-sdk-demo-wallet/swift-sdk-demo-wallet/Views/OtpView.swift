import SwiftUI

import SwiftUI

struct OtpView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var coordinator: NavigationCoordinator
    
    @Environment(\.dismiss) private var dismiss

    @State private var otpDigits: [String] = Array(repeating: "", count: 6)

    var otpId: String
    var organizationId: String
    var contact: String

    private var otpCode: String {
        otpDigits.joined()
    }

    private var isEmail: Bool {
        contact.contains("@")
    }

    var body: some View {
        VStack {
            Spacer()

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
                Button(action: handleCancel) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                }

                Button(action: handleContinue) {
                    Text("Continue")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(otpCode.count == 6 ? Color.blue : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(otpCode.count != 6)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .ignoresSafeArea(.keyboard)
        .navigationTitle("Verify Code")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func handleCancel() {
        dismiss()
    }

    private func handleContinue() {
        session.isAuthenticated = true 
    }
}



struct OTPSixDigitInput: View {
    @Binding var digits: [String]
    @FocusState private var focusedIndex: Int?

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { index in
                OTPDigitBox(text: $digits[index], index: index, focusedIndex: _focusedIndex)
                    .onChange(of: digits[index]) {
                        digits[index] = digits[index].last.map { String($0).filter(\.isNumber) } ?? ""

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
            .keyboardType(.numberPad)
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


#Preview {
    OtpView(otpId: "", organizationId: "", contact: "email@example.com")
        .environmentObject(SessionStore())
        .environmentObject(NavigationCoordinator())
}
