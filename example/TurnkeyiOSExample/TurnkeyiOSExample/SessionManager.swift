import Foundation
import TurnkeySDK
import SwiftUI
import Combine

/// Manages the authenticated TurnkeyClient session across the app
final class SessionManager: ObservableObject {
    /// The currently authenticated TurnkeyClient instance
    @Published var client: TurnkeyClient?
    
    /// Clears the current session
    func logout() {
        client = nil
    }
}
