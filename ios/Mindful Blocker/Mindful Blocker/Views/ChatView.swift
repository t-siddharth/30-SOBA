//
//  ChatView.swift
//  Mindful Blocker
//

import SwiftUI
import RealtimeAPI

// Debug: Intercept all URL requests to log OpenAI responses
class DebugURLProtocol: URLProtocol {
    static var isRegistered = false
    static let handledKey = "DebugURLProtocolHandled"

    // Use a session without the protocol to avoid infinite loop
    static let plainSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config)
    }()

    static func register() {
        guard !isRegistered else { return }
        URLProtocol.registerClass(DebugURLProtocol.self)
        isRegistered = true
    }

    override class func canInit(with request: URLRequest) -> Bool {
        // Skip if already handled
        if URLProtocol.property(forKey: handledKey, in: request) != nil {
            return false
        }
        // Only intercept OpenAI realtime calls
        return request.url?.host == "api.openai.com" && request.url?.path.contains("realtime") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        print("[DEBUG URLProtocol] Intercepted request to: \(request.url?.absoluteString ?? "nil")")
        if let body = request.httpBody, let bodyStr = String(data: body, encoding: .utf8) {
            print("[DEBUG URLProtocol] Request body (first 500 chars): \(String(bodyStr.prefix(500)))")
        }

        // Mark as handled
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)

        let task = Self.plainSession.dataTask(with: mutableRequest as URLRequest) { data, response, error in
            if let error = error {
                print("[DEBUG URLProtocol] Error: \(error)")
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("[DEBUG URLProtocol] Response status: \(httpResponse.statusCode)")
            }

            if let data = data, let bodyStr = String(data: data, encoding: .utf8) {
                print("[DEBUG URLProtocol] Response body: \(bodyStr)")
            }

            if let response = response {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data = data {
                self.client?.urlProtocol(self, didLoad: data)
            }
            self.client?.urlProtocolDidFinishLoading(self)
        }
        task.resume()
    }

    override func stopLoading() {}
}

struct ChatView: View {
    var screenTimeManager: ScreenTimeManager
    var appBlockingState: AppBlockingState

    @State private var conversation = Conversation(debug: true)
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
            // Register debug interceptor to log all OpenAI requests/responses
            DebugURLProtocol.register()

            print("[ChatView] Fetching ephemeral key...")
            let ephemeralKey = try await ephemeralKeyService.fetchEphemeralKey()
            print("[ChatView] Got ephemeral key, connecting to OpenAI...")

            // Model must match what the server uses when creating the ephemeral key
            try await conversation.connect(ephemeralKey: ephemeralKey, model: .custom("gpt-4o-realtime-preview"))
            print("[ChatView] Connected, waiting for session...")

            try await conversation.whenConnected {
                print("[ChatView] Session ready, updating configuration...")
                try await conversation.updateSession { session in
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

            print("[ChatView] Successfully connected and configured!")
            isConnecting = false
        } catch {
            isConnecting = false
            print("[ChatView] Connection error: \(error)")
            print("[ChatView] Error type: \(type(of: error))")
            if let underlyingError = (error as NSError).userInfo[NSUnderlyingErrorKey] as? Error {
                print("[ChatView] Underlying error: \(underlyingError)")
            }
            connectionError = String(describing: error)
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
