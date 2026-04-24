import SwiftUI
import TurnkeySwift

@main
struct DemoWalletApp: App {
    @StateObject private var turnkey: TurnkeyContext
    @StateObject private var toast = ToastContext()

    init() {
        let config = TurnkeyConfig(
            organizationId: Constants.Turnkey.organizationId,
            apiUrl: Constants.Turnkey.apiUrl,
            authProxyUrl: Constants.Turnkey.authProxyUrl,
            authProxyConfigId: Constants.Turnkey.authProxyConfigId,
            rpId: Constants.App.rpId,
            auth: .init(
                oauth: .init(
                    appScheme: Constants.App.scheme,
                    providers: .init(
                        google: .init(
                            primaryClientId: .init(webClientId: Constants.Google.clientId),
                            secondaryClientIds: Constants.Google.secondaryClientIds
                        ),
                        apple: .init(
                            primaryClientId: .init(serviceId: Constants.Apple.clientId),
                            secondaryClientIds: Constants.Apple.secondaryClientIds
                        ),
                        x: .init(
                            primaryClientId: Constants.X.clientId,
                            secondaryClientIds: Constants.X.secondaryClientIds
                        ),
                        discord: .init(
                            primaryClientId: Constants.Discord.clientId,
                            secondaryClientIds: Constants.Discord.secondaryClientIds
                        )
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
