//
//  ThreadManager.swift
//  Mail Summary
//
//  Email Thread Grouping - Business Logic
//  Created by Jordan Koch on 2026-01-26
//
//  Groups emails into conversation threads using fuzzy subject matching.
//

import Foundation

@MainActor
class ThreadManager: ObservableObject {
    static let shared = ThreadManager()

    // MARK: - Published Properties

    @Published var threads: [EmailThread] = []
    @Published var isGrouping: Bool = false

    // MARK: - Private Properties

    private let similarityThreshold = 0.8  // 80% similarity required for fuzzy matching

    // MARK: - Initialization

    private init() {}

    // MARK: - Thread Grouping

    /// Group emails into conversation threads
    func groupEmailsIntoThreads(_ emails: [Email]) -> [EmailThread] {
        guard !emails.isEmpty else { return [] }

        isGrouping = true
        let startTime = Date()

        var threads: [EmailThread] = []
        var processedEmailIDs: Set<Int> = []

        // Sort emails by date (oldest first)
        let sortedEmails = emails.sorted { $0.dateReceived < $1.dateReceived }

        for email in sortedEmails {
            // Skip if already in a thread
            if processedEmailIDs.contains(email.id) {
                continue
            }

            // Create new thread with this email
            var threadEmails: [Email] = [email]
            processedEmailIDs.insert(email.id)

            // Find all related emails
            for otherEmail in sortedEmails {
                if processedEmailIDs.contains(otherEmail.id) {
                    continue
                }

                // Check if belongs to this thread
                if isSameThread(email, otherEmail) {
                    threadEmails.append(otherEmail)
                    processedEmailIDs.insert(otherEmail.id)
                }
            }

            // Create thread
            let thread = EmailThread(emails: threadEmails)
            threads.append(thread)
        }

        // Sort threads by last message date (newest first)
        threads.sort { $0.lastMessageDate > $1.lastMessageDate }

        let duration = Date().timeIntervalSince(startTime) * 1000
        print("🧵 Grouped \(emails.count) emails into \(threads.count) threads in \(Int(duration))ms")

        isGrouping = false
        self.threads = threads
        return threads
    }

    /// Check if two emails belong to the same thread
    private func isSameThread(_ email1: Email, _ email2: Email) -> Bool {
        // Normalize subjects
        let subject1 = EmailThread.normalizeSubject(email1.subject).lowercased()
        let subject2 = EmailThread.normalizeSubject(email2.subject).lowercased()

        // Exact match
        if subject1 == subject2 {
            return true
        }

        // Fuzzy match with similarity threshold
        let similarity = similarityScore(subject1, subject2)
        if similarity >= similarityThreshold {
            // Additional check: at least one common participant
            if email1.senderEmail == email2.senderEmail {
                return true
            }
        }

        return false
    }

    /// Calculate similarity score between two subjects
    private func similarityScore(_ str1: String, _ str2: String) -> Double {
        let maxLen = max(str1.count, str2.count)
        guard maxLen > 0 else { return 1.0 }

        let distance = levenshteinDistance(str1, str2)
        return 1.0 - (Double(distance) / Double(maxLen))
    }

    /// Calculate Levenshtein distance
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
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }

        return matrix[s1.count][s2.count]
    }

    /// Find thread for a specific email
    func findThread(for email: Email) -> EmailThread? {
        threads.first { thread in
            thread.emails.contains { $0.id == email.id }
        }
    }

    /// Add email to existing thread
    func addEmailToThread(email: Email, thread: EmailThread) -> EmailThread {
        var updatedThread = thread
        updatedThread.emails.append(email)
        updatedThread.emails.sort { $0.dateReceived < $1.dateReceived }
        updatedThread.participants.insert(email.senderEmail)
        updatedThread.unreadCount = updatedThread.emails.filter { !$0.isRead }.count
        updatedThread.lastMessageDate = updatedThread.emails.last?.dateReceived ?? Date()
        updatedThread.hasHighPriority = updatedThread.emails.contains { ($0.priority ?? 0) >= 8 }

        return updatedThread
    }

    /// Get thread summary statistics
    func getThreadStatistics() -> (totalThreads: Int, avgMessagesPerThread: Double, longestThread: Int) {
        guard !threads.isEmpty else {
            return (0, 0.0, 0)
        }

        let totalMessages = threads.reduce(0) { $0 + $1.messageCount }
        let avgMessages = Double(totalMessages) / Double(threads.count)
        let longest = threads.max(by: { $0.messageCount < $1.messageCount })?.messageCount ?? 0

        return (threads.count, avgMessages, longest)
    }
}
