//
//  EmailModelsTests.swift
//  Mail SummaryTests
//
//  Unit tests for Email data model, EmailCategory, EmailAction, and related structs
//  Created by Jordan Koch
//

import XCTest
@testable import Mail_Summary

final class EmailModelsTests: XCTestCase {

    // MARK: - Email Struct Tests

    func testEmailInitializationWithAllFields() {
        let date = Date()
        let action = EmailAction(type: .deadline, text: "Pay bill", date: date)
        let email = Email(
            id: 1,
            messageId: "msg-123",
            subject: "Test Subject",
            sender: "John Doe",
            senderEmail: "john@example.com",
            dateReceived: date,
            body: "Test body content",
            isRead: false,
            category: .work,
            priority: 8,
            aiSummary: "AI generated summary",
            actions: [action],
            senderReputation: 0.85
        )

        XCTAssertEqual(email.id, 1)
        XCTAssertEqual(email.messageId, "msg-123")
        XCTAssertEqual(email.subject, "Test Subject")
        XCTAssertEqual(email.sender, "John Doe")
        XCTAssertEqual(email.senderEmail, "john@example.com")
        XCTAssertEqual(email.dateReceived, date)
        XCTAssertEqual(email.body, "Test body content")
        XCTAssertFalse(email.isRead)
        XCTAssertEqual(email.category, .work)
        XCTAssertEqual(email.priority, 8)
        XCTAssertEqual(email.aiSummary, "AI generated summary")
        XCTAssertEqual(email.actions.count, 1)
        XCTAssertEqual(email.senderReputation, 0.85)
    }

    func testEmailOptionalFieldsDefaultToNil() {
        let email = Email(
            id: 1,
            messageId: "msg-1",
            subject: "Test",
            sender: "Sender",
            senderEmail: "sender@example.com",
            dateReceived: Date(),
            body: nil,
            isRead: true,
            category: nil,
            priority: nil,
            aiSummary: nil,
            actions: [],
            senderReputation: nil
        )

        XCTAssertNil(email.body)
        XCTAssertNil(email.category)
        XCTAssertNil(email.priority)
        XCTAssertNil(email.aiSummary)
        XCTAssertNil(email.senderReputation)
        XCTAssertTrue(email.actions.isEmpty)
    }

    func testEmailSnoozeAndReminderDefaults() {
        let email = Email(
            id: 1, messageId: "m1", subject: "S", sender: "S",
            senderEmail: "s@e.com", dateReceived: Date(), body: nil,
            isRead: false, category: nil, priority: nil, aiSummary: nil,
            actions: [], senderReputation: nil
        )

        XCTAssertFalse(email.isSnoozed)
        XCTAssertNil(email.snoozeUntil)
        XCTAssertFalse(email.hasReminder)
        XCTAssertNil(email.reminderDate)
        XCTAssertTrue(email.matchedFields.isEmpty)
    }

    func testEmailEquality() {
        let email1 = makeEmail(id: 1, subject: "Subject A")
        let email2 = makeEmail(id: 1, subject: "Subject B")
        let email3 = makeEmail(id: 2, subject: "Subject A")

        XCTAssertEqual(email1, email2, "Emails with same ID should be equal regardless of subject")
        XCTAssertNotEqual(email1, email3, "Emails with different IDs should not be equal")
    }

    func testEmailHashConsistency() {
        let email1 = makeEmail(id: 42, subject: "Test")
        let email2 = makeEmail(id: 42, subject: "Different Subject")

        var set: Set<Email> = [email1]
        set.insert(email2)

        XCTAssertEqual(set.count, 1, "Same ID emails should hash to same bucket")
    }

    func testEmailCodable() throws {
        let original = makeEmail(id: 1, subject: "Codable Test")
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Email.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.subject, original.subject)
        XCTAssertEqual(decoded.senderEmail, original.senderEmail)
    }

    // MARK: - EmailCategory Tests

    func testAllCategoriesHaveIcons() {
        for category in Email.EmailCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty, "\(category.rawValue) should have an icon")
        }
    }

    func testAllCategoriesHaveColors() {
        for category in Email.EmailCategory.allCases {
            XCTAssertFalse(category.color.isEmpty, "\(category.rawValue) should have a color")
        }
    }

    func testCategoryCaseCount() {
        XCTAssertEqual(Email.EmailCategory.allCases.count, 9, "Should have 9 email categories")
    }

    func testCategoryRawValues() {
        XCTAssertEqual(Email.EmailCategory.bills.rawValue, "Bills")
        XCTAssertEqual(Email.EmailCategory.orders.rawValue, "Orders")
        XCTAssertEqual(Email.EmailCategory.work.rawValue, "Work")
        XCTAssertEqual(Email.EmailCategory.personal.rawValue, "Personal")
        XCTAssertEqual(Email.EmailCategory.marketing.rawValue, "Marketing")
        XCTAssertEqual(Email.EmailCategory.newsletters.rawValue, "Newsletters")
        XCTAssertEqual(Email.EmailCategory.social.rawValue, "Social")
        XCTAssertEqual(Email.EmailCategory.spam.rawValue, "Spam")
        XCTAssertEqual(Email.EmailCategory.other.rawValue, "Other")
    }

    // MARK: - EmailAction Tests

    func testEmailActionInitialization() {
        let date = Date()
        let action = EmailAction(type: .meeting, text: "Team standup", date: date)

        XCTAssertEqual(action.type, .meeting)
        XCTAssertEqual(action.text, "Team standup")
        XCTAssertEqual(action.date, date)
        XCTAssertNotNil(action.id)
    }

    func testEmailActionWithNilDate() {
        let action = EmailAction(type: .task, text: "Review PR", date: nil)

        XCTAssertEqual(action.type, .task)
        XCTAssertNil(action.date)
    }

    func testEmailActionTypes() {
        XCTAssertEqual(EmailAction.ActionType.deadline.rawValue, "deadline")
        XCTAssertEqual(EmailAction.ActionType.meeting.rawValue, "meeting")
        XCTAssertEqual(EmailAction.ActionType.task.rawValue, "task")
        XCTAssertEqual(EmailAction.ActionType.reminder.rawValue, "reminder")
    }

    // MARK: - CategorySummary Tests

    func testCategorySummaryCreation() {
        let summary = CategorySummary(
            category: .bills,
            count: 5,
            unreadCount: 3,
            highPriorityCount: 2,
            aiSummary: "3 bills due this week"
        )

        XCTAssertEqual(summary.category, .bills)
        XCTAssertEqual(summary.count, 5)
        XCTAssertEqual(summary.unreadCount, 3)
        XCTAssertEqual(summary.highPriorityCount, 2)
        XCTAssertEqual(summary.aiSummary, "3 bills due this week")
    }

    // MARK: - MailboxStats Tests

    func testMailboxStatsCreation() {
        let stats = MailboxStats(
            totalEmails: 100,
            unreadEmails: 25,
            todayEmails: 10,
            highPriorityEmails: 5,
            actionsCount: 8
        )

        XCTAssertEqual(stats.totalEmails, 100)
        XCTAssertEqual(stats.unreadEmails, 25)
        XCTAssertEqual(stats.todayEmails, 10)
        XCTAssertEqual(stats.highPriorityEmails, 5)
        XCTAssertEqual(stats.actionsCount, 8)
    }

    // MARK: - Helpers

    private func makeEmail(id: Int, subject: String) -> Email {
        Email(
            id: id,
            messageId: "msg-\(id)",
            subject: subject,
            sender: "Test Sender",
            senderEmail: "test@example.com",
            dateReceived: Date(),
            body: nil,
            isRead: false,
            category: nil,
            priority: nil,
            aiSummary: nil,
            actions: [],
            senderReputation: nil
        )
    }
}
