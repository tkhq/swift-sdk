import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode

    @State private var email = ""
    @State private var phone = ""
    @State private var selectedCountry = "US"

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 20) {

                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.system(size: 14))
                        .foregroundColor(.black)

                    EmailInputView(email: $email)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone")
                        .font(.system(size: 14))
                        .foregroundColor(.black)

                    PhoneInputView(selectedCountry: $selectedCountry, phoneNumber: $phone)
                }
            }
            .padding(.horizontal)

            Button(action: handleUpdatePressed) {
                Text("Update")
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
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .padding()
    }

    private func handleUpdatePressed() {
        // add logic to update email and phone here
        
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    SettingsView()
        .environmentObject(SessionStore())
        .environmentObject(NavigationCoordinator())
}
