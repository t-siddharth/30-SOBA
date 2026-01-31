//
//  VoiceModeButton.swift
//  Mindful Blocker
//

import SwiftUI

struct VoiceModeButton: View {
    let isActive: Bool
    let isUserSpeaking: Bool
    let isModelSpeaking: Bool
    let action: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    private var shouldPulse: Bool {
        isActive && (isUserSpeaking || isModelSpeaking)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.red : Color(.systemGray4))
                    .frame(width: 56, height: 56)
                    .scaleEffect(pulseScale)

                Image(systemName: isActive ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
        }
        .onChange(of: shouldPulse) { _, newValue in
            withAnimation(newValue ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true) : .default) {
                pulseScale = newValue ? 1.1 : 1.0
            }
        }
    }
}
