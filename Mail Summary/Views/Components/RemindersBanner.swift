//
//  RemindersBanner.swift
//  Mail Summary
//
//  Banner showing active email reminders
//  Created by Jordan Koch on 2026-01-23
//

import SwiftUI

struct RemindersBanner: View {
    let reminders: [EmailReminder]
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 8) {
            // Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .foregroundColor(.yellow)

                    Text("ACTIVE REMINDERS")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("(\(reminders.count))")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.yellow)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.yellow.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.yellow, lineWidth: 2)
                        )
                )
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(reminders) { reminder in
                        ReminderRow(reminder: reminder)
                    }
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

/// Individual reminder row
private struct ReminderRow: View {
    let reminder: EmailReminder

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: reminder.reminderType.icon)
                .foregroundColor(.yellow)

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.emailSubject)
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let note = reminder.note {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.yellow)

                    Text(formatReminderTime(reminder.remindAt))
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
            }

            Spacer()

            // Complete button
            Button(action: {
                SnoozeReminderManager.shared.completeReminder(reminder.id)
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            .buttonStyle(.plain)

            // Delete button
            Button(action: {
                SnoozeReminderManager.shared.deleteReminder(reminder.id)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func formatReminderTime(_ date: Date) -> String {
        if date < Date() {
            return "Now!"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
