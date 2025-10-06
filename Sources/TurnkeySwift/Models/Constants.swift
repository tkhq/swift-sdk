import Foundation

public enum Constants {

  public enum Session {
    public static let defaultSessionKey = "com.turnkey.sdk.session"
    public static let defaultExpirationSeconds = "900"
  }

  public enum Storage {
    public static let secureAccount = "p256-private"
    public static let selectedSessionKey = "com.turnkey.sdk.selectedSession"
    public static let sessionRegistryKey = "com.turnkey.sdk.sessionKeys"
    public static let pendingKeysStoreKey = "com.turnkey.sdk.pendingList"
    public static let autoRefreshStoreKey = "com.turnkey.sdk.autoRefresh"
  }

  public enum Turnkey {
    public static let defaultApiUrl = "https://api.turnkey.com"
    public static let defaultAuthProxyUrl = "https://authproxy.turnkey.com"
    public static let oauthOriginUrl = "https://oauth-origin.turnkey.com"
    public static let oauthRedirectUrl = "https://oauth-redirect.turnkey.com"
  }
}
