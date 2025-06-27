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
    
    // configurable base URL
    private static var _apiUrl: String = Constants.Turnkey.defaultApiUrl
    
    internal weak var oauthAnchor: ASPresentationAnchor?
    
    public static func configure(apiUrl: String) {
        _apiUrl = apiUrl
    }
    
    public static let shared: TurnkeyContext = TurnkeyContext(apiUrl: _apiUrl)
    
    private override init() {
        self.apiUrl = Constants.Turnkey.defaultApiUrl
        super.init()
        self.postInitSetup()
    }
    
    private init(apiUrl: String) {
        self.apiUrl = apiUrl
        super.init()
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
}

