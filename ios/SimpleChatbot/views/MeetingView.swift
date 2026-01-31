import SwiftUI
import FamilyControls

// MARK: - App Picker Sheet

struct AppPickerSheet: View {
    @ObservedObject var appBlockingState: AppBlockingState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Text("Select apps and categories to block")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                FamilyActivityPicker(selection: $appBlockingState.selection)
            }
            .navigationTitle("Select Apps")
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
}

// MARK: - Meeting View

struct MeetingView: View {

    @State private var showingSettings = false
    @State private var showingAppPicker = false
    @EnvironmentObject private var model: CallContainerModel
    @EnvironmentObject private var screenTimeManager: ScreenTimeManager
    @EnvironmentObject private var appBlockingState: AppBlockingState

    var body: some View {
        VStack {
            VStack {
                ChatView().frame(maxHeight: .infinity)
                MicrophoneView(audioLevel: 0, isMuted: !self.model.isMicEnabled)
                    .frame(width: 100, height: 100)
                    .onTapGesture {
                        self.model.toggleMicInput()
                    }

                // App Picker and Settings buttons
                HStack(spacing: 12) {
                    Button(action: {
                        self.showingAppPicker = true
                    }) {
                        HStack {
                            Image(systemName: "apps.iphone")
                                .resizable()
                                .frame(width: 20, height: 24)
                            Text("Apps")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .border(Color.buttonsBorder, width: 1)
                    .cornerRadius(12)
                    .sheet(isPresented: $showingAppPicker) {
                        AppPickerSheet(appBlockingState: appBlockingState)
                    }

                    Button(action: {
                        self.showingSettings = true
                    }) {
                        HStack {
                            Image(systemName: "gearshape")
                                .resizable()
                                .frame(width: 24, height: 24)
                            Text("Settings")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .sheet(isPresented: $showingSettings) {
                            SettingsView(showingSettings: $showingSettings).environmentObject(self.model)
                        }
                    }
                    .border(Color.buttonsBorder, width: 1)
                    .cornerRadius(12)
                }
                .foregroundColor(.black)
                .padding([.top, .horizontal])
                
                Button(action: {
                    self.model.disconnect()
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text("End")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .foregroundColor(.white)
                .background(Color.black)
                .cornerRadius(12)
                .padding([.bottom, .horizontal])
            }
        }
        .background(Color.backgroundApp)
        .toast(message: model.toastMessage, isShowing: model.showToast)
    }
}

#Preview {
    let mockModel = MockCallContainerModel()
    let result = MeetingView().environmentObject(mockModel as CallContainerModel)
    return result
}
