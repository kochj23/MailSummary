//
//  ContentView.swift
//  Mail Summary
//
//  Main dashboard with TopGUI glass card design
//  Created by Jordan Koch on 2026-01-22
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var mailEngine: MailEngine
    @State private var selectedCategory: Email.EmailCategory?
    @State private var showingEmailList = false

    var body: some View {
        ZStack {
            // Background (like TopGUI)
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                headerView

                // AI Summary Card
                if !mailEngine.aiSummary.isEmpty {
                    aiSummaryCard
                }

                // Category Cards
                categoryGrid

                // Quick Actions
                quickActions

                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showingEmailList) {
            if let category = selectedCategory {
                EmailListView(
                    category: category,
                    emails: mailEngine.emails.filter { $0.category == category },
                    mailEngine: mailEngine
                )
            }
        }
    }

    private var headerView: some View {
        HStack {
            Text("📧 MAIL SUMMARY")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.cyan)

            Spacer()

            if mailEngine.isScanning {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
            }

            Button("Scan Now") {
                mailEngine.scan()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var aiSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title)
                    .foregroundColor(.cyan)

                Text("AI SUMMARY")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text(mailEngine.aiSummary)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan, lineWidth: 2)
                )
        )
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(mailEngine.categories) { category in
                Button(action: {
                    selectedCategory = category.category
                    showingEmailList = true
                }) {
                    CategoryCardView(summary: category)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: 16) {
            if let marketing = mailEngine.categories.first(where: { $0.category == .marketing }), marketing.count > 0 {
                Button(action: {
                    mailEngine.bulkDelete(category: .marketing)
                }) {
                    Label("Delete \(marketing.count) Marketing", systemImage: "trash.fill")
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                // Mark all as read
                mailEngine.emails.forEach { email in
                    mailEngine.markAsRead(emailID: email.id)
                }
            }) {
                Label("Mark All Read", systemImage: "checkmark.circle.fill")
                    .padding()
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}

struct CategoryCardView: View {
    let summary: CategorySummary

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: summary.category.icon)
                .font(.system(size: 36))
                .foregroundColor(categoryColor)

            Text("\(summary.count)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(categoryColor)

            Text(summary.category.rawValue)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            if summary.unreadCount > 0 {
                Text("\(summary.unreadCount) unread")
                    .font(.caption2)
                    .foregroundColor(.cyan)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(categoryColor.opacity(0.5), lineWidth: 1)
                )
        )
    }

    private var categoryColor: Color {
        switch summary.category {
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

#Preview {
    ContentView()
        .environmentObject(MailEngine())
}
