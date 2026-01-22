//
//  AICategorizationEngine.swift
//  Mail Summary
//
//  AI-powered email categorization and analysis
//  Uses same AIBackendManager as TopGUI/GTNW
//  Created by Jordan Koch on 2026-01-22
//

import Foundation

@MainActor
class AICategorizationEngine {
    // TODO: Copy AIBackendManager from TopGUI
    // private let ai = AIBackendManager.shared

    func categorizeEmail(_ email: Email) async -> Email.EmailCategory {
        // TODO: AI categorization
        // For now, use simple keyword matching
        let subject = email.subject.lowercased()
        let sender = email.sender.lowercased()

        if subject.contains("bill") || subject.contains("invoice") || subject.contains("payment due") {
            return .bills
        } else if subject.contains("order") || subject.contains("shipped") || subject.contains("delivered") {
            return .orders
        } else if sender.contains("amazon") || sender.contains("ebay") || subject.contains("purchase") {
            return .orders
        } else if subject.contains("unsubscribe") || subject.contains("sale") || subject.contains("discount") || subject.contains("% off") {
            return .marketing
        } else if sender.contains("@company.com") || subject.contains("meeting") || subject.contains("project") {
            return .work
        } else if sender.contains("facebook") || sender.contains("twitter") || sender.contains("linkedin") {
            return .social
        } else if subject.contains("newsletter") || subject.contains("weekly") || subject.contains("digest") {
            return .newsletters
        }

        return .other
    }

    func scoreEmailPriority(_ email: Email) async -> Int {
        // TODO: AI priority scoring
        // For now, use rules
        let subject = email.subject.lowercased()

        if subject.contains("urgent") || subject.contains("asap") || subject.contains("today") {
            return 10
        } else if subject.contains("bill") || subject.contains("due") || subject.contains("payment") {
            return 9
        } else if subject.contains("meeting") || subject.contains("deadline") {
            return 8
        } else if email.category == .work {
            return 7
        } else if email.category == .personal {
            return 6
        } else if email.category == .orders {
            return 5
        } else if email.category == .marketing {
            return 2
        }

        return 5
    }

    func generateOverallSummary(emails: [Email], stats: MailboxStats) async -> String {
        // TODO: AI-generated summary
        // For now, use template

        let bills = emails.filter { $0.category == .bills }.count
        let work = emails.filter { $0.category == .work }.count
        let marketing = emails.filter { $0.category == .marketing }.count
        let urgent = stats.highPriorityEmails

        var summary = "📧 You have \(stats.unreadEmails) unread emails. "

        if urgent > 0 {
            summary += "\(urgent) high priority items need attention. "
        }

        if bills > 0 {
            summary += "\(bills) bills to review. "
        }

        if work > 0 {
            summary += "\(work) work emails. "
        }

        if marketing > 0 {
            summary += "\(marketing) marketing emails (safe to delete). "
        }

        return summary
    }

    func extractActions(from email: Email) async -> [EmailAction] {
        // TODO: AI action extraction
        // For now, return empty
        return []
    }

    func generateSmartReply(for email: Email) async -> [String] {
        // TODO: AI smart replies
        return ["Thanks for the update!", "Got it, will review.", "Not interested, thanks."]
    }
}
