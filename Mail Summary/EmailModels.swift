//
//  EmailModels.swift  
//  Mail Summary
//
//  Email data structures
//  Created by Jordan Koch on 2026-01-22
//

import Foundation

struct Email: Identifiable, Codable {
    let id: Int
    let subject: String
    let sender: String
    let senderEmail: String
    let dateReceived: Date
    let body: String
    var isRead: Bool
    var category: EmailCategory?
    var priority: Int?  // 1-10
    var aiSummary: String?
    var actions: [EmailAction]
    var senderReputation: Double?  // 0-1

    enum EmailCategory: String, Codable, CaseIterable {
        case bills = "Bills"
        case orders = "Orders"
        case work = "Work"
        case personal = "Personal"
        case marketing = "Marketing"
        case newsletters = "Newsletters"
        case social = "Social"
        case spam = "Spam"
        case other = "Other"

        var icon: String {
            switch self {
            case .bills: return "dollarsign.circle.fill"
            case .orders: return "shippingbox.fill"
            case .work: return "briefcase.fill"
            case .personal: return "person.fill"
            case .marketing: return "megaphone.fill"
            case .newsletters: return "newspaper.fill"
            case .social: return "bubble.left.and.bubble.right.fill"
            case .spam: return "trash.fill"
            case .other: return "envelope.fill"
            }
        }

        var color: String {
            switch self {
            case .bills: return "red"
            case .orders: return "green"
            case .work: return "blue"
            case .personal: return "cyan"
            case .marketing: return "orange"
            case .newsletters: return "purple"
            case .social: return "pink"
            case .spam: return "gray"
            case .other: return "yellow"
            }
        }
    }
}

struct EmailAction: Identifiable, Codable {
    let id = UUID()
    let type: ActionType
    let text: String
    let date: Date?

    enum ActionType: String, Codable {
        case deadline, meeting, task, reminder
    }
}

struct CategorySummary: Identifiable {
    let id = UUID()
    let category: Email.EmailCategory
    let count: Int
    let unreadCount: Int
    let highPriorityCount: Int
    let aiSummary: String?
}

struct MailboxStats {
    let totalEmails: Int
    let unreadEmails: Int
    let todayEmails: Int
    let highPriorityEmails: Int
    let actionsCount: Int
}
