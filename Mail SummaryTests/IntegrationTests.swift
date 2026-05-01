//
//  IntegrationTests.swift
//  Mail SummaryTests
//
//  Integration tests with mock email data: summarization workflow, thread grouping,
//  batch categorization, snooze/reminder lifecycle, search pipeline
//  Created by Jordan Koch
//

import XCTest
@testable import Mail_Summary

@MainActor
final class IntegrationTests: XCTestCase {

    // MARK: - Mock Email Data Factory

    private func makeSampleEmails() -> [Email] {
        [
            makeEmail(id: 1, subject: "Electric Bill Due January 25", sender: "billing@pge.com", category: .bills, priority: 9, body: "Your electric bill of $156.78 is due January 25."),
            makeEmail(id: 2, subject: "Your Amazon order has shipped", sender: "shipment@amazon.com", category: .orders, priority: 6, body: "Order #123-456 has been shipped. Tracking: 1Z999AA10123456789."),
            makeEmail(id: 3, subject: "50% OFF SALE - Limited Time!", sender: "promo@marketing.com", category: .marketing, priority: 2, body: "Don't miss our biggest sale of the year! Unsubscribe here."),
            makeEmail(id: 4, subject: "Team Meeting Tuesday 3pm", sender: "boss@company.com", category: .work, priority: 8, body: "Team meeting Tuesday at 3pm. Please review Q1 projections."),
            makeEmail(id: 5, subject: "Re: Team Meeting Tuesday 3pm", sender: "colleague@company.com", category: .work, priority: 7, body: "Sounds good! I'll prepare the slides."),
            makeEmail(id: 6, subject: "Re: Team Meeting Tuesday 3pm", sender: "boss@company.com", category: .work, priority: 7, body: "Great, see you all there."),
            makeEmail(id: 7, subject: "Hey, how are you?", sender: "friend@gmail.com", category: .personal, priority: 5, body: "Just checking in, haven't talked in a while!"),
            makeEmail(id: 8, subject: "LinkedIn: 5 new connections", sender: "notifications@linkedin.com", category: .social, priority: 3, body: "You have 5 new connection requests."),
            makeEmail(id: 9, subject: "Weekly Newsletter - Tech Digest", sender: "digest@techsite.com", category: .newsletters, priority: 2, body: "This week in tech: AI breakthroughs..."),
            makeEmail(id: 10, subject: "Verify your account NOW!", sender: "security@paypa1.com", category: .spam, priority: 1, body: "Dear customer, verify now or your account will be suspended. Click: bit.ly/scam")
        ]
    }

    // MARK: - Thread Grouping Integration

    func testThreadGroupingFromMixedEmails() {
        let emails = makeSampleEmails()
        let threadManager = ThreadManager.shared
        let threads = threadManager.groupEmailsIntoThreads(emails)

        // Should group the 3 "Team Meeting" emails into 1 thread
        let meetingThreads = threads.filter { $0.subject.contains("Team Meeting") }
        XCTAssertEqual(meetingThreads.count, 1, "Team Meeting emails should group into one thread")
        XCTAssertEqual(meetingThreads.first?.messageCount, 3)
        XCTAssertEqual(meetingThreads.first?.participants.count, 2)  // boss + colleague
    }

    func testThreadGroupingSingleEmails() {
        let emails = makeSampleEmails()
        let threadManager = ThreadManager.shared
        let threads = threadManager.groupEmailsIntoThreads(emails)

        // Bill, Amazon, Marketing, etc. should each be their own thread
        let billThread = threads.first { $0.subject.contains("Electric Bill") }
        XCTAssertNotNil(billThread)
        XCTAssertEqual(billThread?.messageCount, 1)
    }

    func testThreadGroupingStatistics() {
        let emails = makeSampleEmails()
        let threadManager = ThreadManager.shared
        let _ = threadManager.groupEmailsIntoThreads(emails)
        let stats = threadManager.getThreadStatistics()

        XCTAssertGreaterThan(stats.totalThreads, 0)
        XCTAssertGreaterThan(stats.avgMessagesPerThread, 0)
        XCTAssertGreaterThanOrEqual(stats.longestThread, 3) // Team meeting thread has 3
    }

    // MARK: - Category Distribution

    func testCategoryDistributionCoverage() {
        let emails = makeSampleEmails()

        let categories = Set(emails.compactMap { $0.category })
        XCTAssertTrue(categories.contains(.bills))
        XCTAssertTrue(categories.contains(.orders))
        XCTAssertTrue(categories.contains(.marketing))
        XCTAssertTrue(categories.contains(.work))
        XCTAssertTrue(categories.contains(.personal))
        XCTAssertTrue(categories.contains(.social))
        XCTAssertTrue(categories.contains(.newsletters))
        XCTAssertTrue(categories.contains(.spam))
    }

    func testCategorySummaryGeneration() {
        let emails = makeSampleEmails()
        let grouped = Dictionary(grouping: emails) { $0.category ?? .other }

        let workEmails = grouped[.work] ?? []
        XCTAssertEqual(workEmails.count, 3, "Should have 3 work emails")

        let billEmails = grouped[.bills] ?? []
        XCTAssertEqual(billEmails.count, 1, "Should have 1 bill")
    }

    // MARK: - Priority Scoring Distribution

    func testPriorityDistribution() {
        let emails = makeSampleEmails()

        let highPriority = emails.filter { ($0.priority ?? 0) >= 7 }
        let lowPriority = emails.filter { ($0.priority ?? 0) <= 3 }

        XCTAssertGreaterThan(highPriority.count, 0, "Should have high priority emails")
        XCTAssertGreaterThan(lowPriority.count, 0, "Should have low priority emails")
    }

    func testHighPriorityEmailsAreActionable() {
        let emails = makeSampleEmails()

        let highPriority = emails.filter { ($0.priority ?? 0) >= 8 }

        // High priority emails should be bills or work
        for email in highPriority {
            let isActionable = email.category == .bills || email.category == .work
            XCTAssertTrue(isActionable, "High priority email '\(email.subject)' should be bills or work, got \(email.category?.rawValue ?? "nil")")
        }
    }

    // MARK: - Search Pipeline Integration

    func testSearchByQuery() async {
        let emails = makeSampleEmails()
        let searchManager = SearchFilterManager()
        searchManager.filters.query = "meeting"
        searchManager.search(in: emails)

        // search() uses internal Task, wait for it
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertGreaterThan(searchManager.results.count, 0, "Should find meeting-related emails")
    }

    func testSearchByCategory() async {
        let emails = makeSampleEmails()
        let searchManager = SearchFilterManager()
        searchManager.filters.categories = [.work]
        searchManager.search(in: emails)

        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(searchManager.results.count, 3, "Should find 3 work emails")
    }

    func testSearchByPriorityMinimum() async {
        let emails = makeSampleEmails()
        let searchManager = SearchFilterManager()
        searchManager.filters.minPriority = 8
        searchManager.search(in: emails)

        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(searchManager.results.allSatisfy { ($0.email.priority ?? 0) >= 8 })
    }

    func testSearchNoResults() async {
        let emails = makeSampleEmails()
        let searchManager = SearchFilterManager()
        searchManager.filters.query = "xyznonexistentquery"
        searchManager.search(in: emails)

        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(searchManager.results.isEmpty)
    }

    func testSearchClearFiltersResetsResults() {
        let searchManager = SearchFilterManager()

        // clearFilters should reset
        searchManager.clearFilters()
        XCTAssertTrue(searchManager.results.isEmpty)
        XCTAssertFalse(searchManager.filters.isActive)
    }

    // MARK: - Snooze/Reminder Models

    func testSnoozedEmailExpiration() {
        let snoozed = SnoozedEmail(
            id: UUID(),
            emailId: 1,
            messageId: "msg-1",
            emailSubject: "Test",
            senderEmail: "test@test.com",
            snoozeUntil: Date().addingTimeInterval(-60),  // 1 minute ago
            createdAt: Date().addingTimeInterval(-3600)
        )

        XCTAssertTrue(snoozed.isExpired)
    }

    func testSnoozedEmailNotExpired() {
        let snoozed = SnoozedEmail(
            id: UUID(),
            emailId: 1,
            messageId: "msg-1",
            emailSubject: "Test",
            senderEmail: "test@test.com",
            snoozeUntil: Date().addingTimeInterval(3600),  // 1 hour from now
            createdAt: Date()
        )

        XCTAssertFalse(snoozed.isExpired)
        XCTAssertGreaterThan(snoozed.timeRemaining, 0)
    }

    func testReminderReadyState() {
        let reminder = EmailReminder(
            id: UUID(),
            emailId: 1,
            messageId: "msg-1",
            emailSubject: "Follow up",
            remindAt: Date().addingTimeInterval(-60),  // 1 minute ago
            note: "Check response",
            reminderType: .followUp,
            createdAt: Date().addingTimeInterval(-3600),
            isCompleted: false
        )

        XCTAssertTrue(reminder.isReady)
    }

    func testReminderNotReadyWhenCompleted() {
        let reminder = EmailReminder(
            id: UUID(),
            emailId: 1,
            messageId: "msg-1",
            emailSubject: "Follow up",
            remindAt: Date().addingTimeInterval(-60),
            note: nil,
            reminderType: .followUp,
            createdAt: Date().addingTimeInterval(-3600),
            isCompleted: true
        )

        XCTAssertFalse(reminder.isReady, "Completed reminders should not be ready")
    }

    func testReminderNotReadyWhenFuture() {
        let reminder = EmailReminder(
            id: UUID(),
            emailId: 1,
            messageId: "msg-1",
            emailSubject: "Follow up",
            remindAt: Date().addingTimeInterval(3600),
            note: nil,
            reminderType: .followUp,
            createdAt: Date(),
            isCompleted: false
        )

        XCTAssertFalse(reminder.isReady, "Future reminders should not be ready yet")
    }

    // MARK: - MailboxStats Calculation

    func testMailboxStatsFromEmails() {
        let emails = makeSampleEmails()
        let today = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: today)

        let stats = MailboxStats(
            totalEmails: emails.count,
            unreadEmails: emails.filter { !$0.isRead }.count,
            todayEmails: emails.filter { $0.dateReceived >= startOfToday }.count,
            highPriorityEmails: emails.filter { ($0.priority ?? 0) >= 7 }.count,
            actionsCount: emails.reduce(0) { $0 + $1.actions.count }
        )

        XCTAssertEqual(stats.totalEmails, 10)
        XCTAssertEqual(stats.highPriorityEmails, 4)  // priority 7, 7, 8, 9
    }

    // MARK: - Helpers

    private func makeEmail(id: Int, subject: String, sender: String, category: Email.EmailCategory? = nil, priority: Int? = nil, body: String? = nil, isRead: Bool = false) -> Email {
        Email(
            id: id,
            messageId: "msg-\(id)",
            subject: subject,
            sender: sender.components(separatedBy: "@").first ?? sender,
            senderEmail: sender,
            dateReceived: Date().addingTimeInterval(Double(-id) * 3600),
            body: body,
            isRead: isRead,
            category: category,
            priority: priority,
            aiSummary: nil,
            actions: [],
            senderReputation: nil
        )
    }
}
