import SwiftUI

@MainActor
final class ToastManager: ObservableObject {
    @Published var message: String = ""
    @Published var type: ToastType = .success
    @Published var isVisible: Bool = false

    func show(message: String, type: ToastType = .success, duration: TimeInterval = 2.5) {
        self.message = message
        self.type = type
        withAnimation {
            isVisible = true
        }

        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            withAnimation {
                isVisible = false
            }
        }
    }
}

enum ToastType {
    case success
    case error

    var backgroundColor: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        }
    }
}


struct ToastView: View {
    let message: String
    let type: ToastType

    var body: some View {
        VStack {
            Spacer().frame(height: UIApplication.shared.topSafeArea + 8)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding()
                .background(type.backgroundColor)
                .cornerRadius(12)
                .padding(.horizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .transition(.move(edge: .top).combined(with: .opacity))
        .zIndex(999)
    }
}


extension UIApplication {
    var topSafeArea: CGFloat {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 0
    }
}
