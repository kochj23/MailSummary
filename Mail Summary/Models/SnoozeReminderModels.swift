//
//  SnoozeReminderModels.swift
//  Mail Summary
//
//  Data models for snooze and reminder functionality
//  Created by Jordan Koch on 2026-01-23
//

import Foundation

// MARK: - Snoozed Email Record

/// Represents an email that has been snoozed until a specific time
struct SnoozedEmail: Identifiable, Codable {
    let id: UUID
    let emailId: Int              // Email.id reference
    let messageId: String          // Mail.app message ID for re-fetching
    let emailSubject: String       // Cached for display
    let senderEmail: String        // Cached for display
    let snoozeUntil: Date          // When to show the email again
    let createdAt: Date            // When snooze was set

    /// Check if this snooze has expired and should be shown again
    var isExpired: Bool {
        Date() >= snoozeUntil
    }

    /// Time remaining until unsnooze
    var timeRemaining: TimeInterval {
        snoozeUntil.timeIntervalSinceNow
    }
}

// MARK: - Email Reminder

/// Represents a reminder set for an email
struct EmailReminder: Identifiable, Codable {
    let id: UUID
    let emailId: Int              // Email.id reference
    let messageId: String          // Mail.app message ID
    let emailSubject: String       // Cached for display
    let remindAt: Date             // When to trigger the reminder
    let note: String?              // Optional user note about the reminder
    let reminderType: ReminderType // Type of reminder
    let createdAt: Date            // When reminder was set
    var isCompleted: Bool          // Whether user has addressed this reminder

    /// Check if this reminder should be shown now
    var isReady: Bool {
        Date() >= remindAt && !isCompleted
    }

    /// Time remaining until reminder triggers
    var timeRemaining: TimeInterval {
        remindAt.timeIntervalSinceNow
    }

    /// Reminder type categories
    enum ReminderType: String, Codable, CaseIterable {
        case followUp = "Follow Up"
        case callback = "Callback"
        case deadline = "Deadline"
        case priority = "Priority"
        case custom = "Custom"

        var icon: String {
            switch self {
            case .followUp: return "arrow.turn.up.right"
            case .callback: return "phone.fill"
            case .deadline: return "clock.fill"
            case .priority: return "exclamationmark.triangle.fill"
            case .custom: return "bell.fill"
            }
        }
    }
}

// MARK: - Email Action Result

/// Result of performing an email action (delete, archive, etc.)
enum EmailActionResult {
    case success
    case failure(String)
    case notSupported

    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    var errorMessage: String? {
        if case .failure(let message) = self {
            return message
        }
        return nil
    }
}

// MARK: - Email Action Types

/// Types of actions that can be performed on emails
enum EmailActionType: Equatable {
    case delete
    case archive
    case markRead
    case markUnread
    case toggleRead
    case reply
    case forward
    case move(mailbox: String)

    var displayName: String {
        switch self {
        case .delete: return "Delete"
        case .archive: return "Archive"
        case .markRead: return "Mark Read"
        case .markUnread: return "Mark Unread"
        case .toggleRead: return "Toggle Read"
        case .reply: return "Reply"
        case .forward: return "Forward"
        case .move(let mailbox): return "Move to \(mailbox)"
        }
    }

    var icon: String {
        switch self {
        case .delete: return "trash.fill"
        case .archive: return "archivebox.fill"
        case .markRead: return "envelope.open.fill"
        case .markUnread: return "envelope.badge.fill"
        case .toggleRead: return "envelope.fill"
        case .reply: return "arrowshape.turn.up.left.fill"
        case .forward: return "arrowshape.turn.up.right.fill"
        case .move: return "folder.fill"
        }
    }
}

// MARK: - Search Result

/// Search result wrapper with relevance scoring
struct SearchResult: Identifiable {
    let id: Int                    // Email.id
    let email: Email
    let relevanceScore: Double      // 0.0-1.0
    let matchedText: String         // Preview of matched content
    let matchedFields: Set<String>  // Which fields matched: "subject", "sender", "body"
}

// MARK: - Search Filters

/// Search and filter criteria
struct SearchFilters: Equatable {
    var query: String = ""
    var categories: Set<Email.EmailCategory> = []
    var minPriority: Int? = nil
    var maxPriority: Int? = nil
    var dateRange: (Date, Date)? = nil
    var unreadOnly: Bool = false
    var hasAttachments: Bool = false

    // Advanced filters (Feature 2)
    var senderDomain: String? = nil
    var senderIsVIP: Bool = false
    var hasActionItems: Bool = false
    var wordCountRange: (min: Int, max: Int)? = nil
    var presetName: String? = nil  // For saved filter presets

    // Regex search (NEW)
    var useRegex: Bool = false
    var regexPattern: String? = nil  // Compiled regex pattern

    /// Check if any filters are active
    var isActive: Bool {
        !query.isEmpty || !categories.isEmpty || minPriority != nil ||
        maxPriority != nil || dateRange != nil || unreadOnly || hasAttachments ||
        senderDomain != nil || senderIsVIP || hasActionItems || wordCountRange != nil ||
        (useRegex && regexPattern != nil)
    }

    /// Validate regex pattern
    var isValidRegex: Bool {
        guard useRegex, let pattern = regexPattern, !pattern.isEmpty else { return true }
        do {
            _ = try NSRegularExpression(pattern: pattern, options: [])
            return true
        } catch {
            return false
        }
    }

    /// Get compiled regex (nil if invalid or not using regex)
    func compiledRegex() -> NSRegularExpression? {
        guard useRegex, let pattern = regexPattern, !pattern.isEmpty else { return nil }
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    /// Generate cache key for search results
    func cacheKey() -> String {
        let categoriesStr = categories.map { $0.rawValue }.sorted().joined(separator: ",")
        let minPriStr = minPriority.map { String($0) } ?? "nil"
        let maxPriStr = maxPriority.map { String($0) } ?? "nil"
        let dateStr = dateRange.map { "\($0.0.timeIntervalSince1970)-\($0.1.timeIntervalSince1970)" } ?? "nil"
        let domainStr = senderDomain ?? "nil"
        let wordRangeStr = wordCountRange.map { "\($0.min)-\($0.max)" } ?? "nil"
        let regexStr = useRegex ? (regexPattern ?? "nil") : "noregex"
        return "\(query)|\(categoriesStr)|\(minPriStr)|\(maxPriStr)|\(dateStr)|\(unreadOnly)|\(hasAttachments)|\(domainStr)|\(senderIsVIP)|\(hasActionItems)|\(wordRangeStr)|\(regexStr)"
    }

    static func == (lhs: SearchFilters, rhs: SearchFilters) -> Bool {
        lhs.query == rhs.query &&
        lhs.categories == rhs.categories &&
        lhs.minPriority == rhs.minPriority &&
        lhs.maxPriority == rhs.maxPriority &&
        lhs.unreadOnly == rhs.unreadOnly &&
        lhs.hasAttachments == rhs.hasAttachments &&
        lhs.senderDomain == rhs.senderDomain &&
        lhs.senderIsVIP == rhs.senderIsVIP &&
        lhs.hasActionItems == rhs.hasActionItems &&
        lhs.wordCountRange?.min == rhs.wordCountRange?.min &&
        lhs.wordCountRange?.max == rhs.wordCountRange?.max &&
        lhs.useRegex == rhs.useRegex &&
        lhs.regexPattern == rhs.regexPattern
    }

    // Quick filter presets
    static var billsDueThisWeek: SearchFilters {
        var filters = SearchFilters()
        filters.categories = [.bills]
        filters.dateRange = (Date(), Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date())
        filters.presetName = "Bills Due This Week"
        return filters
    }

    static var urgentUnread: SearchFilters {
        var filters = SearchFilters()
        filters.unreadOnly = true
        filters.minPriority = 8
        filters.presetName = "Urgent Unread"
        return filters
    }

    static var fromVIPs: SearchFilters {
        var filters = SearchFilters()
        filters.senderIsVIP = true
        filters.presetName = "From VIPs"
        return filters
    }
}

// MARK: - Regex Presets

/// Common regex patterns for email search
enum RegexPreset: String, CaseIterable {
    case emailAddress = "Email Addresses"
    case phoneNumber = "Phone Numbers"
    case url = "URLs"
    case dollarAmount = "Dollar Amounts"
    case date = "Dates"
    case trackingNumber = "Tracking Numbers"
    case orderNumber = "Order Numbers"

    var pattern: String {
        switch self {
        case .emailAddress:
            return #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        case .phoneNumber:
            return #"(\+?1?[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}"#
        case .url:
            return #"https?://[^\s<>\"{}|\\^`\[\]]+"#
        case .dollarAmount:
            return #"\$[\d,]+\.?\d{0,2}"#
        case .date:
            return #"\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\w+ \d{1,2},? \d{4}"#
        case .trackingNumber:
            return #"(?:1Z[A-Z0-9]{16}|[0-9]{12,22}|\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4})"#
        case .orderNumber:
            return #"(?:order|#|confirmation)\s*(?:number|#|:)?\s*([A-Z0-9-]{6,})"#
        }
    }

    var description: String {
        switch self {
        case .emailAddress:
            return "Find email addresses (name@domain.com)"
        case .phoneNumber:
            return "Find phone numbers (various formats)"
        case .url:
            return "Find web URLs (http/https)"
        case .dollarAmount:
            return "Find dollar amounts ($X.XX)"
        case .date:
            return "Find dates (MM/DD/YYYY, Month Day, Year)"
        case .trackingNumber:
            return "Find shipping tracking numbers"
        case .orderNumber:
            return "Find order/confirmation numbers"
        }
    }

    var icon: String {
        switch self {
        case .emailAddress: return "envelope"
        case .phoneNumber: return "phone"
        case .url: return "link"
        case .dollarAmount: return "dollarsign.circle"
        case .date: return "calendar"
        case .trackingNumber: return "shippingbox"
        case .orderNumber: return "number"
        }
    }
}
