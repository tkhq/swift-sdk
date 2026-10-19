# Scoped MFA recovery

This reference example shows the recommended native iOS recovery path for a lost passkey. It keeps the same Turnkey user, sub-organization, and wallets without using the deprecated email-recovery activities.

Before trying the sample, create the recovery session profile and the required MFA policies in the dashboard or parent organization. The recovery profile must permit authenticator creation but not signing.

## Flow

1. Use the normal OTP or OAuth flow to verify the first factor and obtain its verification token or OIDC token.
2. Call `ScopedRecovery.beginOtpLogin`. Supply the recovery `sessionProfileId`.
3. If the result is `mfaRequired`, present the required second-factor flow from `mfaStatuses`.
4. Call `ScopedRecovery.approve` using an `AttestedStamper` identity for that second factor. For an OTP factor, bind its verification to a separate local key and retain that public key.
5. Call `ScopedRecovery.resumeOtpLogin` with the original first-factor token and public key, then store the returned JWT with `TurnkeyContext.storeSession`.
6. Call `ScopedRecovery.enrollReplacementPasskey` with the active `Session`.
7. Log in with the replacement passkey using the same sub-organization ID and no recovery `sessionProfileId`. Confirm the user ID and wallet IDs match the pre-recovery account.

The replacement passkey can subsequently log in to the same sub-organization and wallets normally. The temporary recovery session cannot sign because its permissions are defined by the configured session profile.

## Using from SwiftUI

`ScopedRecovery` is framework-agnostic. Keep its `MfaRequiredError` in view state: `activity.fingerprint` identifies the held login, while `mfaStatuses` describes the remaining requirements. The example intentionally leaves the UI and provider-specific OTP/OIDC collection to the host application.

Build the sample module with:

```sh
swift build --target ScopedRecoveryExample
```

`mfaStatuses` is best-effort: if the lookup fails or its stamp is cancelled, the error still carries the held activity and fingerprint. An empty list does not indicate that MFA is satisfied. Retry `getMfaStatus` before choosing a second-factor prompt if the requirements are unavailable.

## Environment-backed acceptance check

Use an existing test user with a passkey, two recovery factors, and at least one wallet. Record the user, sub-organization, and wallet IDs. Configure an MFA policy that holds a login to the recovery profile until the second factor approves it, and a profile scope that permits `CREATE_AUTHENTICATORS_V2` but excludes signing.

Run the flow above without the original passkey. Verify that the first login pauses, approval completes the original activity, and the stored session retains its profile ID and scope. Enroll the replacement passkey, then attempt a signing request with the recovery session and verify that the server rejects it. Finally, log in with the replacement passkey and confirm the recorded user, sub-organization, and wallets are unchanged.

This check requires a configured Turnkey test organization and interactive passkey enrollment on an Apple device. The package tests cover request encoding, MFA hold handling, and session decoding/storage without contacting Turnkey.
