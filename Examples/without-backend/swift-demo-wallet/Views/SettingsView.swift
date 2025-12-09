import SwiftUI
import TurnkeySwift

struct SettingsView: View {
    @EnvironmentObject private var turnkey: TurnkeyContext
    @EnvironmentObject private var toast: ToastContext

    @Environment(\.presentationMode) var presentationMode

    @State private var showUpdateEmail = false
    @State private var showUpdatePhone = false
    @State private var showOtpView = false
    @State private var otpId = ""
    @State private var otpContact = ""
    @State private var otpType: OtpType = .email
    @State private var updateType: UpdateType?

    enum UpdateType {
        case email
        case phone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)

                    HStack {
                        Text(turnkey.user?.userEmail ?? "Not set")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)

                        Spacer()

                        Button("Update") {
                            showUpdateEmail = true
                        }
                        .font(.system(size: 14))
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)

                    HStack {
                        Text(turnkey.user?.userPhoneNumber ?? "Not set")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)

                        Spacer()

                        Button("Update") {
                            showUpdatePhone = true
                        }
                        .font(.system(size: 14))
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .padding()
        .navigationDestination(isPresented: $showOtpView) {
            OtpView(
                otpId: otpId,
                contact: otpContact,
                otpType: otpType,
                onComplete: handleOtpComplete
            )
        }
        .sheet(isPresented: $showUpdateEmail) {
            UpdateEmailView(onUpdate: handleEmailUpdate)
        }
        .sheet(isPresented: $showUpdatePhone) {
            UpdatePhoneView(onUpdate: handlePhoneUpdate)
        }
    }

    private func handleEmailUpdate(newEmail: String) {
        Task {
            do {
                let result = try await turnkey.initOtp(contact: newEmail, otpType: .email)
                otpId = result.otpId
                otpContact = newEmail
                otpType = .email
                updateType = .email
                showUpdateEmail = false
                showOtpView = true
            } catch {
                toast.show(message: "Failed to send verification code", type: .error)
            }
        }
    }

    private func handlePhoneUpdate(newPhone: String) {
        Task {
            do {
                let result = try await turnkey.initOtp(contact: newPhone, otpType: .sms)
                otpId = result.otpId
                otpContact = newPhone
                otpType = .sms
                updateType = .phone
                showUpdatePhone = false
                showOtpView = true
            } catch {
                toast.show(message: "Failed to send verification code", type: .error)
            }
        }
    }

    private func handleOtpComplete(otpCode: String) async throws {
        guard let updateType = updateType else { return }

        let verifyResult = try await turnkey.verifyOtp(otpId: otpId, otpCode: otpCode)
        let verificationToken = verifyResult.verificationToken

        switch updateType {
        case .email:
            try await turnkey.updateUserEmail(email: otpContact, verificationToken: verificationToken)
            toast.show(message: "Email updated successfully", type: .success)
        case .phone:
            try await turnkey.updateUserPhoneNumber(phone: otpContact, verificationToken: verificationToken)
            toast.show(message: "Phone updated successfully", type: .success)
        }

        // we reset state
        self.updateType = nil
    }
}

struct UpdateEmailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    let onUpdate: (String) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Email")
                        .font(.system(size: 14))
                        .foregroundColor(.black)

                    EmailInputView(email: $email)
                }
                .padding(.horizontal)
                .padding(.top, 24)

                Button(action: {
                    onUpdate(email)
                }) {
                    Text("Send Verification Code")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isValidEmail(email) ? Color.blue : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(!isValidEmail(email))
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Update Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct UpdatePhoneView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toast: ToastContext
    @State private var phone = ""
    @State private var selectedCountry = "US"
    let onUpdate: (String) -> Void

    private var isValidPhoneNumber: Bool {
        !phone.isEmpty && isValidPhone(phone, region: selectedCountry)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Phone Number")
                        .font(.system(size: 14))
                        .foregroundColor(.black)

                    PhoneInputView(selectedCountry: $selectedCountry, phoneNumber: $phone)
                }
                .padding(.horizontal)
                .padding(.top, 24)

                Button(action: {
                    guard let formattedPhone = formatToE164(phone, region: selectedCountry) else {
                        toast.show(message: "Invalid phone number", type: .error)
                        return
                    }
                    onUpdate(formattedPhone)
                }) {
                    Text("Send Verification Code")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isValidPhoneNumber ? Color.blue : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(!isValidPhoneNumber)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Update Phone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
