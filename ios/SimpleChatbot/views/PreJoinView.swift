import SwiftUI
import FamilyControls

// MARK: - Secrets

struct PreJoinView: View {

    @State private var showingAppPicker = false

    @EnvironmentObject private var model: CallContainerModel
    @EnvironmentObject private var screenTimeManager: ScreenTimeManager
    @EnvironmentObject private var appBlockingState: AppBlockingState

    var body: some View {
        VStack(spacing: 20) {
            Image("pipecat")
                .resizable()
                .frame(width: 80, height: 80)
            Text("Mindful Blocker")
                .font(.headline)
            Text("AI-powered Screen Time assistant")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // App selection info
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "apps.iphone")
                    Text("\(appBlockingState.selection.applicationTokens.count) apps selected")
                    Spacer()
                    Button("Select Apps") {
                        showingAppPicker = true
                    }
                    .sheet(isPresented: $showingAppPicker) {
                        AppPickerSheet(appBlockingState: appBlockingState)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)

                if screenTimeManager.authorizationStatus != .approved {
                    Button("Authorize Screen Time") {
                        Task {
                            await screenTimeManager.requestAuthorization()
                        }
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)

            Button("Connect") {
                self.model.connect(openaiAPIKey: Secrets.openAIAPIKey)
            }
            .padding()
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .frame(maxHeight: .infinity)
        .background(Color.backgroundApp)
        .toast(message: model.toastMessage, isShowing: model.showToast)
        .task {
            if screenTimeManager.authorizationStatus == .notDetermined {
                await screenTimeManager.requestAuthorization()
            }
        }
    }
}

#Preview {
    PreJoinView()
        .environmentObject(MockCallContainerModel() as CallContainerModel)
        .environmentObject(ScreenTimeManager())
        .environmentObject(AppBlockingState())
}
