import Combine
import CryptoKit
import Foundation
import AuthenticationServices
import TurnkeyHttp

public final class TurnkeyContext: NSObject, ObservableObject {
    
    // public state
    @Published public internal(set) var authState: AuthState = .loading
    @Published public internal(set) var client: TurnkeyClient?
    @Published public internal(set) var selectedSessionKey: String?
    @Published public internal(set) var user: SessionUser?
    
    // internal state
    internal var expiryTasks: [String: DispatchSourceTimer] = [:]
    internal let apiUrl: String
    internal let authProxyUrl: String
    internal let authProxyConfigId: String?
    internal let rpId: String?
    
    // configurable base URL, auth proxy URL, auth proxy config Id, and rpId
    private static var _apiUrl: String = Constants.Turnkey.defaultApiUrl
    private static var _authProxyUrl: String = Constants.Turnkey.defaultAuthProxyUrl
    private static var _authProxyConfigId: String? = nil
    private static var _rpId: String? = nil
    
    internal weak var oauthAnchor: ASPresentationAnchor?
    
    public static func configure(
        apiUrl: String = Constants.Turnkey.defaultApiUrl,
        authProxyUrl: String = Constants.Turnkey.defaultAuthProxyUrl,
        authProxyConfigId: String? = nil,
        rpId: String? = nil
    ) {
        _apiUrl = apiUrl
        _authProxyUrl = authProxyUrl
        _authProxyConfigId = authProxyConfigId
        _rpId = rpId
    }

    
    public static let shared = TurnkeyContext(
        apiUrl: _apiUrl,
        authProxyUrl: _authProxyUrl,
        authProxyConfigId: _authProxyConfigId,
        rpId: _rpId
    )
    
    private override init() {
        self.apiUrl = Constants.Turnkey.defaultApiUrl
        self.authProxyUrl = Constants.Turnkey.defaultAuthProxyUrl
        self.authProxyConfigId = nil
        self.rpId = nil
        
        self.client = nil
        
        super.init()
        self.postInitSetup()
    }
    
    private init(apiUrl: String, authProxyUrl: String, authProxyConfigId: String?, rpId: String?) {
        self.apiUrl = apiUrl
        self.authProxyUrl = authProxyUrl
        self.authProxyConfigId = authProxyConfigId
        self.rpId = rpId
        
        super.init()
        
        self.client = self.makeAuthProxyClientIfNeeded()
        self.postInitSetup()
    }
    
    private func postInitSetup() {
        // clean up expired sessions and pending keys
        SessionRegistryStore.purgeExpiredSessions()
        PendingKeysStore.purge()
        
        
        // restore session and timers after launch
        Task { [weak self] in
            await self?.rescheduleAllSessionExpiries()
            await self?.restoreSelectedSession()
        }
        
        // clean up periodically when app enters foreground
        if let note = Self.foregroundNotification {
            Task.detached {
                for await _ in NotificationCenter.default.notifications(named: note) {
                    PendingKeysStore.purge()
                    SessionRegistryStore.purgeExpiredSessions()
                }
            }
        }
    }
    
    /// creates a `TurnkeyClient` for Auth Proxy requests if a config ID is set
    internal func makeAuthProxyClientIfNeeded() -> TurnkeyClient? {
        if let configId = self.authProxyConfigId {
            return TurnkeyClient(
                authProxyConfigId: configId,
                authProxyUrl: self.authProxyUrl
            )
        } else {
            return nil
        }
    }
}

