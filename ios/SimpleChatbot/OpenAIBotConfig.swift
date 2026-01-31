import Foundation
import PipecatClientIOS
import PipecatClientIOSOpenAIRealtimeWebrtc

public enum ToolsFunctions: String {
    case endBot = "end_bot"
    case blockApps = "block_apps"
    case unblockApps = "unblock_apps"
    case getBlockStatus = "get_block_status"
}

class OpenAIBotConfig {

    static let endBotTool = OpenAIFunctionTool.init(
        name: ToolsFunctions.endBot.rawValue,
        description: "Invoke this function when the user indicates that the conversation has ended and no further assistance is needed.",
        parameters: nil
    )

    static let blockAppsTool = OpenAIFunctionTool.init(
        name: ToolsFunctions.blockApps.rawValue,
        description: "Block the user's selected apps using Screen Time. Call this when the user wants to limit their app usage, focus, or block distracting apps.",
        parameters: nil
    )

    static let unblockAppsTool = OpenAIFunctionTool.init(
        name: ToolsFunctions.unblockApps.rawValue,
        description: "Unblock all apps, removing all Screen Time restrictions. Call this when the user wants to remove blocks or access their apps again.",
        parameters: nil
    )

    static let getBlockStatusTool = OpenAIFunctionTool.init(
        name: ToolsFunctions.getBlockStatus.rawValue,
        description: "Get the current app blocking status - whether blocking is active and how many apps are selected/blocked.",
        parameters: nil
    )
    
    static func createOptions(openaiAPIKey: String) -> RTVIClientOptions {
        var tools: [Value?] = []
        do {
            tools.append(try endBotTool.convertToRtviValue())
            tools.append(try blockAppsTool.convertToRtviValue())
            tools.append(try unblockAppsTool.convertToRtviValue())
            tools.append(try getBlockStatusTool.convertToRtviValue())
        } catch {
            print("[OpenAIBotConfig] Failed to convert tools: \(error)")
        }

        let currentSettings = SettingsManager.getSettings()
        let rtviClientOptions = RTVIClientOptions.init(
            enableMic: currentSettings.enableMic,
            enableCam: false,
            params: .init(config: [
                .init(
                    service: "llm",
                    options: [
                        .init(name: "api_key", value: .string(openaiAPIKey)),
                        .init(name: "initial_messages", value: .array([
                            .object([
                                "role": .string("user"),
                                "content": .string("Start by introducing yourself.")
                            ])
                        ])),
                        .init(name: "session_config", value: .object([
                            "instructions": .string("""
                                You are a mindful assistant helping users manage their screen time and app usage.
                                You can help users block and unblock apps on their device using Screen Time.
                                Be supportive, encouraging, and help them maintain healthy digital habits.
                                When users want to limit their app usage or focus, use the block_apps tool.
                                When users want to remove restrictions, use the unblock_apps tool.
                                You can check the current blocking status with get_block_status.
                                If no apps are selected yet, remind the user to tap the apps button to select which apps to block.
                                """),
                            "voice": .string("verse"),
                            "input_audio_noise_reduction": .object([
                                "type": .string("near_field")
                            ]),
                            "turn_detection": .object([
                                "type": .string("semantic_vad")
                            ]),
                            "tools": .array(tools)
                        ])),
                    ]
                )
            ])
        )
        return rtviClientOptions
    }
    
}
