import SwiftUI

final class SessionStore: ObservableObject {
    @Published var isAuthenticated = false
}
