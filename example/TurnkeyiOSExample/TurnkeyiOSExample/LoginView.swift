import SwiftUI
import TurnkeySDK
import AuthenticationServices

struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel
    @EnvironmentObject private var sessionManager: SessionManager
    
    init(proxyClient: TurnkeyClient, passkeyClient: TurnkeyClient) {
        // Create the view model with required dependencies
        let vm = LoginViewModel(
            proxyClient: proxyClient,
            passkeyClient: passkeyClient,
            sessionManager: SessionManager()
        )
        _viewModel = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Turnkey Authentication")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Enter your email to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Email input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.headline)
                    
                    TextField("your.email@example.com", text: $viewModel.email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(.bottom, 8)
                    
                    // Error message
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Login button
                Button {
                    Task {
                        await viewModel.authenticate()
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Continue")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(viewModel.email.isEmpty || viewModel.isLoading)
                .opacity(viewModel.email.isEmpty || viewModel.isLoading ? 0.6 : 1.0)
                
                Spacer()
            }
            .padding(.bottom, 20)
            .navigationBarTitleDisplayMode(.inline)
        }
        // Use the environment's session manager instead of the locally created one
        .onAppear {
            viewModel.sessionManager = sessionManager
        }
    }
}

#Preview {
    // Create mock clients for preview
    let proxyClient = TurnkeyClient(proxyURL: "http://localhost:3000/proxy")
    let presentationAnchor = ASPresentationAnchor()
    let passkeyClient = TurnkeyClient(rpId: "com.example.domain", presentationAnchor: presentationAnchor)
    
    return LoginView(proxyClient: proxyClient, passkeyClient: passkeyClient)
        .environmentObject(SessionManager())
}
