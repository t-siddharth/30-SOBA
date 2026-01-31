//
//  AppBlockingState.swift
//  Mindful Blocker
//

import Foundation
import FamilyControls

@Observable
final class AppBlockingState {
    private static let selectionKey = "FamilyActivitySelection"

    var selection: FamilyActivitySelection {
        didSet {
            save()
        }
    }

    init() {
        self.selection = Self.load()
    }

    private static func load() -> FamilyActivitySelection {
        guard let data = UserDefaults.standard.data(forKey: selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return selection
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        UserDefaults.standard.set(data, forKey: Self.selectionKey)
    }
}
