//
//  TurnkeyiOSExampleApp.swift
//  TurnkeyiOSExample
//
//  Created by Taylor Dawson on 4/12/24.
//

import SwiftUI

@main
struct TurnkeyiOSExampleApp: App {
  // Create a session manager to be shared across the app
  @StateObject private var sessionManager = SessionManager()
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(sessionManager)
    }
  }
}
