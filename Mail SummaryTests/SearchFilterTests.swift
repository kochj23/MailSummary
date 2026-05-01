//
//  SearchFilterTests.swift
//  Mail SummaryTests
//
//  Tests for SearchFilters, SearchResult, regex presets, and cache key generation
//  Created by Jordan Koch
//

import XCTest
@testable import Mail_Summary

final class SearchFilterTests: XCTestCase {

    // MARK: - SearchFilters Defaults

    func testDefaultFiltersAreInactive() {
        let filters = SearchFilters()

        XCTAssertFalse(filters.isActive)
        XCTAssertTrue(filters.query.isEmpty)
        XCTAssertTrue(filters.categories.isEmpty)
        XCTAssertNil(filters.minPriority)
        XCTAssertNil(filters.maxPriority)
        XCTAssertNil(filters.dateRange)
        XCTAssertFalse(filters.unreadOnly)
        XCTAssertFalse(filters.hasAttachments)
        XCTAssertNil(filters.senderDomain)
        XCTAssertFalse(filters.senderIsVIP)
        XCTAssertFalse(filters.hasActionItems)
        XCTAssertNil(filters.wordCountRange)
        XCTAssertFalse(filters.useRegex)
        XCTAssertNil(filters.regexPattern)
    }

    // MARK: - Filter Activity Detection

    func testFilterIsActiveWithQuery() {
        var filters = SearchFilters()
        filters.query = "test"
        XCTAssertTrue(filters.isActive)
    }

    func testFilterIsActiveWithCategory() {
        var filters = SearchFilters()
        filters.categories = [.work]
        XCTAssertTrue(filters.isActive)
    }

    func testFilterIsActiveWithMinPriority() {
        var filters = SearchFilters()
        filters.minPriority = 7
        XCTAssertTrue(filters.isActive)
    }

    func testFilterIsActiveWithUnreadOnly() {
        var filters = SearchFilters()
        filters.unreadOnly = true
        XCTAssertTrue(filters.isActive)
    }

    func testFilterIsActiveWithRegex() {
        var filters = SearchFilters()
        filters.useRegex = true
        filters.regexPattern = "\\d+"
        XCTAssertTrue(filters.isActive)
    }

    func testFilterNotActiveWithRegexButNoPattern() {
        var filters = SearchFilters()
        filters.useRegex = true
        filters.regexPattern = nil
        XCTAssertFalse(filters.isActive)
    }

    // MARK: - Regex Validation

    func testValidRegexPattern() {
        var filters = SearchFilters()
        filters.useRegex = true
        filters.regexPattern = "\\d{3}-\\d{4}"
        XCTAssertTrue(filters.isValidRegex)
    }

    func testInvalidRegexPattern() {
        var filters = SearchFilters()
        filters.useRegex = true
        filters.regexPattern = "[invalid("
        XCTAssertFalse(filters.isValidRegex)
    }

    func testRegexValidationWhenDisabled() {
        var filters = SearchFilters()
        filters.useRegex = false
        filters.regexPattern = "[invalid("
        XCTAssertTrue(filters.isValidRegex, "Should be valid when regex is disabled")
    }

    func testCompiledRegexReturnsNilWhenDisabled() {
        var filters = SearchFilters()
        filters.useRegex = false
        filters.regexPattern = "\\d+"
        XCTAssertNil(filters.compiledRegex())
    }

    func testCompiledRegexReturnsNSRegularExpression() {
        var filters = SearchFilters()
        filters.useRegex = true
        filters.regexPattern = "test\\d+"
        XCTAssertNotNil(filters.compiledRegex())
    }

    // MARK: - Cache Key

    func testCacheKeyDiffers() {
        var filters1 = SearchFilters()
        filters1.query = "test"

        var filters2 = SearchFilters()
        filters2.query = "other"

        XCTAssertNotEqual(filters1.cacheKey(), filters2.cacheKey())
    }

    func testCacheKeyConsistentForSameFilters() {
        var filters = SearchFilters()
        filters.query = "test"
        filters.categories = [.work, .bills]
        filters.unreadOnly = true

        let key1 = filters.cacheKey()
        let key2 = filters.cacheKey()

        XCTAssertEqual(key1, key2)
    }

    // MARK: - Filter Equality

    func testFilterEquality() {
        var f1 = SearchFilters()
        f1.query = "test"
        f1.categories = [.work]
        f1.unreadOnly = true

        var f2 = SearchFilters()
        f2.query = "test"
        f2.categories = [.work]
        f2.unreadOnly = true

        XCTAssertEqual(f1, f2)
    }

    func testFilterInequalityOnQuery() {
        var f1 = SearchFilters()
        f1.query = "test"

        var f2 = SearchFilters()
        f2.query = "other"

        XCTAssertNotEqual(f1, f2)
    }

    // MARK: - Preset Filters

    func testBillsDueThisWeekPreset() {
        let preset = SearchFilters.billsDueThisWeek

        XCTAssertTrue(preset.categories.contains(.bills))
        XCTAssertNotNil(preset.dateRange)
        XCTAssertEqual(preset.presetName, "Bills Due This Week")
    }

    func testUrgentUnreadPreset() {
        let preset = SearchFilters.urgentUnread

        XCTAssertTrue(preset.unreadOnly)
        XCTAssertEqual(preset.minPriority, 8)
        XCTAssertEqual(preset.presetName, "Urgent Unread")
    }

    func testFromVIPsPreset() {
        let preset = SearchFilters.fromVIPs

        XCTAssertTrue(preset.senderIsVIP)
        XCTAssertEqual(preset.presetName, "From VIPs")
    }

    // MARK: - RegexPreset

    func testAllRegexPresetsHavePatterns() {
        for preset in RegexPreset.allCases {
            XCTAssertFalse(preset.pattern.isEmpty, "\(preset.rawValue) should have a regex pattern")
        }
    }

    func testAllRegexPresetsHaveDescriptions() {
        for preset in RegexPreset.allCases {
            XCTAssertFalse(preset.description.isEmpty, "\(preset.rawValue) should have a description")
        }
    }

    func testAllRegexPresetsHaveIcons() {
        for preset in RegexPreset.allCases {
            XCTAssertFalse(preset.icon.isEmpty, "\(preset.rawValue) should have an icon")
        }
    }

    func testRegexPresetsAreValid() {
        for preset in RegexPreset.allCases {
            let regex = try? NSRegularExpression(pattern: preset.pattern, options: [.caseInsensitive])
            XCTAssertNotNil(regex, "\(preset.rawValue) pattern should be valid regex: \(preset.pattern)")
        }
    }

    func testEmailRegexMatchesEmail() {
        let pattern = RegexPreset.emailAddress.pattern
        let regex = try! NSRegularExpression(pattern: pattern)
        let text = "Contact user@example.com for details"
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        XCTAssertEqual(matches.count, 1)
    }

    func testDollarAmountRegexMatchesAmount() {
        let pattern = RegexPreset.dollarAmount.pattern
        let regex = try! NSRegularExpression(pattern: pattern)
        let text = "Total: $1,234.56"
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        XCTAssertEqual(matches.count, 1)
    }

    // MARK: - EmailActionType

    func testEmailActionTypeDisplayNames() {
        XCTAssertEqual(EmailActionType.delete.displayName, "Delete")
        XCTAssertEqual(EmailActionType.archive.displayName, "Archive")
        XCTAssertEqual(EmailActionType.markRead.displayName, "Mark Read")
        XCTAssertEqual(EmailActionType.markUnread.displayName, "Mark Unread")
        XCTAssertEqual(EmailActionType.reply.displayName, "Reply")
        XCTAssertEqual(EmailActionType.forward.displayName, "Forward")
        XCTAssertEqual(EmailActionType.move(mailbox: "Inbox").displayName, "Move to Inbox")
    }

    func testEmailActionTypeIcons() {
        for actionType in [EmailActionType.delete, .archive, .markRead, .markUnread, .toggleRead, .reply, .forward, .move(mailbox: "Inbox")] {
            XCTAssertFalse(actionType.icon.isEmpty, "\(actionType.displayName) should have an icon")
        }
    }

    // MARK: - EmailActionResult

    func testActionResultSuccess() {
        let result = EmailActionResult.success
        XCTAssertTrue(result.isSuccess)
        XCTAssertNil(result.errorMessage)
    }

    func testActionResultFailure() {
        let result = EmailActionResult.failure("Network error")
        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.errorMessage, "Network error")
    }

    func testActionResultNotSupported() {
        let result = EmailActionResult.notSupported
        XCTAssertFalse(result.isSuccess)
        XCTAssertNil(result.errorMessage)
    }
}
