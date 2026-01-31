//
//  ScreenTimeManager.swift
//  Mindful Blocker
//

import Foundation
import FamilyControls
import ManagedSettings

@Observable @MainActor
final class ScreenTimeManager {
    private let store = ManagedSettingsStore()

    var authorizationStatus: AuthorizationStatus = .notDetermined
    var isBlockingActive: Bool = false

    init() {
        updateAuthorizationStatus()
    }

    private func updateAuthorizationStatus() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            updateAuthorizationStatus()
        } catch {
            print("Failed to request authorization: \(error)")
            updateAuthorizationStatus()
        }
    }

    func blockApps(selection: FamilyActivitySelection) {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        isBlockingActive = !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
    }

    func unblockAllApps() {
        store.clearAllSettings()
        isBlockingActive = false
    }
}
