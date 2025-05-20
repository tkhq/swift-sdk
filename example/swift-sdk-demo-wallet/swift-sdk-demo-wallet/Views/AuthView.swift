import SwiftUI
import PhoneNumberKit

struct AuthView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var coordinator: NavigationCoordinator
    
    @State private var email = ""
    @State private var phone = ""
    
    // we default to the US
    @State private var selectedCountry = "US"
    
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Log in or sign up")
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 8)
                    
                    EmailInputView(email: $email)
                    
                    LightGrayButton(title: "Continue", action: handleContinueWithEmail, isDisabled: !isValidEmail(email))
                    
                    OrSeparator()
                    
                    PhoneInputView(
                        selectedCountry: $selectedCountry,
                        phoneNumber: $phone
                    )
                    
                    LightGrayButton(title: "Continue", action: handleContinueWithPhone, isDisabled: !isValidPhone(phone, region: selectedCountry))
                    
                    OrSeparator()
                    
                    Button("Log in with passkey", action: handleLoginWithPasskey)
                        .buttonStyle(BlackBorderButton())
                    
                    Button("Sign up with passkey", action: handleSignUpWithPasskey)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .background(Color.gray.opacity(0.05).ignoresSafeArea())
    }
    
    private func handleContinueWithEmail() {
        let otpId = "emailOtpId"
        let organizationId = "org123"
        coordinator.push(AuthRoute.otp(otpId: otpId, organizationId: organizationId, contact: email))
    }
    
    private func handleContinueWithPhone() {
        let otpId = "emailOtpId"
        let organizationId = "org123"
        coordinator.push(AuthRoute.otp(otpId: otpId, organizationId: organizationId, contact: phone))
    }
    
    private func handleLoginWithPasskey() {
        session.isAuthenticated = true
    }
    
    private func handleSignUpWithPasskey() {
        session.isAuthenticated = true
    }
}


private struct OrSeparator: View {
    var body: some View {
        HStack {
            Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3))
            Text("OR")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal, 4)
            Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3))
        }
    }
}

struct LightGrayButton: View {
    let title: String
    let action: () -> Void
    let isDisabled: Bool
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.15))
                .foregroundColor(.black)
                .cornerRadius(10)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}


private struct BlackBorderButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .foregroundColor(.black)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: 1)
            )
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

#Preview {
    AuthView()
        .environmentObject(SessionStore())
        .environmentObject(NavigationCoordinator())
}
