//
//  ThreadModels.swift
//  Mail Summary
//
//  Email Thread Grouping - Data Models
//  Created by Jordan Koch on 2026-01-26
//
//  Defines structures for grouping emails into conversation threads.
//

import Foundation

// MARK: - Email Thread

struct EmailThread: Identifiable {
    let id: UUID
    var subject: String  // Normalized subject (without Re:, Fwd:)
    var originalSubject: String  // Original first email subject
    var emails: [Email]  // Sorted by date (oldest first)
    var participants: Set<String>  // All sender emails in thread
    var unreadCount: Int
    var lastMessageDate: Date
    var firstMessageDate: Date
    var isArchived: Bool
    var hasHighPriority: Bool

    init(id: UUID = UUID(), emails: [Email]) {
        self.id = id
        self.emails = emails.sorted { $0.dateReceived < $1.dateReceived }
        self.subject = Self.normalizeSubject(emails.first?.subject ?? "")
        self.originalSubject = emails.first?.subject ?? ""
        self.participants = Set(emails.map { $0.senderEmail })
        self.unreadCount = emails.filter { !$0.isRead }.count
        self.lastMessageDate = self.emails.last?.dateReceived ?? Date()
        self.firstMessageDate = self.emails.first?.dateReceived ?? Date()
        self.isArchived = false
        self.hasHighPriority = emails.contains { ($0.priority ?? 0) >= 8 }
    }

    var messageCount: Int {
        emails.count
    }

    var timespan: TimeInterval {
        lastMessageDate.timeIntervalSince(firstMessageDate)
    }

    var timespanDisplay: String {
        let days = Int(timespan / 86400)
        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "1 day"
        } else if days < 7 {
            return "\(days) days"
        } else {
            let weeks = days / 7
            return "\(weeks) week\(weeks == 1 ? "" : "s")"
        }
    }

    /// Normalize subject for thread grouping
    static func normalizeSubject(_ subject: String) -> String {
        var normalized = subject.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common prefixes (case-insensitive)
        let prefixes = ["Re:", "RE:", "re:", "Fwd:", "FWD:", "fwd:", "Fw:", "FW:", "fw:"]
        for prefix in prefixes {
            if normalized.hasPrefix(prefix) {
                normalized = String(normalized.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }

        // Remove [numbers] like [2] from subject lines
        normalized = normalized.replacingOccurrences(of: #"\[\d+\]"#, with: "", options: .regularExpression)

        // Remove extra whitespace
        normalized = normalized.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Check if an email belongs to this thread
    func belongsToThread(_ email: Email) -> Bool {
        // Same normalized subject
        let emailNormalizedSubject = Self.normalizeSubject(email.subject)
        if emailNormalizedSubject.lowercased() == subject.lowercased() {
            return true
        }

        // Similar subject (fuzzy match with 80% similarity)
        if similarityScore(subject, emailNormalizedSubject) > 0.8 {
            return true
        }

        return false
    }

    /// Calculate similarity between two subjects (0-1)
    private func similarityScore(_ str1: String, _ str2: String) -> Double {
        let s1 = str1.lowercased()
        let s2 = str2.lowercased()

        // Levenshtein distance approach (simplified)
        let maxLen = max(s1.count, s2.count)
        guard maxLen > 0 else { return 1.0 }

        let distance = levenshteinDistance(s1, s2)
        return 1.0 - (Double(distance) / Double(maxLen))
    }

    /// Calculate Levenshtein distance between two strings
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let s1 = Array(str1)
        let s2 = Array(str2)

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: s2.count + 1), count: s1.count + 1)

        for i in 0...s1.count {
            matrix[i][0] = i
        }

        for j in 0...s2.count {
            matrix[0][j] = j
        }

        for i in 1...s1.count {
            for j in 1...s2.count {
                let cost = s1[i - 1] == s2[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost  // substitution
                )
            }
        }

        return matrix[s1.count][s2.count]
    }
}

// MARK: - Thread Summary

struct ThreadSummary: Identifiable {
    let id: UUID
    let subject: String
    let messageCount: Int
    let unreadCount: Int
    let participants: Int
    let lastMessageDate: Date
    let hasHighPriority: Bool

    init(from thread: EmailThread) {
        self.id = thread.id
        self.subject = thread.subject
        self.messageCount = thread.emails.count
        self.unreadCount = thread.unreadCount
        self.participants = thread.participants.count
        self.lastMessageDate = thread.lastMessageDate
        self.hasHighPriority = thread.hasHighPriority
    }
}
