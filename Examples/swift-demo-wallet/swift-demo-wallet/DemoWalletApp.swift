import SwiftUI
import TurnkeySwift

@main
struct DemoWalletApp: App {
    @StateObject private var turnkey: TurnkeyContext
    @StateObject private var auth: AuthContext
    @StateObject private var toast = ToastContext()
    
    init() {
        let config = TurnkeyConfig(
            apiUrl: Constants.Turnkey.apiUrl,
            authProxyUrl: Constants.Turnkey.authProxyUrl,
            authProxyConfigId: Constants.Turnkey.authProxyConfigId,
            rpId: Constants.App.rpId,
            organizationId: Constants.Turnkey.organizationId,
            auth: .init(
                oauth: .init(
                    appScheme: Constants.App.scheme,
                    providers: .init(
                        google: .init(clientId: Constants.Google.clientId),
                        apple: .init(clientId: Constants.Apple.clientId)
                    )
                )
            )
        )
        TurnkeyContext.configure(config)
        
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
