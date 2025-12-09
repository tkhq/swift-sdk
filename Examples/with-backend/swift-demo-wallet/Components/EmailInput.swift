import SwiftUI

struct EmailInputView: View {
    @Binding var email: String

    var body: some View {
        TextField("Enter your email", text: $email)
            .padding()
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.3))
            )
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
}
