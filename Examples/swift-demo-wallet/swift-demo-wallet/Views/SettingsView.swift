import SwiftUI
import TurnkeySwift

struct SettingsView: View {
    @EnvironmentObject private var turnkey: TurnkeyContext
    @EnvironmentObject private var toast: ToastContext

    @Environment(\.presentationMode) var presentationMode
    
    @State private var email = ""
    @State private var phone = ""
    @State private var selectedCountry = "US"
    @State private var didInitialize = false
    
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
        .onAppear {
            if !didInitialize {
                email = turnkey.user?.email ?? ""
                
                if let fullNumber = turnkey.user?.phoneNumber,
                   let parsed = parsePhone(fullNumber) {
                    phone = parsed.nationalNumber
                    selectedCountry = parsed.regionCode
                } else {
                    phone = ""
                    selectedCountry = "US"
                }
                
                didInitialize = true
            }
        }
        
    }
    
    private func handleUpdatePressed() {
        Task {
            do {
                // combines the country code and number
                let formattedPhone = formatToE164(phone, region: selectedCountry)
                
                try await turnkey.updateUser(email: email, phone: formattedPhone)
            } catch {
                toast.show(message: "Failed to update user", type: .error)
            }
        }
    }
    
}
