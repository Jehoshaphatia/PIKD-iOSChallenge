//
//  SceneDelegate.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 19/09/2025.
//

import UIKit
import SwiftUI

/** 
 Main scene delegate for managing the app's window and UI lifecycle.
 Handles window setup, state transitions, and SwiftUI integration.
 */
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    /** Main application window */
    var window: UIWindow?

    /** 
     Configures the window and root view controller when a new scene connects.
     Sets up SwiftUI integration via UIHostingController.
     */
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView()

        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
    }

    /** Scene is being released by the system. Clean up any resources. */
    func sceneDidDisconnect(_ scene: UIScene) {}

    /** Scene became active. Restart previously paused tasks. */
    func sceneDidBecomeActive(_ scene: UIScene) {}

    /** Scene will become inactive. Handle temporary interruptions. */
    func sceneWillResignActive(_ scene: UIScene) {}

    /** Scene transitions to foreground. Restore state if needed. */
    func sceneWillEnterForeground(_ scene: UIScene) {}

    /** Scene transitions to background. Save state if needed. */
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
