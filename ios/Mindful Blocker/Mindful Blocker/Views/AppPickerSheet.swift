//
//  AppPickerSheet.swift
//  Mindful Blocker
//

import SwiftUI
import FamilyControls

struct AppPickerSheet: View {
    @Bindable var appBlockingState: AppBlockingState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $appBlockingState.selection)
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
