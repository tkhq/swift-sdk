//
//  AppDelegate.swift
//  TurnkeyiOSExample
//
//  Created by Taylor Dawson on 4/13/24.
//

import TurnkeySDK
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  let accountManager = AccountManager()

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The override point for customization after app launch.
    return true
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
