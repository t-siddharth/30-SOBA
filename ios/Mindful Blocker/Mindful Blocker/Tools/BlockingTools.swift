//
//  BlockingTools.swift
//  Mindful Blocker
//

import Foundation
import RealtimeAPI

enum BlockingTools {
    static let blockApps = Tool.function(Tool.Function(
        name: "block_apps",
        description: "Block the user's selected apps. This will prevent access to apps that the user has chosen to limit.",
        parameters: .object(properties: [:])
    ))

    static let unblockApps = Tool.function(Tool.Function(
        name: "unblock_apps",
        description: "Remove all app blocks. This will restore access to all previously blocked apps.",
        parameters: .object(properties: [:])
    ))

    static let getBlockStatus = Tool.function(Tool.Function(
        name: "get_block_status",
        description: "Check the current app blocking status. Returns whether blocking is active and how many apps are selected.",
        parameters: .object(properties: [:])
    ))

    static var allTools: [Tool] {
        [blockApps, unblockApps, getBlockStatus]
    }
}

@MainActor
class ToolHandler {
    private let screenTimeManager: ScreenTimeManager
    private let appBlockingState: AppBlockingState

    init(screenTimeManager: ScreenTimeManager, appBlockingState: AppBlockingState) {
        self.screenTimeManager = screenTimeManager
        self.appBlockingState = appBlockingState
    }

    func execute(functionName: String, arguments: String) -> String {
        switch functionName {
        case "block_apps":
            return executeBlockApps()
        case "unblock_apps":
            return executeUnblockApps()
        case "get_block_status":
            return executeGetBlockStatus()
        default:
            return "{\"error\": \"Unknown function: \(functionName)\"}"
        }
    }

    private func executeBlockApps() -> String {
        let selection = appBlockingState.selection
        let appCount = selection.applicationTokens.count
        let categoryCount = selection.categoryTokens.count

        if appCount == 0 && categoryCount == 0 {
            return "{\"success\": false, \"message\": \"No apps selected. Please select apps to block first using the app picker.\"}"
        }

        screenTimeManager.blockApps(selection: selection)
        return "{\"success\": true, \"message\": \"Blocked \(appCount) apps and \(categoryCount) categories.\"}"
    }

    private func executeUnblockApps() -> String {
        screenTimeManager.unblockAllApps()
        return "{\"success\": true, \"message\": \"All app blocks have been removed.\"}"
    }

    private func executeGetBlockStatus() -> String {
        let isActive = screenTimeManager.isBlockingActive
        let appCount = appBlockingState.selection.applicationTokens.count
        let categoryCount = appBlockingState.selection.categoryTokens.count

        return """
        {
            "blocking_active": \(isActive),
            "selected_apps": \(appCount),
            "selected_categories": \(categoryCount)
        }
        """
    }
}
