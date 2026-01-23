//
//  SnoozePickerView.swift
//  Mail Summary
//
//  Time picker for snoozing emails
//  Created by Jordan Koch on 2026-01-23
//

import SwiftUI

struct SnoozePickerView: View {
    let email: Email
    @ObservedObject var mailEngine: MailEngine
    @Environment(\.dismiss) var dismiss

    @State private var showCustomPicker = false
    @State private var customDate = Date().addingTimeInterval(3600)  // Default: 1 hour from now

    let presets: [(String, TimeInterval?)] = [
        ("1 Hour", 3600),
        ("3 Hours", 10800),
        ("Tomorrow Morning", nil),  // Calculated
        ("Tomorrow Evening", nil),  // Calculated
        ("This Weekend", nil),      // Calculated
        ("Next Week", 604800),
        ("Custom...", nil)
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "clock.fill")
                    .font(.title)
                    .foregroundColor(.purple)

                Text("Snooze Email")
                    .font(.title2)
                    .foregroundColor(.white)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }

            Divider()
                .background(Color.purple)

            // Email preview
            VStack(alignment: .leading, spacing: 4) {
                Text(email.subject)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text("From: \(email.sender)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)

            Divider()

            // Preset buttons
            VStack(spacing: 8) {
                ForEach(presets, id: \.0) { preset in
                    Button(action: {
                        if preset.0 == "Custom..." {
                            showCustomPicker.toggle()
                        } else {
                            let snoozeDate = calculateDate(for: preset)
                            snoozeEmail(until: snoozeDate)
                        }
                    }) {
                        HStack {
                            Text(preset.0)
                                .foregroundColor(.white)

                            Spacer()

                            if let interval = preset.1, preset.0 != "Custom..." {
                                Text(formatInterval(interval))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else if preset.0 != "Custom..." {
                                Text(describePreset(preset.0))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.purple)
                            }
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
                    .buttonStyle(.plain)
                }
            }

            // Custom date picker
            if showCustomPicker {
                VStack(spacing: 12) {
                    Divider()

                    Text("Select custom time")
                        .font(.headline)
                        .foregroundColor(.purple)

                    DatePicker(
                        "Snooze until",
                        selection: $customDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .colorScheme(.dark)

                    Button("Snooze") {
                        snoozeEmail(until: customDate)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 450, height: showCustomPicker ? 700 : 520)
        .background(Color.black)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple, lineWidth: 2)
        )
    }

    // MARK: - Actions

    private func snoozeEmail(until date: Date) {
        SnoozeReminderManager.shared.snoozeEmail(
            emailId: email.id,
            messageId: email.messageId,
            subject: email.subject,
            sender: email.senderEmail,
            until: date
        )

        // Update email in MailEngine
        mailEngine.markEmailAsSnoozed(emailId: email.id, until: date)

        dismiss()
    }

    // MARK: - Utilities

    private func calculateDate(for preset: (String, TimeInterval?)) -> Date {
        let calendar = Calendar.current
        let now = Date()

        switch preset.0 {
        case "Tomorrow Morning":
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!

        case "Tomorrow Evening":
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow)!

        case "This Weekend":
            // Next Saturday at 9am
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            components.weekday = 7  // Saturday
            components.hour = 9
            components.minute = 0
            let saturday = calendar.date(from: components)!
            return saturday > now ? saturday : calendar.date(byAdding: .weekOfYear, value: 1, to: saturday)!

        default:
            if let interval = preset.1 {
                return now.addingTimeInterval(interval)
            }
            return now
        }
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        if hours < 24 {
            return "\(hours)h from now"
        } else {
            let days = hours / 24
            return "\(days)d from now"
        }
    }

    private func describePreset(_ name: String) -> String {
        let date = calculateDate(for: (name, nil))
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
