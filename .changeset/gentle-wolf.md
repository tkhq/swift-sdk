---
bump: major
---

### OAuth provider config restructured

**What changed:** The generic `OauthProviderOverride` / `OauthProvidersPartial` types were replaced with per-provider config structs (`GoogleOAuthProviderParams`, `AppleOAuthProviderParams`, `XOAuthProviderParams`, `DiscordOAuthProviderParams`). Each provider now has a typed `primaryClientId` and optional `secondaryClientIds` instead of a flat `clientId` string.

```swift
// before
TurnkeyConfig(
  auth: .init(
    oauth: .init(
      providers: .init(
        google: .init(clientId: "<google-client-id>"),
        apple: .init(clientId: "<apple-service-id>")
      )
    )
  )
)

// after
TurnkeyConfig(
  auth: .init(
    oauth: .init(
      providers: .init(
        google: .init(
          primaryClientId: .init(webClientId: "<google-client-id>"),
          secondaryClientIds: ["<google-client-id-2>"]
        ),
        apple: .init(
          primaryClientId: .init(serviceId: "<apple-service-id>")
        )
      )
    )
  )
)
```

---

### Secondary client IDs

**What changed:** Every `handle*OAuth` function (`handleGoogleOAuth`, `handleAppleOAuth`, `handleAppleWebOauth`, `handleDiscordOAuth`, `handleXOauth`) now accepts `secondaryClientIds: [String]?`. Per-call overrides take precedence over the values in `TurnkeyConfig`.

`secondaryClientIds` are additional client IDs that get linked to the user during sign-up: they're decoded into `oidcClaims` (`{ iss, sub, aud }`) sharing the same identity as the primary OIDC token and registered as additional audiences during sub-organization creation. This lets a user who signed in with one client ID on one platform sign in with a different client ID on another platform and resolve to the same sub-organization.

```swift
// before
try await turnkey.handleGoogleOAuth(anchor: window, clientId: "<google-client-id>")

// after
try await turnkey.handleGoogleOAuth(
  anchor: window,
  clientId: "<google-client-id>",
  secondaryClientIds: ["<google-client-id-2>"]
)
```

---

### Native Apple Sign-In

**What changed:** `handleAppleOAuth` now uses native Apple Sign-In (`ASAuthorizationAppleIDProvider`) instead of a web-based `ASWebAuthenticationSession`. It no longer requires an `anchor` or `clientId` parameter — the bundle ID is used as the primary audience automatically. The `serviceId` (web client ID) from config is prepended to `secondaryClientIds` so it gets registered as an additional provider during sub-org creation.

The previous web-based Apple OAuth flow was renamed to `handleAppleWebOauth` and is still available.

```swift
// before (web-based)
try await turnkey.handleAppleOAuth(anchor: window)

// after (native)
try await turnkey.handleAppleOAuth()

// web-based flow is still available as:
try await turnkey.handleAppleWebOauth(anchor: window)
```

