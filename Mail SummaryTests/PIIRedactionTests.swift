//
//  PIIRedactionTests.swift
//  Mail SummaryTests
//
//  Tests for PII detection, redaction, credit card Luhn validation, and SSN patterns
//  Created by Jordan Koch
//

import XCTest
@testable import Mail_Summary

@MainActor
final class PIIRedactionTests: XCTestCase {

    var manager: PIIRedactionManager!

    override func setUp() {
        super.setUp()
        manager = PIIRedactionManager.shared
        manager.enabledTypes = Set(PIIType.allCases.filter { $0 != .custom })
    }

    // MARK: - Email Address Detection

    func testDetectsEmailAddress() {
        let result = manager.scanText("Contact me at user@example.com for details")
        let emailMatches = result.matches.filter { $0.type == .email }

        XCTAssertFalse(emailMatches.isEmpty, "Should detect email address")
        XCTAssertEqual(emailMatches.first?.matchedText, "user@example.com")
    }

    func testDetectsMultipleEmailAddresses() {
        let text = "From: alice@company.com To: bob@other.org CC: carol@test.net"
        let result = manager.scanText(text)
        let emailMatches = result.matches.filter { $0.type == .email }

        XCTAssertEqual(emailMatches.count, 3, "Should detect 3 email addresses")
    }

    func testRedactsEmailAddress() {
        let result = manager.scanText("Email me at user@example.com today")

        XCTAssertTrue(result.redactedText.contains("[EMAIL REDACTED]"))
        XCTAssertFalse(result.redactedText.contains("user@example.com"))
    }

    // MARK: - Phone Number Detection

    func testDetectsPhoneNumber() {
        let result = manager.scanText("Call me at (555) 123-4567")
        let phoneMatches = result.matches.filter { $0.type == .phone }

        XCTAssertFalse(phoneMatches.isEmpty, "Should detect phone number")
    }

    func testDetectsPhoneNumberDashFormat() {
        let result = manager.scanText("Phone: 555-123-4567")
        let phoneMatches = result.matches.filter { $0.type == .phone }

        XCTAssertFalse(phoneMatches.isEmpty, "Should detect dash-formatted phone number")
    }

    func testRedactsPhoneNumber() {
        let result = manager.scanText("Call 555-123-4567 now")

        XCTAssertTrue(result.redactedText.contains("[PHONE REDACTED]"))
    }

    // MARK: - SSN Detection

    func testDetectsSSN() {
        let result = manager.scanText("SSN: 123-45-6789")
        let ssnMatches = result.matches.filter { $0.type == .ssn }

        XCTAssertFalse(ssnMatches.isEmpty, "Should detect SSN pattern")
    }

    func testSSNWithInvalidPrefix000() {
        let result = manager.scanText("Number: 000-12-3456")
        let ssnMatches = result.matches.filter { $0.type == .ssn }

        // SSNs starting with 000 should have low confidence (< 0.5) and be filtered
        // The validator returns 0.3 for 000 prefix which is below 0.5 threshold
        let highConfidenceMatches = ssnMatches.filter { $0.confidence > 0.5 }
        XCTAssertTrue(highConfidenceMatches.isEmpty, "SSN starting with 000 should be low confidence")
    }

    func testSSNWithInvalidPrefix666() {
        let result = manager.scanText("Number: 666-12-3456")
        let ssnMatches = result.matches.filter { $0.type == .ssn }

        let highConfidenceMatches = ssnMatches.filter { $0.confidence > 0.5 }
        XCTAssertTrue(highConfidenceMatches.isEmpty, "SSN starting with 666 should be low confidence")
    }

    // MARK: - Credit Card Detection

    func testDetectsValidCreditCard() {
        // 4111111111111111 is a known Luhn-valid test number
        let result = manager.scanText("Card: 4111 1111 1111 1111")
        let cardMatches = result.matches.filter { $0.type == .creditCard }

        XCTAssertFalse(cardMatches.isEmpty, "Should detect credit card number")
    }

    func testRedactsCreditCard() {
        let result = manager.scanText("Pay with 4111-1111-1111-1111")

        XCTAssertTrue(result.redactedText.contains("[CARD REDACTED]"))
        XCTAssertFalse(result.redactedText.contains("4111"))
    }

    // MARK: - Address Detection

    func testDetectsStreetAddress() {
        let result = manager.scanText("Office at 123 Main Street")
        let addrMatches = result.matches.filter { $0.type == .address }

        XCTAssertFalse(addrMatches.isEmpty, "Should detect street address")
    }

    func testDetectsAvenueAddress() {
        let result = manager.scanText("Located at 456 Park Avenue")
        let addrMatches = result.matches.filter { $0.type == .address }

        XCTAssertFalse(addrMatches.isEmpty, "Should detect avenue address")
    }

    // MARK: - Name Detection

    func testDetectsCommonFirstName() {
        manager.enabledTypes.insert(.name)
        let result = manager.scanText("Meeting with James tomorrow")
        let nameMatches = result.matches.filter { $0.type == .name }

        XCTAssertFalse(nameMatches.isEmpty, "Should detect common first name")
    }

    func testDetectsCommonLastName() {
        manager.enabledTypes.insert(.name)
        let result = manager.scanText("Contact Smith for details")
        let nameMatches = result.matches.filter { $0.type == .name }

        XCTAssertFalse(nameMatches.isEmpty, "Should detect common last name")
    }

    // MARK: - No PII in Clean Text

    func testNoPIIInCleanText() {
        let result = manager.scanText("The weather today is sunny and warm.")

        XCTAssertFalse(result.hasPII, "Clean text should have no PII")
        XCTAssertEqual(result.piiCount, 0)
    }

    // MARK: - Email Scanning

    func testScanEmailCombinesSubjectAndBody() {
        let email = makeEmail(
            subject: "Invoice from user@company.com",
            body: "Call 555-123-4567 for payment"
        )
        let result = manager.scanEmail(email)

        XCTAssertTrue(result.hasPII)
        let types = Set(result.matches.map { $0.type })
        XCTAssertTrue(types.contains(.email), "Should detect email in subject")
        XCTAssertTrue(types.contains(.phone), "Should detect phone in body")
    }

    func testScanEmailWithNoBody() {
        let email = makeEmail(subject: "Plain subject", body: nil)
        let result = manager.scanEmail(email)

        XCTAssertFalse(result.hasPII, "Email with plain subject and no body should have no PII")
    }

    // MARK: - PIIMatch Display

    func testEmailDisplayPartialRedaction() {
        let match = PIIMatch(
            type: .email,
            matchedText: "john.doe@example.com",
            range: "test".startIndex..<"test".endIndex,
            confidence: 0.9
        )

        // Should show first 2 chars of local part + *** + domain
        XCTAssertTrue(match.displayText.hasPrefix("jo"))
        XCTAssertTrue(match.displayText.contains("***"))
        XCTAssertTrue(match.displayText.contains("@example.com"))
    }

    func testPhoneDisplayPartialRedaction() {
        let match = PIIMatch(
            type: .phone,
            matchedText: "555-123-4567",
            range: "test".startIndex..<"test".endIndex,
            confidence: 0.9
        )

        XCTAssertTrue(match.displayText.hasSuffix("4567"), "Should show last 4 digits of phone")
        XCTAssertTrue(match.displayText.contains("***"))
    }

    func testSSNDisplayPartialRedaction() {
        let match = PIIMatch(
            type: .ssn,
            matchedText: "123-45-6789",
            range: "test".startIndex..<"test".endIndex,
            confidence: 0.95
        )

        XCTAssertTrue(match.displayText.hasSuffix("6789"), "Should show last 4 digits of SSN")
        XCTAssertTrue(match.displayText.hasPrefix("***"))
    }

    // MARK: - PIIType Properties

    func testAllTypesHaveIcons() {
        for type in PIIType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "\(type.rawValue) should have an icon")
        }
    }

    func testAllTypesHavePlaceholders() {
        for type in PIIType.allCases {
            XCTAssertTrue(type.redactionPlaceholder.contains("REDACTED"), "\(type.rawValue) placeholder should contain REDACTED")
        }
    }

    func testAllTypesHaveDescriptions() {
        for type in PIIType.allCases {
            XCTAssertFalse(type.description.isEmpty, "\(type.rawValue) should have a description")
        }
    }

    // MARK: - Count Statistics

    func testCountByType() {
        let text = "Email user@test.com and call 555-123-4567. Also contact admin@test.com."
        let _ = manager.scanText(text)

        // scanText doesn't store in lastScanResults, scanEmail does
        let email = makeEmail(subject: text, body: nil)
        let _ = manager.scanEmail(email)

        let counts = manager.countByType()
        XCTAssertTrue((counts[.email] ?? 0) >= 2, "Should count multiple emails")
    }

    // MARK: - Helpers

    private func makeEmail(subject: String, body: String?) -> Email {
        Email(
            id: 1, messageId: "msg-1", subject: subject, sender: "Test",
            senderEmail: "test@test.com", dateReceived: Date(), body: body,
            isRead: false, category: nil, priority: nil, aiSummary: nil,
            actions: [], senderReputation: nil
        )
    }
}
