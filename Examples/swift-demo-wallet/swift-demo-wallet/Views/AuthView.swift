import SwiftUI
import AuthenticationServices
import PhoneNumberKit
import TurnkeySwift
import TurnkeyHttp

struct AuthView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @EnvironmentObject private var turnkey: TurnkeyContext
    @EnvironmentObject private var auth: AuthContext
    @EnvironmentObject private var toast: ToastContext
    
    @State private var email = ""
    @State private var phone = ""
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
                    
                    GoogleButton(action: handleLoginWithGoogle)
                    
                    OrSeparator()
                    
                    EmailInputView(email: $email)
                    
                    LightGrayButton(
                        title: "Continue",
                        action: handleContinueWithEmail,
                        isDisabled: !isValidEmail(email)
                    )
                    
                    OrSeparator()
                    
                    PhoneInputView(
                        selectedCountry: $selectedCountry,
                        phoneNumber: $phone
                    )
                    
                    LightGrayButton(
                        title: "Continue",
                        action: handleContinueWithPhone,
                        isDisabled: !isValidPhone(phone, region: selectedCountry)
                    )
                    
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
        .onChange(of: auth.error) {
            if let error = auth.error {
                toast.show(message: error, type: .error)
                auth.error = nil
            }
        }
    }
    
    private func handleLoginWithGoogle() {
        Task {
            guard let anchor = defaultAnchor() else {
                toast.show(message: "No window available", type: .error)
                return
            }
            
            do {
                try await auth.loginWithGoogle(anchor: anchor)
            } catch {
                auth.error = "Failed to log in with Google"
            }
        }
    }
    
    private func handleContinueWithEmail() {
        Task {
            do {
                let otpId = try await turnkey.initOtp(contact: email, otpType: OtpType.email)
                coordinator.push(AuthRoute.otp(otpId: otpId, contact: email))
            } catch {
                auth.error = "Failed to send OTP"
            }
        }
    }
    
    private func handleContinueWithPhone() {
        Task {
            do {
                let otpId = try await turnkey.initOtp(contact: phone, otpType: OtpType.sms)
                coordinator.push(AuthRoute.otp(otpId: otpId, contact: email))
            } catch {
                auth.error = "Failed to send OTP"
            }
        }
    }
    
    private func handleLoginWithPasskey() {
        Task {
            guard let anchor = defaultAnchor() else {
                toast.show(message: "No window available", type: .error)
                return
            }
            
            do {
                try await auth.loginWithPasskey(anchor: anchor)
            } catch {
                auth.error = "Failed to log in with passkey"
            }
        }
    }
    
    private func handleSignUpWithPasskey() {
        Task {
            guard let anchor = defaultAnchor() else {
                toast.show(message: "No window available", type: .error)
                return
            }
            
            do {
                try await auth.signUpWithPasskey(anchor: anchor)
            } catch {
                auth.error = "Failed to sign up with passkey"
            }
        }
    }
    
    private func defaultAnchor() -> ASPresentationAnchor? {
        UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows
            .first(where: { $0.isKeyWindow })
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
    
    private struct LightGrayButton: View {
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
    
    private struct GoogleButton: View {
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                ZStack {
                    HStack {
                        Image("google-icon")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .padding(.leading, 12)
                        
                        Spacer()
                    }
                    
                    Text("Continue with Google")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(10)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
}
