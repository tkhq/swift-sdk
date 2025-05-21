import SwiftUI

@main
struct DemoWalletApp: App {
    @StateObject private var session = SessionStore()
        var body: some Scene {
            WindowGroup {
                AppView()
                    .environmentObject(session)
            }
        }
}
