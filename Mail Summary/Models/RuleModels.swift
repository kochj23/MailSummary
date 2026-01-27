//
//  RuleModels.swift
//  Mail Summary
//
//  Smart Rules Engine - Data Models
//  Created by Jordan Koch on 2026-01-26
//
//  Defines rule structures for automated email actions based on conditions.
//  Rules are evaluated after AI categorization and can modify email properties or trigger actions.
//

import Foundation

// Forward reference to Email.EmailCategory
typealias EmailCategory = Email.EmailCategory

// MARK: - Email Rule

struct EmailRule: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var isEnabled: Bool
    var conditions: [RuleCondition]
    var actions: [RuleAction]
    var priority: Int  // Higher priority runs first (1-100)
    var matchType: MatchType  // all, any
    var createdAt: Date
    var lastModified: Date
    var executionCount: Int  // Track how many times rule has fired

    enum MatchType: String, Codable {
        case all  // AND - all conditions must match
        case any  // OR - any condition can match

        var displayName: String {
            switch self {
            case .all: return "All"
            case .any: return "Any"
            }
        }
    }

    init(id: UUID = UUID(), name: String, isEnabled: Bool = true,
         conditions: [RuleCondition], actions: [RuleAction], priority: Int = 50,
         matchType: MatchType = .all) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.conditions = conditions
        self.actions = actions
        self.priority = priority
        self.matchType = matchType
        self.createdAt = Date()
        self.lastModified = Date()
        self.executionCount = 0
    }

    var isValid: Bool {
        !name.isEmpty && !conditions.isEmpty && !actions.isEmpty
    }

    var description: String {
        let conditionsStr = conditions.count == 1 ? "1 condition" : "\(conditions.count) conditions"
        let actionsStr = actions.count == 1 ? "1 action" : "\(actions.count) actions"
        return "\(conditionsStr), \(actionsStr)"
    }
}

// MARK: - Rule Condition

struct RuleCondition: Identifiable, Codable, Equatable {
    let id: UUID
    var type: ConditionType

    init(id: UUID = UUID(), type: ConditionType) {
        self.id = id
        self.type = type
    }

    // Manual Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ConditionType.self, forKey: .type)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
    }

    enum ConditionType: Equatable {
        case senderContains(String)
        case senderIs(String)
        case senderDomain(String)
        case subjectContains(String)
        case bodyContains(String)
        case categoryIs(EmailCategory)
        case priorityGreaterThan(Int)
        case priorityLessThan(Int)
        case ageGreaterThan(days: Int)
        case ageLessThan(days: Int)
        case hasAttachment
        case isUnread
        case isRead
        case hasActionItems
        case senderIsVIP

        var displayName: String {
            switch self {
            case .senderContains(let text):
                return "Sender contains '\(text)'"
            case .senderIs(let email):
                return "Sender is '\(email)'"
            case .senderDomain(let domain):
                return "Sender domain is '\(domain)'"
            case .subjectContains(let text):
                return "Subject contains '\(text)'"
            case .bodyContains(let text):
                return "Body contains '\(text)'"
            case .categoryIs(let category):
                return "Category is \(category.rawValue)"
            case .priorityGreaterThan(let value):
                return "Priority > \(value)"
            case .priorityLessThan(let value):
                return "Priority < \(value)"
            case .ageGreaterThan(let days):
                return "Older than \(days) day\(days == 1 ? "" : "s")"
            case .ageLessThan(let days):
                return "Newer than \(days) day\(days == 1 ? "" : "s")"
            case .hasAttachment:
                return "Has attachment"
            case .isUnread:
                return "Is unread"
            case .isRead:
                return "Is read"
            case .hasActionItems:
                return "Has action items"
            case .senderIsVIP:
                return "Sender is VIP"
            }
        }

        var icon: String {
            switch self {
            case .senderContains, .senderIs, .senderDomain:
                return "person.fill"
            case .subjectContains:
                return "text.justify.left"
            case .bodyContains:
                return "doc.text"
            case .categoryIs:
                return "folder.fill"
            case .priorityGreaterThan, .priorityLessThan:
                return "exclamationmark.triangle.fill"
            case .ageGreaterThan, .ageLessThan:
                return "clock.fill"
            case .hasAttachment:
                return "paperclip"
            case .isUnread:
                return "envelope.badge.fill"
            case .isRead:
                return "envelope.open.fill"
            case .hasActionItems:
                return "checkmark.circle.fill"
            case .senderIsVIP:
                return "star.fill"
            }
        }
    }
}

// MARK: - Rule Action

struct RuleAction: Identifiable, Codable, Equatable {
    let id: UUID
    var type: ActionType

    init(id: UUID = UUID(), type: ActionType) {
        self.id = id
        self.type = type
    }

    // Manual Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ActionType.self, forKey: .type)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
    }

    enum ActionType: Equatable {
        case categorize(EmailCategory)
        case setPriority(Int)
        case delete
        case archive
        case markRead
        case markUnread
        case move(to: String)
        case snooze(until: Date)
        case addTag(String)
        case notify(String)  // Show notification with message
        case stopProcessing  // Don't run any more rules

        var displayName: String {
            switch self {
            case .categorize(let category):
                return "Categorize as \(category.rawValue)"
            case .setPriority(let value):
                return "Set priority to \(value)"
            case .delete:
                return "Delete"
            case .archive:
                return "Archive"
            case .markRead:
                return "Mark as read"
            case .markUnread:
                return "Mark as unread"
            case .move(let mailbox):
                return "Move to '\(mailbox)'"
            case .snooze(let date):
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                return "Snooze until \(formatter.string(from: date))"
            case .addTag(let tag):
                return "Add tag '\(tag)'"
            case .notify(let message):
                return "Notify: \(message)"
            case .stopProcessing:
                return "Stop processing rules"
            }
        }

        var icon: String {
            switch self {
            case .categorize:
                return "folder.fill"
            case .setPriority:
                return "exclamationmark.triangle.fill"
            case .delete:
                return "trash.fill"
            case .archive:
                return "archivebox.fill"
            case .markRead:
                return "envelope.open.fill"
            case .markUnread:
                return "envelope.badge.fill"
            case .move:
                return "arrow.right.square.fill"
            case .snooze:
                return "moon.fill"
            case .addTag:
                return "tag.fill"
            case .notify:
                return "bell.fill"
            case .stopProcessing:
                return "stop.fill"
            }
        }

        var isDestructive: Bool {
            switch self {
            case .delete:
                return true
            default:
                return false
            }
        }
    }
}

// MARK: - Rule Execution Result

struct RuleExecutionResult {
    let ruleId: UUID
    let ruleName: String
    let matched: Bool
    let actionsExecuted: Int
    let errors: [String]
    let executionTime: TimeInterval

    var isSuccess: Bool {
        errors.isEmpty
    }
}

// MARK: - Rule Statistics

struct RuleStatistics: Codable {
    var totalRules: Int
    var enabledRules: Int
    var totalExecutions: Int
    var successfulExecutions: Int
    var failedExecutions: Int
    var lastExecutionDate: Date?
    var avgExecutionTime: TimeInterval

    var successRate: Double {
        guard totalExecutions > 0 else { return 0.0 }
        return Double(successfulExecutions) / Double(totalExecutions)
    }
}

// MARK: - Codable Conformance for Enums

extension RuleCondition.ConditionType: Codable {
    enum CodingKeys: String, CodingKey {
        case type, value, days, category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "senderContains":
            let value = try container.decode(String.self, forKey: .value)
            self = .senderContains(value)
        case "senderIs":
            let value = try container.decode(String.self, forKey: .value)
            self = .senderIs(value)
        case "senderDomain":
            let value = try container.decode(String.self, forKey: .value)
            self = .senderDomain(value)
        case "subjectContains":
            let value = try container.decode(String.self, forKey: .value)
            self = .subjectContains(value)
        case "bodyContains":
            let value = try container.decode(String.self, forKey: .value)
            self = .bodyContains(value)
        case "categoryIs":
            let category = try container.decode(EmailCategory.self, forKey: .category)
            self = .categoryIs(category)
        case "priorityGreaterThan":
            let value = try container.decode(Int.self, forKey: .value)
            self = .priorityGreaterThan(value)
        case "priorityLessThan":
            let value = try container.decode(Int.self, forKey: .value)
            self = .priorityLessThan(value)
        case "ageGreaterThan":
            let days = try container.decode(Int.self, forKey: .days)
            self = .ageGreaterThan(days: days)
        case "ageLessThan":
            let days = try container.decode(Int.self, forKey: .days)
            self = .ageLessThan(days: days)
        case "hasAttachment":
            self = .hasAttachment
        case "isUnread":
            self = .isUnread
        case "isRead":
            self = .isRead
        case "hasActionItems":
            self = .hasActionItems
        case "senderIsVIP":
            self = .senderIsVIP
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown condition type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .senderContains(let value):
            try container.encode("senderContains", forKey: .type)
            try container.encode(value, forKey: .value)
        case .senderIs(let value):
            try container.encode("senderIs", forKey: .type)
            try container.encode(value, forKey: .value)
        case .senderDomain(let value):
            try container.encode("senderDomain", forKey: .type)
            try container.encode(value, forKey: .value)
        case .subjectContains(let value):
            try container.encode("subjectContains", forKey: .type)
            try container.encode(value, forKey: .value)
        case .bodyContains(let value):
            try container.encode("bodyContains", forKey: .type)
            try container.encode(value, forKey: .value)
        case .categoryIs(let category):
            try container.encode("categoryIs", forKey: .type)
            try container.encode(category, forKey: .category)
        case .priorityGreaterThan(let value):
            try container.encode("priorityGreaterThan", forKey: .type)
            try container.encode(value, forKey: .value)
        case .priorityLessThan(let value):
            try container.encode("priorityLessThan", forKey: .type)
            try container.encode(value, forKey: .value)
        case .ageGreaterThan(let days):
            try container.encode("ageGreaterThan", forKey: .type)
            try container.encode(days, forKey: .days)
        case .ageLessThan(let days):
            try container.encode("ageLessThan", forKey: .type)
            try container.encode(days, forKey: .days)
        case .hasAttachment:
            try container.encode("hasAttachment", forKey: .type)
        case .isUnread:
            try container.encode("isUnread", forKey: .type)
        case .isRead:
            try container.encode("isRead", forKey: .type)
        case .hasActionItems:
            try container.encode("hasActionItems", forKey: .type)
        case .senderIsVIP:
            try container.encode("senderIsVIP", forKey: .type)
        }
    }
}

extension RuleAction.ActionType: Codable {
    enum CodingKeys: String, CodingKey {
        case type, value, category, mailbox, date, tag, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "categorize":
            let category = try container.decode(EmailCategory.self, forKey: .category)
            self = .categorize(category)
        case "setPriority":
            let value = try container.decode(Int.self, forKey: .value)
            self = .setPriority(value)
        case "delete":
            self = .delete
        case "archive":
            self = .archive
        case "markRead":
            self = .markRead
        case "markUnread":
            self = .markUnread
        case "move":
            let mailbox = try container.decode(String.self, forKey: .mailbox)
            self = .move(to: mailbox)
        case "snooze":
            let date = try container.decode(Date.self, forKey: .date)
            self = .snooze(until: date)
        case "addTag":
            let tag = try container.decode(String.self, forKey: .tag)
            self = .addTag(tag)
        case "notify":
            let message = try container.decode(String.self, forKey: .message)
            self = .notify(message)
        case "stopProcessing":
            self = .stopProcessing
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown action type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .categorize(let category):
            try container.encode("categorize", forKey: .type)
            try container.encode(category, forKey: .category)
        case .setPriority(let value):
            try container.encode("setPriority", forKey: .type)
            try container.encode(value, forKey: .value)
        case .delete:
            try container.encode("delete", forKey: .type)
        case .archive:
            try container.encode("archive", forKey: .type)
        case .markRead:
            try container.encode("markRead", forKey: .type)
        case .markUnread:
            try container.encode("markUnread", forKey: .type)
        case .move(let mailbox):
            try container.encode("move", forKey: .type)
            try container.encode(mailbox, forKey: .mailbox)
        case .snooze(let date):
            try container.encode("snooze", forKey: .type)
            try container.encode(date, forKey: .date)
        case .addTag(let tag):
            try container.encode("addTag", forKey: .type)
            try container.encode(tag, forKey: .tag)
        case .notify(let message):
            try container.encode("notify", forKey: .type)
            try container.encode(message, forKey: .message)
        case .stopProcessing:
            try container.encode("stopProcessing", forKey: .type)
        }
    }
}
