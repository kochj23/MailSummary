//
//  EmailDetailView.swift
//  Mail Summary
//
//  Full email viewer with HTML rendering and actions
//  Created by Jordan Koch on 2026-01-23
//

import SwiftUI

struct EmailDetailView: View {
    let email: Email
    @ObservedObject var mailEngine: MailEngine
    @Environment(\.dismiss) var dismiss

    @State private var showingSnooze = false
    @State private var showingReminder = false
    @State private var isPerformingAction = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .background(Color.cyan)
                .frame(height: 2)

            // Action buttons
            if !isPerformingAction {
                ActionButtonRow(
                    email: email,
                    onDelete: { performAction(.delete) },
                    onArchive: { performAction(.archive) },
                    onMarkRead: { performAction(.toggleRead) },
                    onReply: { performAction(.reply) },
                    onForward: { performAction(.forward) },
                    onSnooze: { showingSnooze = true },
                    onRemind: { showingReminder = true }
                )
                .padding(.vertical, 12)
            } else {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                    Text("Performing action...")
                        .foregroundColor(.gray)
                }
                .padding()
            }

            Divider()

            // Email body
            bodyView

            Divider()

            // Footer with metadata and AI info
            footerView
        }
        .frame(width: 900, height: 700)
        .background(Color.black)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cyan, lineWidth: 3)
        )
        .sheet(isPresented: $showingSnooze) {
            SnoozePickerView(email: email, mailEngine: mailEngine)
        }
        .sheet(isPresented: $showingReminder) {
            ReminderFormView(email: email, mailEngine: mailEngine)
        }
        .onAppear {
            // Load body if not already loaded
            if email.body == nil {
                Task {
                    await mailEngine.loadEmailBody(emailID: email.id)
                }
            }
        }
    }

    // MARK: - Sub Views

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: Priority and close button
            HStack {
                if let priority = email.priority {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(priorityColor(priority))
                        Text("Priority: \(priority)")
                            .font(.caption)
                            .foregroundColor(priorityColor(priority))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(priorityColor(priority).opacity(0.2))
                    )
                }

                if let category = email.category {
                    HStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .foregroundColor(categoryColor(category))
                        Text(category.rawValue)
                            .font(.caption)
                            .foregroundColor(categoryColor(category))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(categoryColor(category).opacity(0.2))
                    )
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }

            // Subject
            Text(email.subject)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            // Sender and date
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("From:")
                            .foregroundColor(.gray)
                        Text(email.sender)
                            .foregroundColor(.cyan)
                    }
                    .font(.body)

                    Text(email.senderEmail)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatFullDate(email.dateReceived))
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text(formatRelativeDate(email.dateReceived))
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
                }
            }

            // Read status
            if email.isRead {
                HStack(spacing: 4) {
                    Image(systemName: "envelope.open.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("Read")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "envelope.badge.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text("Unread")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color.black)
    }

    private var bodyView: some View {
        Group {
            if let body = email.body {
                // Check if it's HTML
                if body.contains("<html") || body.contains("<body") || body.contains("<div") {
                    HTMLContentView(html: body)
                } else {
                    // Plain text
                    ScrollView {
                        Text(body)
                            .font(.body)
                            .foregroundColor(.white)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else if email.isLoadingBody {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))

                    Text("Loading email body...")
                        .foregroundColor(.gray)
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "envelope")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)

                    Button("Load Email Body") {
                        Task {
                            await mailEngine.loadEmailBody(emailID: email.id)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .background(Color.black)
    }

    private var footerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // AI Summary
            if let summary = email.aiSummary {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.cyan)

                    Text("AI Summary:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Text(summary)
                        .font(.caption)
                        .foregroundColor(.cyan.opacity(0.8))
                }
            }

            // Action items
            if !email.actions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "checklist")
                            .foregroundColor(.orange)

                        Text("Action Items:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }

                    ForEach(email.actions) { action in
                        HStack(spacing: 6) {
                            Image(systemName: actionIcon(action.type))
                                .font(.caption2)
                                .foregroundColor(.orange)

                            Text(action.text)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))

                            if let date = action.date {
                                Text("(\(formatActionDate(date)))")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }

            // Sender reputation
            if let reputation = email.senderReputation {
                HStack(spacing: 4) {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(reputationColor(reputation))

                    Text("Sender Trust:")
                        .font(.caption2)
                        .foregroundColor(.white)

                    Text(reputationLabel(reputation))
                        .font(.caption2)
                        .foregroundColor(reputationColor(reputation))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
    }

    // MARK: - Actions

    private func performAction(_ action: EmailActionType) {
        isPerformingAction = true

        Task {
            await mailEngine.performEmailAction(action, on: email)

            // Close detail view after successful action (except mark read/unread)
            await MainActor.run {
                isPerformingAction = false

                if case .delete = action { dismiss() }
                else if case .archive = action { dismiss() }
            }
        }
    }

    // MARK: - Utilities

    private func priorityColor(_ priority: Int) -> Color {
        if priority >= 9 { return .red }
        if priority >= 7 { return .orange }
        if priority >= 5 { return .yellow }
        return .green
    }

    private func categoryColor(_ category: Email.EmailCategory) -> Color {
        switch category {
        case .bills: return .red
        case .orders: return .green
        case .work: return .blue
        case .personal: return .cyan
        case .marketing: return .orange
        case .newsletters: return .purple
        case .social: return .pink
        case .spam: return .gray
        case .other: return .yellow
        }
    }

    private func reputationColor(_ reputation: Double) -> Color {
        if reputation >= 0.8 { return .green }
        if reputation >= 0.5 { return .yellow }
        return .red
    }

    private func reputationLabel(_ reputation: Double) -> String {
        if reputation >= 0.8 { return "Trusted (\(Int(reputation * 100))%)" }
        if reputation >= 0.5 { return "Unknown (\(Int(reputation * 100))%)" }
        return "Suspicious (\(Int(reputation * 100))%)"
    }

    private func actionIcon(_ type: EmailAction.ActionType) -> String {
        switch type {
        case .deadline: return "clock.badge.exclamationmark"
        case .meeting: return "calendar"
        case .task: return "checklist"
        case .reminder: return "bell"
        }
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatActionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
