//
//  ContentView.swift
//  TurnkeyiOSExample
//
//  Created by Taylor Dawson on 4/12/24.
//

import SwiftUI
import TurnkeySDK
import AuthenticationServices

struct ContentView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  
  // Create clients for authentication
  private let proxyClient = TurnkeyClient(proxyURL: "http://localhost:3000/proxy")
  private let passkeyClient: TurnkeyClient
  
  init() {
    // Create the presentation anchor for passkey authentication
    let presentationAnchor = ASPresentationAnchor()
    self.passkeyClient = TurnkeyClient(rpId: "com.example.domain", presentationAnchor: presentationAnchor)
  }
  
  var body: some View {
    ZStack {
      // Show HomeView if authenticated, otherwise show LoginView
      if sessionManager.client != nil {
        HomeView()
      } else {
        LoginView(proxyClient: proxyClient, passkeyClient: passkeyClient)
      }
    }
  }
}

#Preview {
  ContentView()
    .environmentObject(SessionManager())
}
