//
//  Mindful_BlockerApp.swift
//  Mindful Blocker
//
//  Created by Gabe Montague on 1/30/26.
//

import SwiftUI

@main
struct Mindful_BlockerApp: App {
    @State private var screenTimeManager = ScreenTimeManager()
    @State private var appBlockingState = AppBlockingState()

    var body: some Scene {
        WindowGroup {
            ChatView(
                screenTimeManager: screenTimeManager,
                appBlockingState: appBlockingState
            )
            .task {
                if screenTimeManager.authorizationStatus == .notDetermined {
                    await screenTimeManager.requestAuthorization()
                }
            }
        }
    }
}
