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

    private let parser = MailParser()
    private let categorizer = AICategorizationEngine()
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadEmails()
    }

    func loadEmails() {
        isScanning = true

        Task {
            let parsed = parser.parseEmails()

            await MainActor.run {
                self.emails = parsed
                self.updateCategories()
                self.updateStats()
                self.isScanning = false
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
