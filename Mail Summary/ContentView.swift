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
    @State private var showingSearch = false

    var body: some View {
        ZStack {
            // Background (like TopGUI)
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                headerView

                // NEW: Action result toast
                if let (message, isSuccess) = mailEngine.lastActionResult {
                    ActionToast(message: message, isSuccess: isSuccess)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(100)
                }

                // NEW: Active reminders banner
                if !mailEngine.activeReminders.isEmpty {
                    RemindersBanner(reminders: mailEngine.activeReminders)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // AI Status Card (when processing)
                if mailEngine.isCategorizingWithAI {
                    aiStatusCard
                }

                // AI Summary Card
                if !mailEngine.aiSummary.isEmpty {
                    aiSummaryCard
                }

                // NEW: Snoozed emails section (if any)
                if !mailEngine.snoozedEmails.isEmpty {
                    SnoozedSection(snoozedEmails: snoozeManager.snoozedEmails, mailEngine: mailEngine)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Category Cards
                categoryGrid

                // Quick Actions
                quickActions

                Spacer()
            }
            .padding()
            .blur(radius: showingEmailList || showingSearch ? 5 : 0)

            // Custom modal overlay for email list
            if showingEmailList, let category = selectedCategory {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingEmailList = false
                    }

                let filtered = mailEngine.emails.filter { $0.category == category && !$0.isSnoozed }
                let _ = print("🔍 Opening modal for \(category.rawValue): \(filtered.count) emails")
                EmailListView(
                    category: category,
                    emails: filtered,
                    mailEngine: mailEngine
                )
                .transition(.scale.combined(with: .opacity))
            }

            // NEW: Search overlay
            if showingSearch {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingSearch = false
                    }

                SearchView(
                    searchManager: mailEngine.searchManager,
                    mailEngine: mailEngine,
                    isPresented: $showingSearch
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: showingEmailList)
        .animation(.spring(response: 0.3), value: showingSearch)
        .animation(.spring(response: 0.3), value: mailEngine.lastActionResult != nil)
        .animation(.spring(response: 0.3), value: mailEngine.activeReminders.count)
        .onAppear {
            // Cleanup on app launch
            SnoozeReminderManager.shared.cleanupExpired()
        }
    }

    private var snoozeManager: SnoozeReminderManager {
        SnoozeReminderManager.shared
    }

    private var headerView: some View {
        HStack {
            Text("📧 MAIL SUMMARY")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.cyan)

            Spacer()

            // NEW: Search button
            Button(action: { showingSearch = true }) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundColor(.cyan)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: .command)
            .help("Search emails (⌘F)")

            // AI Backend Indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(AIBackendManager.shared.activeBackend != nil ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                    .shadow(color: AIBackendManager.shared.activeBackend != nil ? Color.green : Color.red, radius: 3)

                Text(AIBackendManager.shared.activeBackend?.rawValue ?? "No AI")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(AIBackendManager.shared.activeBackend != nil ? .green : .red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.05))
            .cornerRadius(6)

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

    private var aiStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .purple))

                Text("🤖 AI PROCESSING")
                    .font(.headline)
                    .foregroundColor(.purple)

                Spacer()
            }

            Text(mailEngine.aiProgress)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple, lineWidth: 2)
                )
        )
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
