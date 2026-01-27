//
//  ThreadedEmailListView.swift
//  Mail Summary
//
//  Thread View - Conversation Display
//  Created by Jordan Koch on 2026-01-26
//
//  Displays emails grouped into conversation threads.
//

import SwiftUI

struct ThreadedEmailListView: View {
    @ObservedObject var threadManager = ThreadManager.shared
    @ObservedObject var mailEngine: MailEngine
    @State private var expandedThreads: Set<UUID> = []
    @State private var selectedEmail: Email?
    @Environment(\.dismiss) var dismiss

    let category: Email.EmailCategory?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Thread List
            if threadManager.threads.isEmpty {
                emptyStateView
            } else {
                threadListView
            }
        }
        .frame(width: 900, height: 700)
        .background(Color.black)
        .sheet(item: $selectedEmail) { email in
            EmailDetailView(email: email, mailEngine: mailEngine)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let category = category {
                    let catColor: Color = {
                        switch category.color.lowercased() {
                        case "red": return .red
                        case "green": return .green
                        case "blue": return .blue
                        case "cyan": return .cyan
                        case "orange": return .orange
                        case "purple": return .purple
                        case "pink": return .pink
                        case "gray": return .gray
                        case "yellow": return .yellow
                        default: return .primary
                        }
                    }()
                    HStack(spacing: 8) {
                        Image(systemName: category.icon)
                            .foregroundColor(catColor)
                        Text("\(category.rawValue) Threads")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                } else {
                    Text("🧵 All Threads")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                let stats = threadManager.getThreadStatistics()
                Text("\(stats.totalThreads) threads • Avg \(String(format: "%.1f", stats.avgMessagesPerThread)) msgs/thread")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            // View mode toggle
            Button(action: { dismiss() }) {
                Label("List View", systemImage: "list.bullet")
            }
            .buttonStyle(.bordered)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundColor(.gray)
            .keyboardShortcut(.escape)
        }
        .padding()
    }

    // MARK: - Thread List

    private var threadListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredThreads) { thread in
                    ThreadCard(
                        thread: thread,
                        isExpanded: expandedThreads.contains(thread.id),
                        onToggle: {
                            if expandedThreads.contains(thread.id) {
                                expandedThreads.remove(thread.id)
                            } else {
                                expandedThreads.insert(thread.id)
                            }
                        },
                        onEmailTap: { email in
                            selectedEmail = email
                        },
                        onArchiveThread: {
                            Task {
                                let emailIDs = thread.emails.map { $0.id }
                                await mailEngine.bulkArchive(emailIDs: emailIDs)
                            }
                        },
                        onDeleteThread: {
                            Task {
                                let emailIDs = thread.emails.map { $0.id }
                                await mailEngine.bulkDelete(emailIDs: emailIDs)
                            }
                        },
                        onMarkThreadRead: {
                            Task {
                                let emailIDs = thread.emails.map { $0.id }
                                await mailEngine.bulkMarkRead(emailIDs: emailIDs)
                            }
                        }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Threads")
                .font(.title)
                .foregroundColor(.white)

            Text("Emails will be grouped into conversation threads")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Filtered Threads

    private var filteredThreads: [EmailThread] {
        guard let category = category else {
            return threadManager.threads
        }

        return threadManager.threads.filter { thread in
            thread.emails.contains { $0.category == category }
        }
    }
}

// MARK: - Thread Card

struct ThreadCard: View {
    let thread: EmailThread
    let isExpanded: Bool
    let onToggle: () -> Void
    let onEmailTap: (Email) -> Void
    let onArchiveThread: () -> Void
    let onDeleteThread: () -> Void
    let onMarkThreadRead: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thread Header
            threadHeaderView

            // Expanded emails
            if isExpanded {
                Divider()
                    .padding(.vertical, 8)

                ForEach(thread.emails) { email in
                    ThreadEmailRow(email: email, onTap: {
                        onEmailTap(email)
                    })
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(thread.hasHighPriority ? Color.red : Color.clear, lineWidth: 2)
        )
    }

    private var threadHeaderView: some View {
        HStack(alignment: .top, spacing: 12) {
            // Expand/collapse button
            Button(action: onToggle) {
                Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                    .font(.title3)
                    .foregroundColor(.cyan)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                // Subject
                Text(thread.subject)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)

                // Thread info
                HStack(spacing: 12) {
                    Label("\(thread.messageCount) messages", systemImage: "bubble.left.and.bubble.right")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Label("\(thread.participants.count) participants", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Label(thread.timespanDisplay, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.gray)

                    if thread.unreadCount > 0 {
                        Text("\(thread.unreadCount) unread")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }

                // Last message preview
                if let lastEmail = thread.emails.last {
                    Text("\(lastEmail.sender): \(lastEmail.body?.prefix(100).description ?? lastEmail.subject)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Thread actions
            VStack(spacing: 8) {
                Button(action: onMarkThreadRead) {
                    Image(systemName: "envelope.open")
                }
                .buttonStyle(.plain)
                .foregroundColor(.green)
                .help("Mark thread as read")

                Button(action: onArchiveThread) {
                    Image(systemName: "archivebox")
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .help("Archive thread")

                Button(action: onDeleteThread) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .help("Delete thread")
            }
        }
    }
}

// MARK: - Thread Email Row

struct ThreadEmailRow: View {
    let email: Email
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Read indicator
                Circle()
                    .fill(email.isRead ? Color.clear : Color.cyan)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(email.sender)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.cyan)

                        Spacer()

                        Text(formatRelativeDate(email.dateReceived))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    if let body = email.body {
                        Text(body.prefix(100).description)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                }

                if let priority = email.priority, priority >= 8 {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let days = Int(interval / 86400)

        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Yesterday"
        } else if days < 7 {
            return "\(days) days ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ThreadedEmailListView_Previews: PreviewProvider {
    static var previews: some View {
        ThreadedEmailListView(mailEngine: MailEngine(), category: nil)
    }
}
#endif
