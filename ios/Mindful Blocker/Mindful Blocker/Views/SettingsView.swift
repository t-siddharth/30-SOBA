//
//  SettingsView.swift
//  Mindful Blocker
//

import SwiftUI
import FamilyControls

struct SettingsView: View {
    @Bindable var screenTimeManager: ScreenTimeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Screen Time Authorization") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(authorizationStatusText)
                            .foregroundColor(authorizationStatusColor)
                    }

                    if screenTimeManager.authorizationStatus != .approved {
                        Button("Request Authorization") {
                            Task {
                                await screenTimeManager.requestAuthorization()
                            }
                        }
                    }
                }

                Section("App Blocking") {
                    HStack {
                        Text("Blocking Active")
                        Spacer()
                        Image(systemName: screenTimeManager.isBlockingActive ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(screenTimeManager.isBlockingActive ? .green : .secondary)
                    }

                    if screenTimeManager.isBlockingActive {
                        Button("Unblock All Apps", role: .destructive) {
                            screenTimeManager.unblockAllApps()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var authorizationStatusText: String {
        switch screenTimeManager.authorizationStatus {
        case .notDetermined:
            return "Not Determined"
        case .denied:
            return "Denied"
        case .approved:
            return "Approved"
        @unknown default:
            return "Unknown"
        }
    }

    private var authorizationStatusColor: Color {
        switch screenTimeManager.authorizationStatus {
        case .approved:
            return .green
        case .denied:
            return .red
        default:
            return .secondary
        }
    }
}
