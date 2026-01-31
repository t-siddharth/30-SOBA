//
//  MessageBubbleView.swift
//  Mindful Blocker
//

import SwiftUI
import RealtimeAPI

struct MessageBubbleView: View {
    let message: Item.Message

    private var isUser: Bool {
        message.role == .user
    }

    private var messageText: String {
        message.content.compactMap { $0.text }.joined()
    }

    var body: some View {
        HStack {
            if isUser { Spacer() }

            Text(messageText.isEmpty ? "..." : messageText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            if !isUser { Spacer() }
        }
        .padding(.horizontal)
    }
}
