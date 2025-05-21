import SwiftUI

enum AuthRoute: Hashable {
    case otp(otpId: String, organizationId: String, contact: String)
}

enum MainRoute: Hashable {
    case settings
    case importWallet
    case signMessage
}

struct AuthFlow: View {
    @StateObject private var nav = NavigationCoordinator()
    
    var body: some View {
        NavigationStack(path: $nav.path) {
            AuthView()
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case let .otp(id, orgId, contact):
                        OtpView(otpId: id, organizationId: orgId, contact: contact)
                    }
                }
        }
        .environmentObject(nav)
    }
}

struct MainFlow: View {
    @StateObject private var nav = NavigationCoordinator()
    
    var body: some View {
        NavigationStack(path: $nav.path) {
            DashboardView()
                .navigationBarBackButtonHidden(true)
                .navigationDestination(for: MainRoute.self) { route in
                    switch route {
                    case .settings:
                        SettingsView()
                    case .importWallet:
                        ImportWalletView()
                    case .signMessage:
                        SignMessageView()
                    }
                }
        }
        .environmentObject(nav)
    }
}

struct AppView: View {
    @EnvironmentObject private var session: SessionStore
    
    var body: some View {
        ZStack {
            if session.isAuthenticated {
                MainFlow()
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing),  
                            removal:   .move(edge: .trailing)
                        )
                    )
            } else {
                AuthFlow()
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .leading),
                            removal:   .move(edge: .leading)
                        )
                    )
            }
        }
        .animation(.easeInOut, value: session.isAuthenticated)
    }
}

#Preview {
    AppView()
        .environmentObject(SessionStore())
}
