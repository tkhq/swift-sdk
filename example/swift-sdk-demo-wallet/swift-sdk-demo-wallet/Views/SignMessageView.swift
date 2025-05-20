import SwiftUI

struct SignMessageView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    
    @State private var message = "I love Turnkey"
    @State private var signature: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Message to Sign")
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                
                TextEditor(text: $message)
                    .font(.system(size: 14))
                    .frame(height: 100)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3))
                    )
                    .background(Color.white)
                    .cornerRadius(8)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            // if the user hasn't signed yet, we show the "Sign" button
            if signature == nil {
                Button("Sign", action: handleSignPressed)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            
            // display the signature result
            if let sig = signature {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Signature")
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                    
                    ScrollView {
                        Text(sig)
                            .font(.system(size: 12))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
            }
            
            Spacer()
            
            // show the "Done" button when there is a signature
            if signature != nil {
                Button("Done", action: handleDonePressed)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(10)
            }
        }
        .padding()
        .navigationTitle("Sign Message")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func handleSignPressed() {
        // add actual signing logic here
        
        signature = "signed(\(message))"
    }
    
    private func handleDonePressed() {
        coordinator.pop()
    }
}

#Preview {
    SignMessageView()
        .environmentObject(SessionStore())
        .environmentObject(NavigationCoordinator())
}
