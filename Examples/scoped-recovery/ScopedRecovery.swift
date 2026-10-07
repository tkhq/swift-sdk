import AuthenticationServices
import Foundation
import TurnkeyHttp
import TurnkeyPasskeys
import TurnkeyStamper
import TurnkeySwift
import TurnkeyTypes

/// A reference implementation of the scoped MFA-recovery flow for a native iOS app.
///
/// This is deliberately a small, framework-agnostic state machine. A SwiftUI app can keep the
/// returned `MfaRequiredError` in view state, use its `mfaStatuses` to prompt for a second factor,
/// and then call `approve` and `resumeOtpLogin`.
public enum ScopedRecovery {
  public struct Configuration: Sendable {
    public let organizationId: String
    public let sessionProfileId: String
    public let apiUrl: String

    public init(
      organizationId: String,
      sessionProfileId: String,
      apiUrl: String = TurnkeyClient.baseURLString
    ) {
      self.organizationId = organizationId
      self.sessionProfileId = sessionProfileId
      self.apiUrl = apiUrl
    }
  }

  public enum LoginResult {
    case completed(session: String)
    case mfaRequired(MfaRequiredError)
  }

  public enum RecoveryError: Error {
    case activityDidNotComplete
    case activityFailed
    case missingOtpLoginSession
  }

  /// Starts a scoped OTP login. If MFA is required, the result carries the activity fingerprint
  /// and unsatisfied MFA methods instead of treating the held activity as a failed login.
  public static func beginOtpLogin(
    verificationToken: String,
    configuration: Configuration,
    expirationSeconds: String? = nil,
    invalidateExisting: Bool = false
  ) async throws -> LoginResult {
    let (message, publicKey) = try ClientSignature.forLogin(verificationToken: verificationToken)
    let signingStamper = try Stamper(apiPublicKey: publicKey)
    let attestedStamper = AttestedStamper(
      attestedIdentity: verificationToken,
      scheme: .p256VerificationToken,
      stamper: signingStamper
    )
    let client = TurnkeyClient(
      organizationId: configuration.organizationId,
      baseUrl: configuration.apiUrl,
      stamper: attestedStamper
    )
    let clientSignature = v1ClientSignature(
      message: message,
      publicKey: publicKey,
      scheme: .client_signature_scheme_api_p256,
      signature: try await signingStamper.sign(payload: message, format: .raw)
    )

    do {
      let response = try await client.otpLogin(
        TOtpLoginBody(
          clientSignature: clientSignature,
          expirationSeconds: expirationSeconds,
          invalidateExisting: invalidateExisting,
          publicKey: publicKey,
          sessionProfileId: configuration.sessionProfileId,
          verificationToken: verificationToken
        )
      )
      return .completed(session: response.session)
    } catch let error as MfaRequiredError {
      return .mfaRequired(error)
    }
  }

  /// Uses an independently verified second factor to approve the held recovery activity.
  ///
  /// The attested identity can be either an OTP verification token or OIDC token. Its local
  /// P-256 key must be the key bound to that identity when it was verified.
  public static func approve(
    _ requirement: MfaRequiredError,
    attestedIdentity: String,
    attestedPublicKey: String,
    scheme: AttestedStampScheme,
    configuration: Configuration
  ) async throws {
    let signingStamper = try Stamper(apiPublicKey: attestedPublicKey)
    let client = TurnkeyClient(
      organizationId: configuration.organizationId,
      baseUrl: configuration.apiUrl,
      stamper: AttestedStamper(
        attestedIdentity: attestedIdentity,
        scheme: scheme,
        stamper: signingStamper
      )
    )

    _ = try await client.approveActivity(
      TApproveActivityBody(fingerprint: requirement.activity.fingerprint)
    )
  }

  /// Waits for a previously held OTP login activity and returns its newly scoped session JWT.
  public static func resumeOtpLogin(
    activityId: String,
    attestedIdentity: String,
    attestedPublicKey: String,
    scheme: AttestedStampScheme,
    configuration: Configuration,
    maxAttempts: Int = 30,
    intervalNanoseconds: UInt64 = 1_000_000_000
  ) async throws -> String {
    let signingStamper = try Stamper(apiPublicKey: attestedPublicKey)
    let client = TurnkeyClient(
      organizationId: configuration.organizationId,
      baseUrl: configuration.apiUrl,
      stamper: AttestedStamper(
        attestedIdentity: attestedIdentity,
        scheme: scheme,
        stamper: signingStamper
      )
    )

    for attempt in 0..<maxAttempts {
      let activity = try await client.getActivity(TGetActivityBody(activityId: activityId)).activity
      switch activity.status {
      case .activity_status_completed:
        guard let session = activity.result.otpLoginResult?.session else {
          throw RecoveryError.missingOtpLoginSession
        }
        return session
      case .activity_status_failed, .activity_status_rejected:
        throw RecoveryError.activityFailed
      default:
        guard attempt < maxAttempts - 1 else { break }
        try await Task.sleep(nanoseconds: intervalNanoseconds)
      }
    }

    throw RecoveryError.activityDidNotComplete
  }

  /// Enrolls a replacement passkey while the scoped recovery session is active.
  @available(iOS 16.0, macOS 13.0, *)
  public static func enrollReplacementPasskey(
    sessionPublicKey: String,
    userId: String,
    passkeyName: String,
    rpId: String,
    presentationAnchor: ASPresentationAnchor,
    configuration: Configuration
  ) async throws -> TCreateAuthenticatorsResponse {
    let client = try TurnkeyClient(
      apiPublicKey: sessionPublicKey,
      organizationId: configuration.organizationId,
      baseUrl: configuration.apiUrl
    )
    let passkey = try await createPasskey(
      user: PasskeyUser(id: userId, name: passkeyName, displayName: passkeyName),
      rp: RelyingParty(id: rpId, name: ""),
      presentationAnchor: presentationAnchor
    )

    return try await client.createAuthenticators(
      TCreateAuthenticatorsBody(
        authenticators: [
          v1AuthenticatorParamsV2(
            attestation: passkey.attestation,
            authenticatorName: passkeyName,
            challenge: passkey.challenge
          )
        ],
        userId: userId
      )
    )
  }
}
