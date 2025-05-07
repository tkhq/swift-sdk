//
//  AppDelegate.swift
//  TurnkeyiOSExample
//
//  Created by Taylor Dawson on 4/13/24.
//

import SwiftData
import TurnkeySDK
import UIKit

// @main attribute removed to allow SwiftUI lifecycle
class AppDelegate: UIResponder, UIApplicationDelegate {
    let accountManager = AccountManager()
    var modelContainer: ModelContainer?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Initialize the ModelContainer
        do {
            modelContainer = try ModelContainer(for: User.self)
            
        } catch {
            fatalError("Failed to initialize the model container: \(error)")
        }

        return true
    }
    
    // Accessor for ModelContext
    static var userModelContext: ModelContext {
        // Ensure we are on the main thread when accessing the context
        if Thread.isMainThread {
            guard let context = (UIApplication.shared.delegate as? AppDelegate)?.modelContainer?.mainContext else {
                fatalError("ModelContainer is not initialized")
            }
            return context
        } else {
            var context: ModelContext?
            DispatchQueue.main.sync {
                context = (UIApplication.shared.delegate as? AppDelegate)?.modelContainer?.mainContext
            }
            guard let mainContext = context else {
                fatalError("ModelContainer is not initialized")
            }
            return mainContext
        }
    }

    // MARK: UISceneSession Lifecycle

    func application(
        _ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // The system calls this method when creating a new scene.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(
            name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(
        _ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {
        // The system calls this method when the user discards a scene session.
        // If the system discards any sessions while the app isn't running,
        // it calls this shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that are specific to the discarded scenes, because they don't return.
    }
}
