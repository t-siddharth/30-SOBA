//
//  SettingsView.swift
//  Mindful Blocker
//

import SwiftUI
import FamilyControls

struct SettingsView: View {
    @Bindable var screenTimeManager: ScreenTimeManager
    @Bindable var appBlockingState: AppBlockingState
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

                Section("App Selection") {
                    HStack {
                        Text("Selected Apps")
                        Spacer()
                        Text("\(appBlockingState.selection.applicationTokens.count)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Selected Categories")
                        Spacer()
                        Text("\(appBlockingState.selection.categoryTokens.count)")
                            .foregroundColor(.secondary)
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
                            print("[Test] Unblocked all apps")
                        }
                    }
                }

                Section("Testing") {
                    Button("Test: Block Selected Apps") {
                        print("[Test] Blocking apps...")
                        print("[Test] Apps: \(appBlockingState.selection.applicationTokens.count), Categories: \(appBlockingState.selection.categoryTokens.count)")
                        screenTimeManager.blockApps(selection: appBlockingState.selection)
                        print("[Test] Block complete, isBlockingActive: \(screenTimeManager.isBlockingActive)")
                    }
                    .disabled(appBlockingState.selection.applicationTokens.isEmpty && appBlockingState.selection.categoryTokens.isEmpty)

                    Button("Test: Unblock All") {
                        print("[Test] Unblocking all...")
                        screenTimeManager.unblockAllApps()
                        print("[Test] Unblock complete, isBlockingActive: \(screenTimeManager.isBlockingActive)")
                    }

                    Button("Test: Check Status") {
                        print("[Test] Status check:")
                        print("[Test]   Authorization: \(screenTimeManager.authorizationStatus)")
                        print("[Test]   Blocking active: \(screenTimeManager.isBlockingActive)")
                        print("[Test]   Selected apps: \(appBlockingState.selection.applicationTokens.count)")
                        print("[Test]   Selected categories: \(appBlockingState.selection.categoryTokens.count)")
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
