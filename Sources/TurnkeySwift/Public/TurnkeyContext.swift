import Combine
import CryptoKit
import Foundation
import AuthenticationServices
import TurnkeyTypes
import TurnkeyHttp

public final class TurnkeyContext: NSObject, ObservableObject {
    
    // public state
    @Published public internal(set) var authState: AuthState = .loading
    
    /// this is `nil` if no `authProxyConfigId` is provided in the configuration
    /// and there are no active sessions
    @Published public internal(set) var client: TurnkeyClient?
    
    @Published public internal(set) var selectedSessionKey: String?
    @Published public internal(set) var session: Session?
    @Published public internal(set) var user: v1User?
    @Published public internal(set) var wallets: [Wallet] = []
    @Published internal var runtimeConfig: TurnkeyRuntimeConfig?
    
    // internal state
    internal var expiryTasks: [String: DispatchSourceTimer] = [:]
    internal let userConfig: TurnkeyConfig
    internal let apiUrl: String
    internal let authProxyUrl: String
    internal let authProxyConfigId: String?
    internal let rpId: String?
    internal let organizationId: String?
    internal weak var oauthAnchor: ASPresentationAnchor?
    
    // Single user config captured at configure-time
    private static var _config: TurnkeyConfig = TurnkeyConfig()
    
    public static func configure(_ config: TurnkeyConfig) {
        _config = config
    }

    
    public static let shared = TurnkeyContext(config: _config)
    
    private override init() {
        let cfg = TurnkeyConfig()
        self.apiUrl = cfg.apiUrl
        self.authProxyUrl = cfg.authProxyUrl
        self.authProxyConfigId = cfg.authProxyConfigId
        self.rpId = cfg.rpId
        self.organizationId = cfg.organizationId
        self.userConfig = cfg
        self.client = nil
        super.init()
        self.postInitSetup()
    }
    
    private init(config: TurnkeyConfig) {
        self.apiUrl = config.apiUrl
        self.authProxyUrl = config.authProxyUrl
        self.authProxyConfigId = config.authProxyConfigId
        self.rpId = config.rpId
        self.organizationId = config.organizationId
        self.userConfig = config
        super.init()
        self.client = self.makeAuthProxyClientIfNeeded()
        self.postInitSetup()
    }
    
    private func postInitSetup() {
        // clean up expired sessions and pending keys
        SessionRegistryStore.purgeExpiredSessions()
        PendingKeysStore.purge()
        
        
        // build runtime configuration, restore session and timers after launch
        Task { [weak self] in
            await self?.rescheduleAllSessionExpiries()
            await self?.restoreSelectedSession()
            
            // we call this last because `restoreSelectedSession()` sets the authentication
            // state and we don't want this to slow that down
            // TODO: how should this affect authentication state if this fails?
            await self?.initializeRuntimeConfig()
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
}

