import SwiftUI
import TurnkeySwift

struct HomeView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var turnkey: TurnkeyContext
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Authentication Successful")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("You are now logged in")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Account info
                VStack(alignment: .leading, spacing: 16) {
                    Text("Account Information")
                        .font(.headline)
                    
                    HStack {
                        Text("Status:")
                            .fontWeight(.semibold)
                        switch turnkey.authState {
                        case .authenticated:
                            Text("Authenticated").foregroundColor(.green)
                        case .loading:
                            Text("Loading").foregroundColor(.orange)
                        default:
                            Text("Not authenticated").foregroundColor(.red)
                        }
                    }
                    
                    if turnkey.client != nil {
                        Text("Client is initialized and ready to use")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
                
                // Logout button
                Button {
                    sessionManager.logout()
                } label: {
                    Text("Log Out")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.bottom, 20)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(SessionManager())
}
