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

    var body: some View {
        VStack(spacing: 0) {
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
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.black.opacity(0.9))

            Divider().background(categoryColor)

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
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(emails) { email in
                            EmailRowView(email: email)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 800, height: 600)
        .background(Color.black)
        .border(categoryColor, width: 2)
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

            if !email.body.isEmpty && email.body != email.subject {
                Text(email.body.prefix(100) + "...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
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
