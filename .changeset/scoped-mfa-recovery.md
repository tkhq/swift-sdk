---
bump: major
---

### MFA recovery and scoped sessions

- Add `AttestedStamper` for OTP verification tokens and OIDC tokens bound to a local P-256 key.
- Stop activity polling at `AUTHENTICATORS_NEEDED` and throw `MfaRequiredError` with the held activity, fingerprint, and best-effort MFA requirements. Failed or cancelled status lookups preserve the held activity.
- Preserve session profile IDs, scopes, and custom profile names when decoding and storing sessions.
- Decode null activity results while MFA is pending.
- Preserve the session profile during selected and background session refresh, including auto-refresh.
- Wrap approval and rejection requests in activity envelopes and use the activity organization when polling and querying MFA status.
- Correct the generated EIP-7702 undelegation activity mapping and query endpoint classification.
- Add a compile-checked [scoped recovery example](Examples/scoped-recovery/README.md).

`SessionType` now includes `.custom(String)` for session profile names. Applications with exhaustive switches must handle this case. `rawValue` continues to return the original wire string.

