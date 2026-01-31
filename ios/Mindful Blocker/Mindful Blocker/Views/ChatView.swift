//
//  ChatView.swift
//  Mindful Blocker
//

import SwiftUI
import RealtimeAPI

struct ChatView: View {
    var screenTimeManager: ScreenTimeManager
    var appBlockingState: AppBlockingState

    @State private var conversation = Conversation()
    @State private var inputText = ""
    @State private var isConnecting = false
    @State private var connectionError: String?
    @State private var showingAppPicker = false
    @State private var showingSettings = false
    @State private var processedFunctionCallIds = Set<String>()

    private let ephemeralKeyService = EphemeralKeyService()

    private var toolHandler: ToolHandler {
        ToolHandler(screenTimeManager: screenTimeManager, appBlockingState: appBlockingState)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isConnecting {
                    ProgressView("Connecting...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = connectionError {
                    VStack(spacing: 16) {
                        Text("Connection Error")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await connect() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    messagesScrollView
                    inputBar
                }
            }
            .navigationTitle("Mindful Blocker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAppPicker = true
                    } label: {
                        Image(systemName: "apps.iphone")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingAppPicker) {
                AppPickerSheet(appBlockingState: appBlockingState)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(screenTimeManager: screenTimeManager)
            }
            .task {
                await connect()
            }
            .onChange(of: conversation.entries) { _, entries in
                handleFunctionCalls(entries: entries)
            }
        }
    }

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(conversation.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: conversation.messages.count) { _, _ in
                if let lastMessage = conversation.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Message...", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    sendMessage()
                }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            VoiceModeButton(
                isActive: !conversation.muted,
                isUserSpeaking: conversation.isUserSpeaking,
                isModelSpeaking: conversation.isModelSpeaking
            ) {
                conversation.muted.toggle()
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private func connect() async {
        isConnecting = true
        connectionError = nil

        do {
            let ephemeralKey = try await ephemeralKeyService.fetchEphemeralKey()
            try await conversation.connect(ephemeralKey: ephemeralKey)

            try await conversation.whenConnected {
                try conversation.updateSession { session in
                    session.instructions = """
                    You are a mindful assistant helping users manage their screen time and app usage.
                    You can help users block and unblock apps on their device.
                    Be supportive, encouraging, and help them maintain healthy digital habits.
                    When users want to limit their app usage, use the block_apps tool.
                    When users want to remove restrictions, use the unblock_apps tool.
                    You can check the current blocking status with get_block_status.
                    """
                    session.tools = BlockingTools.allTools
                }
            }

            isConnecting = false
        } catch {
            isConnecting = false
            connectionError = error.localizedDescription
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""

        do {
            try conversation.send(from: .user, text: text)
        } catch {
            print("Failed to send message: \(error)")
        }
    }

    private func handleFunctionCalls(entries: [Item]) {
        for entry in entries {
            guard case let .functionCall(functionCall) = entry,
                  functionCall.status == .completed,
                  !processedFunctionCallIds.contains(functionCall.callId) else {
                continue
            }

            processedFunctionCallIds.insert(functionCall.callId)

            let result = toolHandler.execute(
                functionName: functionCall.name,
                arguments: functionCall.arguments
            )

            do {
                let output = Item.FunctionCallOutput(
                    id: UUID().uuidString,
                    callId: functionCall.callId,
                    output: result
                )
                try conversation.send(result: output)
                try conversation.send(event: .createResponse())
            } catch {
                print("Failed to send function result: \(error)")
            }
        }
    }
}
