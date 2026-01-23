//
//  ActionButtonRow.swift
//  Mail Summary
//
//  Reusable action button row for email operations
//  Created by Jordan Koch on 2026-01-23
//

import SwiftUI

struct ActionButtonRow: View {
    let email: Email
    let onDelete: () -> Void
    let onArchive: () -> Void
    let onMarkRead: () -> Void
    let onReply: () -> Void
    let onForward: () -> Void
    let onSnooze: () -> Void
    let onRemind: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ActionButton(
                icon: "trash.fill",
                label: "Delete",
                color: .red,
                action: onDelete
            )

            ActionButton(
                icon: "archivebox.fill",
                label: "Archive",
                color: .orange,
                action: onArchive
            )

            ActionButton(
                icon: email.isRead ? "envelope.badge.fill" : "envelope.open.fill",
                label: email.isRead ? "Mark Unread" : "Mark Read",
                color: .blue,
                action: onMarkRead
            )

            ActionButton(
                icon: "arrowshape.turn.up.left.fill",
                label: "Reply",
                color: .green,
                action: onReply
            )

            ActionButton(
                icon: "arrowshape.turn.up.right.fill",
                label: "Forward",
                color: .cyan,
                action: onForward
            )

            ActionButton(
                icon: "clock.fill",
                label: "Snooze",
                color: .purple,
                action: onSnooze
            )

            ActionButton(
                icon: "bell.fill",
                label: "Remind",
                color: .yellow,
                action: onRemind
            )
        }
        .padding(.horizontal)
    }
}

/// Individual action button
private struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(color.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ActionButtonRow(
        email: Email(
            id: 1,
            messageId: "test",
            subject: "Test",
            sender: "Test",
            senderEmail: "test@test.com",
            dateReceived: Date(),
            body: "Test body",
            isRead: false,
            category: .work,
            priority: 5,
            aiSummary: nil,
            actions: [],
            senderReputation: nil
        ),
        onDelete: {},
        onArchive: {},
        onMarkRead: {},
        onReply: {},
        onForward: {},
        onSnooze: {},
        onRemind: {}
    )
    .padding()
    .background(Color.black)
}
