# Scoped MFA recovery

This reference example shows the recommended native iOS recovery path for a lost passkey. It keeps the same Turnkey user, sub-organization, and wallets without using the deprecated email-recovery activities.

Before trying the sample, create the recovery session profile and the required MFA policies in the dashboard or parent organization. The recovery profile must permit authenticator creation but not signing.

## Flow

1. Use the normal OTP or OAuth flow to verify the first factor and obtain its verification token or OIDC token.
2. Call `ScopedRecovery.beginOtpLogin`. Supply the recovery `sessionProfileId`.
3. If the result is `mfaRequired`, present the required second-factor flow from `mfaStatuses`.
4. Call `ScopedRecovery.approve` using an `AttestedStamper` identity for that second factor.
5. Call `ScopedRecovery.resumeOtpLogin`, then store the returned JWT with `TurnkeyContext.storeSession`.
6. Call `ScopedRecovery.enrollReplacementPasskey` while that scoped session is active.

The replacement passkey can subsequently log in to the same sub-organization and wallets normally. The temporary recovery session cannot sign because its permissions are defined by the configured session profile.

## Using from SwiftUI

`ScopedRecovery` is framework-agnostic. Keep its `MfaRequiredError` in view state: `activity.fingerprint` identifies the held login, while `mfaStatuses` describes the remaining requirements. The example intentionally leaves the UI and provider-specific OTP/OIDC collection to the host application.

Build the sample module with:

```sh
swift build --target ScopedRecoveryExample
```
