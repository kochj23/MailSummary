//
//  MailEngine.swift
//  Mail Summary
//
//  Core email management and AI orchestration
//  Created by Jordan Koch on 2026-01-22
//

import Foundation
import Combine

@MainActor
class MailEngine: ObservableObject {
    @Published var emails: [Email] = []
    @Published var categories: [CategorySummary] = []
    @Published var stats: MailboxStats = MailboxStats(totalEmails: 0, unreadEmails: 0, todayEmails: 0, highPriorityEmails: 0, actionsCount: 0)
    @Published var aiSummary: String = ""
    @Published var isScanning: Bool = false
    @Published var isCategorizingWithAI: Bool = false
    @Published var aiProgress: String = ""

    // NEW: Search & Filter
    @Published var searchManager = SearchFilterManager()
    @Published var isSearching = false

    // NEW: Snooze & Reminders
    @Published var snoozedEmails: [Email] = []
    @Published var activeReminders: [EmailReminder] = []

    // NEW: Action feedback
    @Published var lastActionResult: (String, Bool)? = nil  // (message, isSuccess)

    private let parser = MailParser()
    private let categorizer = AICategorizationEngine()
    private let actionManager = EmailActionManager.shared
    private let snoozeManager = SnoozeReminderManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var snoozeCheckTimer: Timer?

    init() {
        loadEmails()

        // Check for expired snoozes every minute
        snoozeCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkExpiredSnoozes()
            }
        }
    }

    func loadEmails() {
        isScanning = true

        Task {
            var parsed = await parser.parseEmails(limit: 500)  // Now async with timeout

            await MainActor.run {
                self.isCategorizingWithAI = true
                self.aiProgress = "Categorizing \(parsed.count) emails with AI..."
            }

            // Categorize emails with AI
            for (index, _) in parsed.enumerated() {
                let category = await categorizer.categorizeEmail(parsed[index])
                let priority = await categorizer.scoreEmailPriority(parsed[index])
                parsed[index].category = category
                parsed[index].priority = priority

                // Update progress
                if index % 10 == 0 {
                    await MainActor.run {
                        self.aiProgress = "Categorized \(index+1)/\(parsed.count) emails..."
                    }
                }
            }

            await MainActor.run {
                self.emails = parsed
                self.updateCategories()
                self.updateStats()
                self.isScanning = false
                self.isCategorizingWithAI = false
                self.aiProgress = ""
            }

            // AI summary
            await generateAISummary()
        }
    }

    func scan() {
        loadEmails()
    }

    private func updateCategories() {
        let grouped = Dictionary(grouping: emails) { $0.category ?? .other }

        categories = Email.EmailCategory.allCases.compactMap { category in
            guard let categoryEmails = grouped[category], !categoryEmails.isEmpty else { return nil }

            return CategorySummary(
                category: category,
                count: categoryEmails.count,
                unreadCount: categoryEmails.filter { !$0.isRead }.count,
                highPriorityCount: categoryEmails.filter { ($0.priority ?? 0) >= 7 }.count,
                aiSummary: nil
            )
        }.sorted { $0.count > $1.count }
    }

    private func updateStats() {
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)

        stats = MailboxStats(
            totalEmails: emails.count,
            unreadEmails: emails.filter { !$0.isRead }.count,
            todayEmails: emails.filter { $0.dateReceived >= startOfToday }.count,
            highPriorityEmails: emails.filter { ($0.priority ?? 0) >= 7 }.count,
            actionsCount: emails.reduce(0) { $0 + $1.actions.count }
        )
    }

    private func generateAISummary() async {
        let summary = await categorizer.generateOverallSummary(emails: emails, stats: stats)

        await MainActor.run {
            self.aiSummary = summary
        }
    }

    /// Load email body on-demand
    func loadEmailBody(emailID: Int) async {
        guard let index = emails.firstIndex(where: { $0.id == emailID }) else { return }

        // Already loaded or loading
        if emails[index].body != nil || emails[index].isLoadingBody {
            return
        }

        // Mark as loading
        await MainActor.run {
            self.emails[index].isLoadingBody = true
        }

        // Load body
        let messageId = emails[index].messageId
        if let body = await parser.loadEmailBody(messageId: messageId) {
            await MainActor.run {
                self.emails[index].body = body
                self.emails[index].isLoadingBody = false
            }
        } else {
            await MainActor.run {
                self.emails[index].body = "[Unable to load email body]"
                self.emails[index].isLoadingBody = false
            }
        }
    }

    // MARK: - Email Actions

    /// Perform an action on an email (delete, archive, reply, etc.)
    func performEmailAction(_ action: EmailActionType, on email: Email) async {
        let result = await actionManager.performAction(action, on: email)

        await MainActor.run {
            switch result {
            case .success:
                lastActionResult = ("✅ \(action.displayName) completed", true)

                // Update UI state based on action
                switch action {
                case .delete, .archive:
                    deleteEmail(emailID: email.id)

                case .markRead:
                    if let index = emails.firstIndex(where: { $0.id == email.id }) {
                        emails[index].isRead = true
                    }
                    updateStats()

                case .markUnread:
                    if let index = emails.firstIndex(where: { $0.id == email.id }) {
                        emails[index].isRead = false
                    }
                    updateStats()

                case .toggleRead:
                    if let index = emails.firstIndex(where: { $0.id == email.id }) {
                        emails[index].isRead.toggle()
                    }
                    updateStats()

                case .reply, .forward:
                    // Mail.app draft window opened, no UI update needed
                    break

                case .move:
                    // Email moved, remove from list
                    deleteEmail(emailID: email.id)
                }

            case .failure(let error):
                lastActionResult = ("❌ \(error)", false)

            case .notSupported:
                lastActionResult = ("⚠️ Action not supported", false)
            }

            // Clear toast after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    self.lastActionResult = nil
                }
            }
        }
    }

    // MARK: - Snooze & Reminders

    /// Mark email as snoozed
    func markEmailAsSnoozed(emailId: Int, until: Date) {
        if let index = emails.firstIndex(where: { $0.id == emailId }) {
            emails[index].isSnoozed = true
            emails[index].snoozeUntil = until
        }
        updateSnoozedList()
    }

    /// Unsnooze an email
    func unsnoozeEmail(emailId: Int) {
        if let index = emails.firstIndex(where: { $0.id == emailId }) {
            emails[index].isSnoozed = false
            emails[index].snoozeUntil = nil
        }
        updateSnoozedList()
    }

    /// Mark email as having a reminder
    func markEmailAsHasReminder(emailId: Int, remindAt: Date) {
        if let index = emails.firstIndex(where: { $0.id == emailId }) {
            emails[index].hasReminder = true
            emails[index].reminderDate = remindAt
        }
        updateActiveReminders()
    }

    /// Check for expired snoozes
    private func checkExpiredSnoozes() {
        let expired = snoozeManager.getExpiredSnoozed()

        for snoozed in expired {
            // Find email and unsnooze
            if let index = emails.firstIndex(where: { $0.messageId == snoozed.messageId }) {
                emails[index].isSnoozed = false
                emails[index].snoozeUntil = nil
            }

            snoozeManager.unsnooze(emailId: snoozed.emailId)
        }

        if !expired.isEmpty {
            updateSnoozedList()
            lastActionResult = ("📧 \(expired.count) snoozed email\(expired.count == 1 ? "" : "s") ready", true)

            // Clear message after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    self.lastActionResult = nil
                }
            }
        }

        updateActiveReminders()
    }

    /// Update snoozed emails list
    private func updateSnoozedList() {
        snoozedEmails = emails.filter { $0.isSnoozed }
    }

    /// Update active reminders list
    private func updateActiveReminders() {
        activeReminders = snoozeManager.getActiveReminders()
    }

    func markAsRead(emailID: Int) {
        if let index = emails.firstIndex(where: { $0.id == emailID }) {
            emails[index].isRead = true
            updateStats()
        }
    }

    func deleteEmail(emailID: Int) {
        emails.removeAll { $0.id == emailID }
        updateCategories()
        updateStats()
    }

    func bulkDelete(category: Email.EmailCategory) {
        emails.removeAll { $0.category == category }
        updateCategories()
        updateStats()
    }
}
