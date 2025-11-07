import SwiftUI
import TurnkeySwift

enum AuthRoute: Hashable {
    case otp(otpId: String, contact: String, otpType: OtpType)
    case keyManager
}

enum MainRoute: Hashable {
    case settings
    case importWallet
    case signMessage(walletAddress: String)
}

struct AuthFlow: View {
    @StateObject private var nav = NavigationCoordinator()
    @EnvironmentObject private var turnkey: TurnkeyContext
    
    var body: some View {
        NavigationStack(path: $nav.path) {
            AuthView()
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case let .otp(id, contact, otpType):
                        OtpView(otpId: id, contact: contact, otpType: otpType) { otpCode in
                            try await turnkey.completeOtp(
                                otpId: id,
                                otpCode: otpCode,
                                contact: contact,
                                otpType: otpType
                            )
                        }
                    case .keyManager:
                        KeyManagerView()
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
    @EnvironmentObject private var toast:  ToastContext
    
    @State private var hasLoaded = false
    
    var body: some View {
        ZStack(alignment: .top) {
            Group {
                switch turnkey.authState {
                case .loading:
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.red)
                        .transition(.opacity)
                    
                case .unAuthenticated:
                    AuthFlow()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal:   .move(edge: .leading)
                        ))
                        .onAppear { hasLoaded = true }
                    
                case .authenticated:
                    MainFlow()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal:   .move(edge: .trailing)
                        ))
                        .onAppear { hasLoaded = true }
                }
            }
            
            // add toast overlay
            if toast.isVisible {
                ToastView(message: toast.message, type: toast.type)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // we only animate once we've left .loading at least once
        // this is to avoid showing a transition when going from loading
        // to another auth state
        .animation(hasLoaded ? .easeInOut : nil, value: turnkey.authState)
    }
}
