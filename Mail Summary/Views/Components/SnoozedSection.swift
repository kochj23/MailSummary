//
//  SnoozedSection.swift
//  Mail Summary
//
//  Collapsible section showing snoozed emails
//  Created by Jordan Koch on 2026-01-23
//

import SwiftUI

struct SnoozedSection: View {
    let snoozedEmails: [SnoozedEmail]
    @ObservedObject var mailEngine: MailEngine
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.purple)

                    Text("SNOOZED")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("(\(snoozedEmails.count))")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.purple)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.purple.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.purple, lineWidth: 2)
                        )
                )
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(snoozedEmails) { snoozed in
                        SnoozedEmailRow(snoozed: snoozed, mailEngine: mailEngine)
                    }
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

/// Individual snoozed email row
private struct SnoozedEmailRow: View {
    let snoozed: SnoozedEmail
    @ObservedObject var mailEngine: MailEngine

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snoozed.emailSubject)
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("From: \(snoozed.senderEmail)")
                    .font(.caption)
                    .foregroundColor(.gray)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.purple)

                    Text("Until \(formatSnoozeTime(snoozed.snoozeUntil))")
                        .font(.caption2)
                        .foregroundColor(.purple)
                }
            }

            Spacer()

            // Unsnooze button
            Button(action: {
                SnoozeReminderManager.shared.unsnooze(emailId: snoozed.emailId)
                mailEngine.unsnoozeEmail(emailId: snoozed.emailId)
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
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func formatSnoozeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
