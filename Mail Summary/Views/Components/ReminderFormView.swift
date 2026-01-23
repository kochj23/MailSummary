//
//  ReminderFormView.swift
//  Mail Summary
//
//  Form for creating email reminders
//  Created by Jordan Koch on 2026-01-23
//

import SwiftUI

struct ReminderFormView: View {
    let email: Email
    @ObservedObject var mailEngine: MailEngine
    @Environment(\.dismiss) var dismiss

    @State private var reminderDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
    @State private var reminderType: EmailReminder.ReminderType = .followUp
    @State private var note: String = ""

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "bell.fill")
                    .font(.title)
                    .foregroundColor(.yellow)

                Text("Set Reminder")
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
                .background(Color.yellow)

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

            // Reminder type picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Reminder Type")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    ForEach(EmailReminder.ReminderType.allCases, id: \.self) { type in
                        Button(action: { reminderType = type }) {
                            VStack(spacing: 4) {
                                Image(systemName: type.icon)
                                    .font(.title3)
                                Text(type.rawValue)
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(reminderType == type ? Color.yellow.opacity(0.2) : Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(reminderType == type ? Color.yellow : Color.gray.opacity(0.3), lineWidth: reminderType == type ? 2 : 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Date picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Remind Me At")
                    .font(.headline)
                    .foregroundColor(.white)

                DatePicker(
                    "Reminder time",
                    selection: $reminderDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .colorScheme(.dark)
            }

            // Optional note
            VStack(alignment: .leading, spacing: 8) {
                Text("Note (Optional)")
                    .font(.headline)
                    .foregroundColor(.white)

                TextField("Add a note about this reminder", text: $note)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)
                    .foregroundColor(.white)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Set Reminder") {
                    setReminder()
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
            }
        }
        .padding(20)
        .frame(width: 450, height: 750)
        .background(Color.black)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow, lineWidth: 2)
        )
    }

    private func setReminder() {
        SnoozeReminderManager.shared.addReminder(
            emailId: email.id,
            messageId: email.messageId,
            subject: email.subject,
            remindAt: reminderDate,
            note: note.isEmpty ? nil : note,
            type: reminderType
        )

        // Update email in MailEngine
        mailEngine.markEmailAsHasReminder(emailId: email.id, remindAt: reminderDate)

        dismiss()
    }
}
