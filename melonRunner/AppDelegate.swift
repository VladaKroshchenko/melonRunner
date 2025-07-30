//
//  AppDelegate.swift
//  melonRunner
//
//  Created by Emelyanov Artem on 29.07.2025.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = MenuView()
        self.window = window
        window.makeKeyAndVisible()
        return true
    }
}
