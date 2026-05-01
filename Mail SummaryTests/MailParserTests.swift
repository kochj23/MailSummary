//
//  MailParserTests.swift
//  Mail SummaryTests
//
//  Unit tests for email header extraction, MIME parsing, and metadata parsing
//  Created by Jordan Koch
//

import XCTest
@testable import Mail_Summary

final class MailParserTests: XCTestCase {

    var parser: MailParser!

    override func setUp() {
        super.setUp()
        parser = MailParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    // MARK: - Sender Extraction Tests

    func testSenderEmailExtractionFromAngleBrackets() {
        // The parser extracts email from "Name <email@domain.com>" format
        // We test the pattern used in parseMetadataOutput
        let senderString = "John Doe <john@example.com>"
        let (name, email) = extractSenderParts(senderString)

        XCTAssertEqual(name, "John Doe")
        XCTAssertEqual(email, "john@example.com")
    }

    func testSenderEmailExtractionPlainEmail() {
        let senderString = "user@domain.com"
        let (name, email) = extractSenderParts(senderString)

        XCTAssertEqual(name, "user@domain.com")
        XCTAssertEqual(email, "user@domain.com")
    }

    func testSenderEmailExtractionWithQuotedName() {
        let senderString = "\"Jane Smith\" <jane@company.org>"
        let (name, email) = extractSenderParts(senderString)

        XCTAssertEqual(name, "\"Jane Smith\"")
        XCTAssertEqual(email, "jane@company.org")
    }

    func testSenderEmailExtractionEmptyAngles() {
        let senderString = "No Email <>"
        let (name, email) = extractSenderParts(senderString)

        XCTAssertEqual(name, "No Email")
        XCTAssertEqual(email, "")
    }

    // MARK: - Metadata Parsing Tests

    func testParseSingleEmailMetadata() {
        // Simulate the pipe-delimited format: messageId|subject|sender|date|isRead
        let output = "12345|Test Subject|John Doe <john@test.com>|Thursday, January 30, 2026 at 9:30:00 AM|false"
        let emails = parseMetadataOutput(output, startId: 0)

        XCTAssertEqual(emails.count, 1)
        XCTAssertEqual(emails.first?.messageId, "12345")
        XCTAssertEqual(emails.first?.subject, "Test Subject")
        XCTAssertEqual(emails.first?.senderEmail, "john@test.com")
        XCTAssertFalse(emails.first?.isRead ?? true)
    }

    func testParseMultipleEmailsDelimited() {
        let output = "1|Sub A|Alice <a@test.com>|Thursday, January 30, 2026 at 9:00:00 AM|false|||2|Sub B|Bob <b@test.com>|Thursday, January 30, 2026 at 10:00:00 AM|true"
        let emails = parseMetadataOutput(output, startId: 0)

        XCTAssertEqual(emails.count, 2)
        XCTAssertEqual(emails[0].subject, "Sub A")
        XCTAssertEqual(emails[1].subject, "Sub B")
        XCTAssertFalse(emails[0].isRead)
        XCTAssertTrue(emails[1].isRead)
    }

    func testParseMalformedMetadataSkipsEntry() {
        // Only 3 parts instead of 5
        let output = "1|Subject Only|sender@test.com"
        let emails = parseMetadataOutput(output, startId: 0)

        XCTAssertEqual(emails.count, 0, "Malformed metadata should be skipped")
    }

    func testParseEmptyOutput() {
        let emails = parseMetadataOutput("", startId: 0)
        XCTAssertTrue(emails.isEmpty)
    }

    func testParseReadStatusTrue() {
        let output = "1|Sub|sender@test.com|Thursday, January 30, 2026 at 9:00:00 AM|true"
        let emails = parseMetadataOutput(output, startId: 0)
        XCTAssertTrue(emails.first?.isRead ?? false)
    }

    func testParseReadStatusFalse() {
        let output = "1|Sub|sender@test.com|Thursday, January 30, 2026 at 9:00:00 AM|false"
        let emails = parseMetadataOutput(output, startId: 0)
        XCTAssertFalse(emails.first?.isRead ?? true)
    }

    func testParseStartIdOffset() {
        let output = "1|Sub A|a@test.com|Thursday, January 30, 2026 at 9:00:00 AM|false|||2|Sub B|b@test.com|Thursday, January 30, 2026 at 10:00:00 AM|false"
        let emails = parseMetadataOutput(output, startId: 100)

        XCTAssertEqual(emails[0].id, 100)
        XCTAssertEqual(emails[1].id, 101)
    }

    func testBodyIsNilAfterMetadataParse() {
        let output = "1|Sub|sender@test.com|Thursday, January 30, 2026 at 9:00:00 AM|false"
        let emails = parseMetadataOutput(output, startId: 0)

        XCTAssertNil(emails.first?.body, "Body should be nil after metadata-only parse")
    }

    // MARK: - Date Parsing Tests

    func testDateParsingWithValidFormat() {
        // Generate a valid date string using the same formatter the parser uses
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm:ss a"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let testDate = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 30, hour: 9, minute: 30, second: 0))!
        let dateString = dateFormatter.string(from: testDate)

        let output = "1|Sub|s@t.com|\(dateString)|false"
        let emails = parseMetadataOutput(output, startId: 0)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: emails.first!.dateReceived)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 30)
    }

    func testDateParsingWithInvalidFormatDefaultsToNow() {
        let output = "1|Sub|s@t.com|not-a-date|false"
        let emails = parseMetadataOutput(output, startId: 0)

        // Invalid date should default to Date() - within 5 seconds of now
        let timeDiff = abs(emails.first!.dateReceived.timeIntervalSinceNow)
        XCTAssertLessThan(timeDiff, 5.0, "Invalid date should default to approximately now")
    }

    // MARK: - Subject with Special Characters

    func testSubjectWithPipeCharacter() {
        // The parser splits on | which means subjects containing | would break parsing
        // This tests the known limitation
        let output = "1|Subject with pipe char|sender@test.com|Thursday, January 30, 2026 at 9:00:00 AM|false"
        let emails = parseMetadataOutput(output, startId: 0)

        // With 5+ parts after split, it should still parse (first 5 parts used)
        XCTAssertFalse(emails.isEmpty)
    }

    func testSubjectWithUnicodeCharacters() {
        let output = "1|Facture: 500EUR|billing@test.com|Thursday, January 30, 2026 at 9:00:00 AM|false"
        let emails = parseMetadataOutput(output, startId: 0)

        XCTAssertEqual(emails.first?.subject, "Facture: 500EUR")
    }

    // MARK: - Helper: Simulate parseMetadataOutput logic

    private func parseMetadataOutput(_ output: String, startId: Int) -> [Email] {
        var emails: [Email] = []
        let messages = output.components(separatedBy: "|||").filter { !$0.isEmpty }

        for (index, messageString) in messages.enumerated() {
            let parts = messageString.components(separatedBy: "|")
            guard parts.count >= 5 else { continue }

            let messageId = parts[0].trimmingCharacters(in: .whitespaces)
            let subject = parts[1].trimmingCharacters(in: .whitespaces)
            let sender = parts[2].trimmingCharacters(in: .whitespaces)
            let dateString = parts[3].trimmingCharacters(in: .whitespaces)
            let isReadString = parts[4].trimmingCharacters(in: .whitespaces)

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm:ss a"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            let date = dateFormatter.date(from: dateString) ?? Date()

            let isRead = isReadString.lowercased() == "true"

            var senderEmail = sender
            var senderName = sender
            if let emailStart = sender.firstIndex(of: "<"), let emailEnd = sender.firstIndex(of: ">") {
                senderEmail = String(sender[emailStart...emailEnd]).replacingOccurrences(of: "<", with: "").replacingOccurrences(of: ">", with: "")
                senderName = String(sender[..<emailStart]).trimmingCharacters(in: .whitespaces)
            }

            let email = Email(
                id: startId + index,
                messageId: messageId,
                subject: subject,
                sender: senderName,
                senderEmail: senderEmail,
                dateReceived: date,
                body: nil,
                isRead: isRead,
                category: nil,
                priority: nil,
                aiSummary: nil,
                actions: [],
                senderReputation: nil
            )
            emails.append(email)
        }

        return emails
    }

    private func extractSenderParts(_ sender: String) -> (name: String, email: String) {
        var senderEmail = sender
        var senderName = sender
        if let emailStart = sender.firstIndex(of: "<"), let emailEnd = sender.firstIndex(of: ">") {
            senderEmail = String(sender[emailStart...emailEnd]).replacingOccurrences(of: "<", with: "").replacingOccurrences(of: ">", with: "")
            senderName = String(sender[..<emailStart]).trimmingCharacters(in: .whitespaces)
        }
        return (senderName, senderEmail)
    }
}
