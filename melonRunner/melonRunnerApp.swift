//
//  melonRunnerApp.swift
//  melonRunner
//
//  Created by Kroshchenko Vlada on 29.07.2025.
//

import SwiftUI

@main
struct melonRunnerApp: App {
    // Указываем SwiftUI использовать AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
