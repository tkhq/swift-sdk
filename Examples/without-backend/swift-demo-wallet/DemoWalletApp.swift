import SwiftUI
import TurnkeySwift

@main
struct DemoWalletApp: App {
    @StateObject private var turnkey: TurnkeyContext
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
                        google: .init(primaryClientId: .init(webClientId: Constants.Google.clientId)),
                        apple: .init(primaryClientId: .init(serviceId: Constants.Apple.clientId)),
                        x: .init(primaryClientId: Constants.X.clientId),
                        discord: .init(primaryClientId: Constants.Discord.clientId)
                    )
                )
            )
        )
        TurnkeyContext.configure(config)

        let turnkey = TurnkeyContext.shared
        _turnkey = StateObject(wrappedValue: turnkey)
    }

    var body: some Scene {
        WindowGroup {
            AppView()
                .environmentObject(turnkey)
                .environmentObject(toast)
        }
    }
}
