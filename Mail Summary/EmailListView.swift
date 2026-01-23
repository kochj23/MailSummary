//
//  EmailListView.swift
//  Mail Summary
//
//  Email list for selected category
//  Created by Jordan Koch on 2026-01-22
//

import SwiftUI

struct EmailListView: View {
    let category: Email.EmailCategory
    let emails: [Email]
    @ObservedObject var mailEngine: MailEngine
    @Environment(\.dismiss) var dismiss

    @State private var selectedEmail: Email?

    var body: some View {
        VStack(spacing: 0) {
            // Debug: Print when view loads
            let _ = print("📋 EmailListView loaded: \(category.rawValue), \(emails.count) emails")

            // Header
            HStack {
                Image(systemName: category.icon)
                    .font(.title)
                    .foregroundColor(categoryColor)

                Text("\(category.rawValue.uppercased()) EMAILS")
                    .font(.title2)
                    .foregroundColor(.white)

                Spacer()

                Text("\(emails.count) emails")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.black)

            Divider()
                .background(categoryColor)
                .frame(height: 2)

            // Email list
            if emails.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "tray")
                        .font(.system(size: 64))
                        .foregroundColor(.gray)

                    Text("No \(category.rawValue) emails")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(emails) { email in
                            EmailRowView(email: email, mailEngine: mailEngine)
                                .onTapGesture {
                                    selectedEmail = email
                                }
                        }
                    }
                    .padding()
                }
                .background(Color.black)
            }
        }
        .frame(width: 800, height: 600)
        .background(Color.black)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(categoryColor, lineWidth: 3)
        )
        .sheet(item: $selectedEmail) { email in
            EmailDetailView(email: email, mailEngine: mailEngine)
        }
    }

    private var categoryColor: Color {
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
}

struct EmailRowView: View {
    let email: Email
    @ObservedObject var mailEngine: MailEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(email.sender)
                    .font(.headline)
                    .foregroundColor(.cyan)

                Spacer()

                if let priority = email.priority {
                    Text("⭐ \(priority)")
                        .font(.caption)
                        .foregroundColor(priorityColor(priority))
                }

                Text(formatDate(email.dateReceived))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            Text(email.subject)
                .font(.body)
                .foregroundColor(.white)

            // Body preview (if loaded)
            if let body = email.body, !body.isEmpty && body != email.subject {
                Text(body.prefix(100) + "...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            } else if email.isLoadingBody {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Loading body...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            if let summary = email.aiSummary {
                Text("🤖 \(summary)")
                    .font(.caption)
                    .foregroundColor(.cyan.opacity(0.8))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
        .onTapGesture {
            // Load body on-demand when user taps email
            Task {
                await mailEngine.loadEmailBody(emailID: email.id)
            }
        }
    }

    private func priorityColor(_ priority: Int) -> Color {
        if priority >= 9 { return .red }
        if priority >= 7 { return .orange }
        if priority >= 5 { return .yellow }
        return .green
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
