// Shared
public enum AuthAction: String, Codable {
    case login
    case signup
}

public struct BaseAuthResult: Codable, Sendable {
    public let session: String
}

// Passkey
public struct PasskeyAuthResult: Codable {
    public let session: String
    public let credentialId: String
}

// OTP
public struct InitOtpResult: Codable, Sendable {
    public let otpId: String
}

public struct VerifyOtpResult: Codable, Sendable {
    public let credentialBundle: String
}

public struct CompleteOtpResult: Codable {
    public let session: String
    public let verificationToken: String
    public let action: AuthAction
}

// OAuth
public struct CompleteOAuthResult: Codable {
    public let session: String
    public let action: AuthAction
}
