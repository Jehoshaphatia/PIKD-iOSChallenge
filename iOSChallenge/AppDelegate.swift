//
//  AppDelegate.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import UIKit
import SwiftUI

/** Main application delegate handling app lifecycle and scene configuration for the AR demo app. */
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    /** Configures initial app state after launch.
     - Parameters:
         - application: The singleton app instance
         - launchOptions: Launch configuration dictionary
     - Returns: Success indicator for URL resource handling
     */
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    // MARK: - UISceneSession Lifecycle

    /** Configures and returns a new scene session.
     - Parameters:
         - application: The singleton app instance
         - connectingSceneSession: New session being created
         - options: Scene creation options
     - Returns: Scene configuration object
     */
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    /** Handles cleanup when scene sessions are discarded.
     - Parameters:
         - application: The singleton app instance
         - sceneSessions: The set of discarded sessions
     */
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}

