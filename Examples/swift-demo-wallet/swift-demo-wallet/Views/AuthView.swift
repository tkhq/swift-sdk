import SwiftUI
import AuthenticationServices
import PhoneNumberKit
import TurnkeySwift
import TurnkeyHttp

struct AuthView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @EnvironmentObject private var turnkey: TurnkeyContext
    @EnvironmentObject private var toast: ToastContext
    
    @State private var email = ""
    @State private var phone = ""
    @State private var selectedCountry = "US"
    @State private var error: String? = nil
    
    var body: some View {
        ZStack {
            VStack {
                Spacer()
                
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Text("Log in or sign up")
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 8)
                        
                        HStack(spacing: 12) {
                            SocialIconButton(image: Image(systemName: "applelogo"), action: handleLoginWithApple)
                            SocialIconButton(image: Image("google-icon"), action: handleLoginWithGoogle)
                            SocialIconButton(image: Image("x-icon"), action: handleLoginWithX)
                            SocialIconButton(image: Image("discord-icon"), action: handleLoginWithDiscord)
                        }
                        .frame(height: 48)

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
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { coordinator.push(AuthRoute.keyManager) }) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)
                    }
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color.gray.opacity(0.05).ignoresSafeArea())
        .onChange(of: error) {
            if let message = error {
                toast.show(message: message, type: .error)
                error = nil
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
                try await turnkey.handleGoogleOAuth(anchor: anchor)
            } catch {
                let message = formatError(error, fallback: "Failed to log in with Google")
                print("[AuthView] Google login error: \(message)")
                self.error = message
            }
        }
    }

    private func handleLoginWithApple() {
        Task {
            guard let anchor = defaultAnchor() else {
                toast.show(message: "No window available", type: .error)
                return
            }

            do {
                try await turnkey.handleAppleOAuth(anchor: anchor)
            } catch {
                let message = formatError(error, fallback: "Failed to log in with Apple")
                print("[AuthView] Apple login error: \(message)")
                self.error = message
            }
        }
    }

    private func handleLoginWithX() {
        Task {
            guard let anchor = defaultAnchor() else {
                toast.show(message: "No window available", type: .error)
                return
            }

            do {
                try await turnkey.handleXOauth(anchor: anchor)
            } catch {
                let message = formatError(error, fallback: "Failed to log in with X")
                print("[AuthView] X login error: \(message)")
                self.error = message
            }
        }
    }

    private func handleLoginWithDiscord() {
        Task {
            guard let anchor = defaultAnchor() else {
                toast.show(message: "No window available", type: .error)
                return
            }

            do {
                try await turnkey.handleDiscordOAuth(anchor: anchor)
            } catch {
                let message = formatError(error, fallback: "Failed to log in with Discord")
                print("[AuthView] Discord login error: \(message)")
                self.error = message
            }
        }
    }
    
    private func handleContinueWithEmail() {
        Task {
            do {
                let resp = try await turnkey.initOtp(contact: email, otpType: OtpType.email)
                coordinator.push(AuthRoute.otp(otpId: resp.otpId, contact: email, otpType: .email))
            } catch {
                let message = formatError(error, fallback: "Failed to send OTP")
                print("[AuthView] Email OTP error: \(message)")
                self.error = message
            }
        }
    }
    
    private func handleContinueWithPhone() {
        Task {
            do {
                guard let formattedPhone = formatToE164(phone, region: selectedCountry) else {
                    self.error = "Invalid phone number"
                    return
                }
                let resp = try await turnkey.initOtp(contact: formattedPhone, otpType: OtpType.sms)
                coordinator.push(AuthRoute.otp(otpId: resp.otpId, contact: formattedPhone, otpType: .sms))
            } catch {
                let message = formatError(error, fallback: "Failed to send OTP")
                print("[AuthView] SMS OTP error: \(message)")
                self.error = message
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
                try await turnkey.loginWithPasskey(anchor: anchor)
            } catch {
                let message = formatError(error, fallback: "Failed to log in with passkey")
                print("[AuthView] Passkey login error: \(message)")
                self.error = message
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
                try await turnkey.signUpWithPasskey(anchor: anchor)
            } catch {
                let message = formatError(error, fallback: "Failed to sign up with passkey")
                print("[AuthView] Passkey signup error: \(message)")
                self.error = message
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

    private func formatError(_ error: Error, fallback: String) -> String {
        if let turnkeyError = error.turnkeyRequestError {
            return "\(fallback): \(turnkeyError.fullMessage)"
        }
        if let localized = (error as? LocalizedError)?.errorDescription {
            return "\(fallback): \(localized)"
        }
        return "\(fallback): \(String(describing: error))"
    }
    
    private struct OrSeparator: View {
        var label: String = "OR"
        var body: some View {
            HStack {
                Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3))
                Text(label)
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
    
    private struct SocialIconButton: View {
        let image: Image
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                ZStack {
                    Color.white
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(10)
        }
    }
}
