//
//  ThreadGroupingTests.swift
//  Mail SummaryTests
//
//  Functional tests for email thread grouping, subject normalization, and similarity
//  Created by Jordan Koch
//

import XCTest
@testable import Mail_Summary

final class ThreadGroupingTests: XCTestCase {

    // MARK: - Subject Normalization

    func testNormalizeSubjectRemovesRePrefix() {
        XCTAssertEqual(EmailThread.normalizeSubject("Re: Budget Meeting"), "Budget Meeting")
    }

    func testNormalizeSubjectRemovesREPrefix() {
        XCTAssertEqual(EmailThread.normalizeSubject("RE: Budget Meeting"), "Budget Meeting")
    }

    func testNormalizeSubjectRemovesFwdPrefix() {
        XCTAssertEqual(EmailThread.normalizeSubject("Fwd: Urgent Notice"), "Urgent Notice")
    }

    func testNormalizeSubjectRemovesFWDPrefix() {
        XCTAssertEqual(EmailThread.normalizeSubject("FWD: Urgent Notice"), "Urgent Notice")
    }

    func testNormalizeSubjectRemovesFwPrefix() {
        XCTAssertEqual(EmailThread.normalizeSubject("Fw: Document"), "Document")
    }

    func testNormalizeSubjectRemovesNumberBrackets() {
        XCTAssertEqual(EmailThread.normalizeSubject("Re: Budget [2]"), "Budget")
    }

    func testNormalizeSubjectTrimsWhitespace() {
        XCTAssertEqual(EmailThread.normalizeSubject("  Re:  Budget Meeting  "), "Budget Meeting")
    }

    func testNormalizeSubjectHandlesEmptyString() {
        XCTAssertEqual(EmailThread.normalizeSubject(""), "")
    }

    func testNormalizeSubjectHandlesOnlyPrefix() {
        XCTAssertEqual(EmailThread.normalizeSubject("Re:"), "")
    }

    func testNormalizeSubjectPreservesNormalSubject() {
        XCTAssertEqual(EmailThread.normalizeSubject("Q1 Budget Report"), "Q1 Budget Report")
    }

    func testNormalizeSubjectReducesMultipleSpaces() {
        XCTAssertEqual(EmailThread.normalizeSubject("Subject   with   spaces"), "Subject with spaces")
    }

    // MARK: - Thread Creation

    func testThreadCreationWithSingleEmail() {
        let email = makeEmail(id: 1, subject: "Test Subject", sender: "alice@test.com", isRead: false)
        let thread = EmailThread(emails: [email])

        XCTAssertEqual(thread.messageCount, 1)
        XCTAssertEqual(thread.subject, "Test Subject")
        XCTAssertEqual(thread.participants.count, 1)
        XCTAssertTrue(thread.participants.contains("alice@test.com"))
        XCTAssertEqual(thread.unreadCount, 1)
    }

    func testThreadCreationWithMultipleEmails() {
        let emails = [
            makeEmail(id: 1, subject: "Project Update", sender: "alice@test.com", isRead: true, date: Date().addingTimeInterval(-3600)),
            makeEmail(id: 2, subject: "Re: Project Update", sender: "bob@test.com", isRead: false, date: Date().addingTimeInterval(-1800)),
            makeEmail(id: 3, subject: "Re: Project Update", sender: "alice@test.com", isRead: false, date: Date())
        ]

        let thread = EmailThread(emails: emails)

        XCTAssertEqual(thread.messageCount, 3)
        XCTAssertEqual(thread.participants.count, 2)
        XCTAssertEqual(thread.unreadCount, 2)
    }

    func testThreadSortsByDateAscending() {
        let older = makeEmail(id: 1, subject: "Test", sender: "a@t.com", date: Date().addingTimeInterval(-7200))
        let newer = makeEmail(id: 2, subject: "Re: Test", sender: "b@t.com", date: Date())

        let thread = EmailThread(emails: [newer, older]) // Insert in reverse order

        XCTAssertEqual(thread.emails.first?.id, 1, "Oldest email should be first")
        XCTAssertEqual(thread.emails.last?.id, 2, "Newest email should be last")
    }

    func testThreadDetectsHighPriority() {
        let normalEmail = makeEmail(id: 1, subject: "Normal", sender: "a@t.com", priority: 5)
        let urgentEmail = makeEmail(id: 2, subject: "Urgent", sender: "b@t.com", priority: 9)

        let thread = EmailThread(emails: [normalEmail, urgentEmail])
        XCTAssertTrue(thread.hasHighPriority)
    }

    func testThreadNoHighPriority() {
        let email1 = makeEmail(id: 1, subject: "Normal", sender: "a@t.com", priority: 3)
        let email2 = makeEmail(id: 2, subject: "Also Normal", sender: "b@t.com", priority: 5)

        let thread = EmailThread(emails: [email1, email2])
        XCTAssertFalse(thread.hasHighPriority)
    }

    // MARK: - Thread Timespan

    func testThreadTimespanDisplay() {
        let oldDate = Date().addingTimeInterval(-86400 * 3)  // 3 days ago
        let thread = EmailThread(emails: [
            makeEmail(id: 1, subject: "Test", sender: "a@t.com", date: oldDate),
            makeEmail(id: 2, subject: "Re: Test", sender: "b@t.com", date: Date())
        ])

        XCTAssertEqual(thread.timespanDisplay, "3 days")
    }

    func testThreadTimespanDisplayToday() {
        let thread = EmailThread(emails: [
            makeEmail(id: 1, subject: "Test", sender: "a@t.com", date: Date()),
        ])

        XCTAssertEqual(thread.timespanDisplay, "Today")
    }

    // MARK: - Thread belongsToThread

    func testBelongsToThreadExactMatch() {
        let thread = EmailThread(emails: [
            makeEmail(id: 1, subject: "Budget Report", sender: "a@t.com")
        ])

        let newEmail = makeEmail(id: 2, subject: "Budget Report", sender: "b@t.com")
        XCTAssertTrue(thread.belongsToThread(newEmail))
    }

    func testBelongsToThreadWithRePrefix() {
        let thread = EmailThread(emails: [
            makeEmail(id: 1, subject: "Budget Report", sender: "a@t.com")
        ])

        let reply = makeEmail(id: 2, subject: "Re: Budget Report", sender: "b@t.com")
        XCTAssertTrue(thread.belongsToThread(reply))
    }

    func testBelongsToThreadDifferentSubject() {
        let thread = EmailThread(emails: [
            makeEmail(id: 1, subject: "Budget Report", sender: "a@t.com")
        ])

        let unrelated = makeEmail(id: 2, subject: "Lunch Plans", sender: "a@t.com")
        XCTAssertFalse(thread.belongsToThread(unrelated))
    }

    // MARK: - ThreadSummary

    func testThreadSummaryFromThread() {
        let thread = EmailThread(emails: [
            makeEmail(id: 1, subject: "Project", sender: "a@t.com", isRead: true, priority: 9),
            makeEmail(id: 2, subject: "Re: Project", sender: "b@t.com", isRead: false, priority: 5)
        ])

        let summary = ThreadSummary(from: thread)
        XCTAssertEqual(summary.messageCount, 2)
        XCTAssertEqual(summary.unreadCount, 1)
        XCTAssertEqual(summary.participants, 2)
        XCTAssertTrue(summary.hasHighPriority)
    }

    // MARK: - Helpers

    private func makeEmail(id: Int, subject: String, sender: String, isRead: Bool = false, priority: Int? = nil, date: Date = Date()) -> Email {
        Email(
            id: id,
            messageId: "msg-\(id)",
            subject: subject,
            sender: sender.components(separatedBy: "@").first ?? sender,
            senderEmail: sender,
            dateReceived: date,
            body: nil,
            isRead: isRead,
            category: nil,
            priority: priority,
            aiSummary: nil,
            actions: [],
            senderReputation: nil
        )
    }
}
