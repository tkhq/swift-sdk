import SwiftUI
import TurnkeySwift

@main
struct DemoWalletApp: App {
    @StateObject private var turnkey: TurnkeyContext
    @StateObject private var auth: AuthContext
    @StateObject private var toast = ToastContext()
    
    init() {
        TurnkeyContext.configure(apiUrl: Constants.Turnkey.apiUrl, authProxyUrl: Constants.Turnkey.authProxyUrl, authProxyConfigId: Constants.Turnkey.authProxyConfigId)
        
        let turnkey = TurnkeyContext.shared
        _turnkey = StateObject(wrappedValue: turnkey)
        _auth = StateObject(wrappedValue: AuthContext(turnkey: turnkey))
    }
    
    var body: some Scene {
        WindowGroup {
            AppView()
                .environmentObject(auth)
                .environmentObject(turnkey)
                .environmentObject(toast)
        }
    }
}
