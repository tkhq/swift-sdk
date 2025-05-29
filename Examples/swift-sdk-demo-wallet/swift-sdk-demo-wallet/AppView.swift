import SwiftUI
import TurnkeySwift

enum AuthRoute: Hashable {
    case otp(otpId: String, contact: String, publicKey: String)
}

enum MainRoute: Hashable {
    case settings
    case importWallet
    case signMessage(walletAddress: String)
}

struct AuthFlow: View {
    @StateObject private var nav = NavigationCoordinator()
    
    var body: some View {
        NavigationStack(path: $nav.path) {
            AuthView()
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case let .otp(id, contact, publicKey):
                        OtpView(otpId: id, contact: contact, publicKey: publicKey)
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
                    case let .signMessage(walletAddress):
                        SignMessageView(walletAddress: walletAddress)
                    }
                }
        }
        .environmentObject(nav)
    }
}

struct AppView: View {
    @EnvironmentObject private var turnkey: TurnkeyContext
    @EnvironmentObject private var toast: ToastManager

    var body: some View {
        ZStack(alignment: .top) {
            if turnkey.client != nil {
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

            // add toast overlay
            if toast.isVisible {
                ToastView(message: toast.message, type: toast.type)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: turnkey.client == nil)
    }
}

#Preview {
    AppView()
        .environmentObject(TurnkeyContext.shared)
        .environmentObject(ToastManager())
}
