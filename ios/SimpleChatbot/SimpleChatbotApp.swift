import SwiftUI

@main
struct SimpleChatbotApp: App {

    @StateObject var callContainerModel = CallContainerModel()
    @StateObject var screenTimeManager = ScreenTimeManager()
    @StateObject var appBlockingState = AppBlockingState()

    var body: some Scene {
        WindowGroup {
            if (!callContainerModel.isInCall) {
                PreJoinView()
                    .environmentObject(callContainerModel)
                    .environmentObject(screenTimeManager)
                    .environmentObject(appBlockingState)
            } else {
                MeetingView()
                    .environmentObject(callContainerModel)
                    .environmentObject(screenTimeManager)
                    .environmentObject(appBlockingState)
            }
        }
        .onChange(of: callContainerModel.isInCall) { _, _ in
            // Ensure Screen Time objects are available to the model
            callContainerModel.configure(
                screenTimeManager: screenTimeManager,
                appBlockingState: appBlockingState
            )
        }
    }

    init() {
        // Request Screen Time authorization on launch
        Task { @MainActor in
            let manager = ScreenTimeManager()
            if manager.authorizationStatus == .notDetermined {
                await manager.requestAuthorization()
            }
        }
    }

}
