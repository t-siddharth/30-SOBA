import SwiftUI
import FamilyControls
import ManagedSettings

import PipecatClientIOSOpenAIRealtimeWebrtc
import PipecatClientIOS

// MARK: - Screen Time Manager

@MainActor
class ScreenTimeManager: ObservableObject {
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var isBlockingActive: Bool = false

    private let store = ManagedSettingsStore()

    init() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationStatus = .approved
            print("[ScreenTime] Authorization approved")
        } catch {
            authorizationStatus = .denied
            print("[ScreenTime] Authorization denied: \(error)")
        }
    }

    func blockApps(selection: FamilyActivitySelection) {
        guard authorizationStatus == .approved else {
            print("[ScreenTime] Cannot block - not authorized")
            return
        }

        let applications = selection.applicationTokens
        let categories = selection.categoryTokens

        store.shield.applications = applications.isEmpty ? nil : applications
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)

        isBlockingActive = !applications.isEmpty || !categories.isEmpty
        print("[ScreenTime] Blocking \(applications.count) apps and \(categories.count) categories")
    }

    func unblockAllApps() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        isBlockingActive = false
        print("[ScreenTime] Unblocked all apps")
    }

    func getBlockStatus(selection: FamilyActivitySelection) -> String {
        let appCount = selection.applicationTokens.count
        let categoryCount = selection.categoryTokens.count

        if isBlockingActive {
            return "Blocking is active. \(appCount) apps and \(categoryCount) categories are currently blocked."
        } else if appCount > 0 || categoryCount > 0 {
            return "Blocking is not active. User has selected \(appCount) apps and \(categoryCount) categories that can be blocked."
        } else {
            return "No apps or categories selected for blocking. Ask the user to select apps first using the app picker."
        }
    }
}

// MARK: - App Blocking State

class AppBlockingState: ObservableObject {
    private static let selectionKey = "appBlockingSelection"

    @Published var selection: FamilyActivitySelection {
        didSet {
            saveSelection()
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.selectionKey),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            self.selection = decoded
            print("[AppBlockingState] Loaded \(decoded.applicationTokens.count) apps")
        } else {
            self.selection = FamilyActivitySelection()
        }
    }

    private func saveSelection() {
        if let encoded = try? JSONEncoder().encode(selection) {
            UserDefaults.standard.set(encoded, forKey: Self.selectionKey)
        }
    }
}

// MARK: - Call Container Model

class CallContainerModel: ObservableObject {

    @Published var voiceClientStatus: String = TransportState.disconnected.description
    @Published var isInCall: Bool = false
    @Published var isBotReady: Bool = false

    @Published var isMicEnabled: Bool = false

    @Published var toastMessage: String? = nil
    @Published var showToast: Bool = false

    @Published var messages: [LiveMessage] = []
    @Published var liveBotMessage: LiveMessage?
    @Published var liveUserMessage: LiveMessage?

    var rtviClientIOS: RTVIClient?

    // Screen Time integration
    var screenTimeManager: ScreenTimeManager?
    var appBlockingState: AppBlockingState?

    @Published var selectedMic: MediaDeviceId? = nil {
        didSet {
            guard let selectedMic else { return } // don't store nil
            var settings = SettingsManager.getSettings()
            settings.selectedMic = selectedMic.id
            SettingsManager.updateSettings(settings: settings)
        }
    }
    @Published var availableMics: [MediaDeviceInfo] = []

    init() {
        // Changing the log level
        PipecatClientIOS.setLogLevel(.warn)
        PipecatClientIOSOpenAIRealtimeWebrtc.setLogLevel(.info)
    }

    func configure(screenTimeManager: ScreenTimeManager, appBlockingState: AppBlockingState) {
        self.screenTimeManager = screenTimeManager
        self.appBlockingState = appBlockingState
    }

    @MainActor
    func connect(openaiAPIKey: String) {
        self.resetLiveMessages()
        
        let openaiAPIKey = openaiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if(openaiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty){
            self.showError(message: "Need to provide an OpenAI API key")
            return
        }

        let rtviClientOptions = OpenAIBotConfig.createOptions(openaiAPIKey: openaiAPIKey)
        self.rtviClientIOS = RTVIClient.init(
            transport: OpenAIRealtimeTransport.init(options: rtviClientOptions),
            options: rtviClientOptions
        )
        self.rtviClientIOS?.delegate = self
        
        // Registering the llm helper, we will need this to handle the function calling
        let llmHelper = try? self.rtviClientIOS?.registerHelper(service: "llm", helper: LLMHelper.self)
        llmHelper?.delegate = self
        
        self.rtviClientIOS?.start() { result in
            switch result {
            case .failure(let error):
                self.showError(message: error.localizedDescription)
                self.rtviClientIOS = nil
            case .success():
                // Apply initial mic preference
                if let selectedMic = SettingsManager.getSettings().selectedMic {
                    self.selectMic(MediaDeviceId(id: selectedMic))
                }
                // Populate available devices list
                self.availableMics = self.rtviClientIOS?.getAllMics() ?? []
            }
        }
        self.saveCredentials(openaiAPIKey: openaiAPIKey)
    }

    @MainActor
    func disconnect() {
        self.rtviClientIOS?.disconnect(completion: nil)
        self.rtviClientIOS?.release()
        self.rtviClientIOS = nil
    }

    func showError(message: String) {
        self.toastMessage = message
        self.showToast = true
        // Hide the toast after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.showToast = false
            self.toastMessage = nil
        }
    }

    @MainActor
    func toggleMicInput() {
        self.rtviClientIOS?.enableMic(enable: !self.isMicEnabled) { result in
            switch result {
            case .success():
                self.isMicEnabled = self.rtviClientIOS?.isMicEnabled ?? false
            case .failure(let error):
                self.showError(message: error.localizedDescription)
            }
        }
    }

    func saveCredentials(openaiAPIKey: String) {
        var currentSettings = SettingsManager.getSettings()
        currentSettings.openaiAPIKey = openaiAPIKey
        // Saving the settings
        SettingsManager.updateSettings(settings: currentSettings)
    }

    @MainActor
    func selectMic(_ mic: MediaDeviceId) {
        self.selectedMic = mic
        self.rtviClientIOS?.updateMic(micId: mic, completion: nil)
    }
    
    private func createLiveMessage(content:String = "", type:MessageType) {
        // Creating a new one
        DispatchQueue.main.async {
            let liveMessage = LiveMessage(content: content, type: type, updatedAt: Date())
            self.messages.append(liveMessage)
            if type == .bot {
                self.liveBotMessage = liveMessage
            } else if type == .user {
                self.liveUserMessage = liveMessage
            }
        }
    }
    
    private func appendTextToLiveMessage(fromBot: Bool, content:String) {
        DispatchQueue.main.async {
            // Updating the last message with the new content
            if fromBot {
                self.liveBotMessage?.content += content
            } else {
                self.liveUserMessage?.content += content
            }
        }
    }
    
    private func resetLiveMessages() {
        DispatchQueue.main.async {
            self.messages = []
        }
    }
}

extension CallContainerModel:RTVIClientDelegate, LLMHelperDelegate {

    private func handleEvent(eventName: String, eventValue: Any? = nil) {
        if let value = eventValue {
            print("Pipecat Demo, received event: \(eventName), value:\(value)")
        } else {
            print("Pipecat Demo, received event: \(eventName)")
        }
    }

    func onTransportStateChanged(state: TransportState) {
        Task { @MainActor in
            self.handleEvent(eventName: "onTransportStateChanged", eventValue: state)
            self.voiceClientStatus = state.description
            self.isInCall = ( state == .connecting || state == .connected || state == .ready || state == .authenticating )
            self.createLiveMessage(content: state.description, type: .system)
        }
    }

    func onBotReady(botReadyData: BotReadyData) {
        Task { @MainActor in
            self.handleEvent(eventName: "onBotReady")
            self.isBotReady = true
        }
    }

    func onConnected() {
        Task { @MainActor in
            self.handleEvent(eventName: "onConnected")
            self.isMicEnabled = self.rtviClientIOS?.isMicEnabled ?? false
        }
    }

    func onDisconnected() {
        Task { @MainActor in
            self.handleEvent(eventName: "onDisconnected")
            self.isBotReady = false
        }
    }

    func onError(message: String) {
        Task { @MainActor in
            self.handleEvent(eventName: "onError", eventValue: message)
            self.showError(message: message)
        }
    }

    func onAvailableMicsUpdated(mics: [MediaDeviceInfo]) {
        Task { @MainActor in
            self.availableMics = mics
        }
    }

    func onMicUpdated(mic: MediaDeviceInfo?) {
        Task { @MainActor in
            self.selectedMic = mic?.id
        }
    }
    
    func onBotTranscript(data: String) {
        self.handleEvent(eventName: "onBotTranscript", eventValue: data)
    }
    
    func onTracksUpdated(tracks: Tracks) {
        self.handleEvent(eventName: "onTracksUpdated", eventValue: tracks)
    }

    func onUserStartedSpeaking() {
        self.createLiveMessage(content: "User started speaking", type: .system)
        self.handleEvent(eventName: "onUserStartedSpeaking")
        self.createLiveMessage(type: .user)
    }

    func onUserStoppedSpeaking() {
        self.createLiveMessage(content: "User stopped speaking", type: .system)
        self.handleEvent(eventName: "onUserStoppedSpeaking")
    }

    func onBotStartedSpeaking(participant: Participant) {
        self.createLiveMessage(content: "Bot started speaking", type: .system)
        self.handleEvent(eventName: "onBotStartedSpeaking")
        self.createLiveMessage(type: .bot)
    }

    func onBotStoppedSpeaking(participant: Participant) {
        self.createLiveMessage(content: "Bot stopped speaking", type: .system)
        self.handleEvent(eventName: "onBotStoppedSpeaking")
    }
    
    func onUserTranscript(data: Transcript) {
        if data.final ?? false {
            self.handleEvent(eventName: "onUserTranscript", eventValue: data.text)
            self.appendTextToLiveMessage(fromBot: false, content: data.text)
        }
    }
    
    func onBotTTSText(data: BotTTSText) {
        self.appendTextToLiveMessage(fromBot: true, content: data.text)
    }
    
    func onLLMFunctionCall(functionCallData: LLMFunctionCallData, onResult: ((Value) async -> Void)) async {
        self.handleEvent(eventName: "onLLMFunctionCall", eventValue: functionCallData)
        if let receivedFunction = ToolsFunctions(rawValue: functionCallData.functionName) {
            switch receivedFunction {
            case .endBot:
                await self.disconnect()
                return await onResult(Value.object([:]))

            case .blockApps:
                await MainActor.run {
                    guard let screenTimeManager = self.screenTimeManager,
                          let appBlockingState = self.appBlockingState else {
                        return
                    }
                    screenTimeManager.blockApps(selection: appBlockingState.selection)
                }
                let result = Value.object([
                    "success": .boolean(true),
                    "message": .string("Apps have been blocked successfully.")
                ])
                return await onResult(result)

            case .unblockApps:
                await MainActor.run {
                    self.screenTimeManager?.unblockAllApps()
                }
                let result = Value.object([
                    "success": .boolean(true),
                    "message": .string("All apps have been unblocked.")
                ])
                return await onResult(result)

            case .getBlockStatus:
                var statusMessage = "Unable to get status"
                await MainActor.run {
                    if let screenTimeManager = self.screenTimeManager,
                       let appBlockingState = self.appBlockingState {
                        statusMessage = screenTimeManager.getBlockStatus(selection: appBlockingState.selection)
                    }
                }
                let result = Value.object([
                    "status": .string(statusMessage)
                ])
                return await onResult(result)
            }
        }
        await onResult(Value.object(["success": .boolean(false)]))
    }

}
