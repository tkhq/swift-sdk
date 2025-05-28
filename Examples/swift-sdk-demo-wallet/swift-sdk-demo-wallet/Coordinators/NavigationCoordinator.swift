import SwiftUI

final class NavigationCoordinator: ObservableObject {
    @Published var path = NavigationPath()

    func push<Route: Hashable>(_ route: Route) { path.append(route) }
    func pop()                                 { if !path.isEmpty { path.removeLast() } }
    func popToRoot()                           { path.removeLast(path.count) }
}
