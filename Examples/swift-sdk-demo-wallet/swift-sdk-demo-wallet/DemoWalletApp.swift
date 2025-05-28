import SwiftUI
import TurnkeySwift

@main
struct DemoWalletApp: App {
    @StateObject private var sessions: SessionManager
    @StateObject private var authVM: AuthViewModel

    init() {
        let sessions = SessionManager.shared
        _sessions = StateObject(wrappedValue: sessions)
        _authVM = StateObject(wrappedValue: AuthViewModel(authService: AuthService(sessions: sessions)))
    }

    var body: some Scene {
        WindowGroup {
            AppView()
                .environmentObject(authVM)
                .environmentObject(sessions)
        }
    }
}

