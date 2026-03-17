//
//  ThreadManager.swift
//  Mail Summary
//
//  Email Thread Grouping - Business Logic
//  Created by Jordan Koch on 2026-01-26
//
//  Groups emails into conversation threads using fuzzy subject matching.
//  OPTIMIZED: Uses dictionary-based grouping to avoid O(n²) comparisons.
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

    // Cache for normalized subjects to avoid repeated computation
    private var normalizedSubjectCache: [Int: String] = [:]

    // Levenshtein distance cache to avoid recomputing same pairs
    private var levenshteinCache: [String: Int] = [:]
    private let maxLevenshteinCacheSize = 1000

    // MARK: - Initialization

    private init() {}

    // MARK: - Thread Grouping

    /// Group emails into conversation threads - OPTIMIZED O(n) for exact matches
    func groupEmailsIntoThreads(_ emails: [Email]) -> [EmailThread] {
        guard !emails.isEmpty else { return [] }

        isGrouping = true
        let startTime = Date()

        // Clear caches for fresh grouping
        normalizedSubjectCache.removeAll(keepingCapacity: true)
        levenshteinCache.removeAll(keepingCapacity: true)

        // Step 1: Pre-normalize all subjects once (O(n))
        var normalizedSubjects: [Int: String] = [:]
        for email in emails {
            let normalized = EmailThread.normalizeSubject(email.subject).lowercased()
            normalizedSubjects[email.id] = normalized
            normalizedSubjectCache[email.id] = normalized
        }

        // Step 2: Group by exact normalized subject using Dictionary (O(n))
        var exactMatchGroups: [String: [Email]] = [:]
        for email in emails {
            let normalized = normalizedSubjects[email.id]!
            exactMatchGroups[normalized, default: []].append(email)
        }

        // Step 3: Build threads from exact matches
        var threads: [EmailThread] = []
        var processedEmailIDs: Set<Int> = []

        // Process exact match groups first (fast path)
        for (_, groupEmails) in exactMatchGroups {
            // Mark all as processed
            for email in groupEmails {
                processedEmailIDs.insert(email.id)
            }

            // Sort by date and create thread
            let sortedGroup = groupEmails.sorted { $0.dateReceived < $1.dateReceived }
            let thread = EmailThread(emails: sortedGroup)
            threads.append(thread)
        }

        // Step 4: Merge similar threads using fuzzy matching (only between thread representatives)
        // This reduces comparisons from O(n²) to O(t²) where t = number of threads << n
        threads = mergeSimilarThreads(threads, normalizedSubjects: normalizedSubjects)

        // Sort threads by last message date (newest first)
        threads.sort { $0.lastMessageDate > $1.lastMessageDate }

        let duration = Date().timeIntervalSince(startTime) * 1000
        #if DEBUG
        print("🧵 Grouped \(emails.count) emails into \(threads.count) threads in \(Int(duration))ms")
        #endif

        isGrouping = false
        self.threads = threads
        return threads
    }

    /// Merge threads with similar subjects - O(t²) where t = thread count
    private func mergeSimilarThreads(_ threads: [EmailThread], normalizedSubjects: [Int: String]) -> [EmailThread] {
        guard threads.count > 1 else { return threads }

        var mergedThreads: [EmailThread] = []
        var processedIndices: Set<Int> = []

        // Get representative subject for each thread (first email's subject)
        let threadSubjects: [(index: Int, subject: String, senderEmail: String)] = threads.enumerated().compactMap { index, thread in
            guard let firstEmail = thread.emails.first,
                  let subject = normalizedSubjects[firstEmail.id] else { return nil }
            return (index, subject, firstEmail.senderEmail)
        }

        // Group threads by similar subjects
        for i in 0..<threadSubjects.count {
            if processedIndices.contains(i) { continue }

            var combinedEmails = threads[threadSubjects[i].index].emails
            processedIndices.insert(i)

            // Only check threads with similar subject length (optimization)
            let subjectI = threadSubjects[i].subject
            let lengthI = subjectI.count

            for j in (i + 1)..<threadSubjects.count {
                if processedIndices.contains(j) { continue }

                let subjectJ = threadSubjects[j].subject
                let lengthJ = subjectJ.count

                // Skip if lengths differ by more than 20% (can't be 80% similar)
                let lengthDiff = abs(lengthI - lengthJ)
                let maxLen = max(lengthI, lengthJ)
                if maxLen > 0 && Double(lengthDiff) / Double(maxLen) > 0.2 {
                    continue
                }

                // Check similarity
                let similarity = cachedSimilarityScore(subjectI, subjectJ)
                if similarity >= similarityThreshold {
                    // Additional check: same sender
                    if threadSubjects[i].senderEmail == threadSubjects[j].senderEmail {
                        combinedEmails.append(contentsOf: threads[threadSubjects[j].index].emails)
                        processedIndices.insert(j)
                    }
                }
            }

            // Sort combined emails by date
            combinedEmails.sort { $0.dateReceived < $1.dateReceived }
            let mergedThread = EmailThread(emails: combinedEmails)
            mergedThreads.append(mergedThread)
        }

        return mergedThreads
    }

    /// Check if two emails belong to the same thread
    private func isSameThread(_ email1: Email, _ email2: Email) -> Bool {
        // Use cached normalized subjects
        let subject1 = normalizedSubjectCache[email1.id] ?? EmailThread.normalizeSubject(email1.subject).lowercased()
        let subject2 = normalizedSubjectCache[email2.id] ?? EmailThread.normalizeSubject(email2.subject).lowercased()

        // Exact match
        if subject1 == subject2 {
            return true
        }

        // Fuzzy match with similarity threshold
        let similarity = cachedSimilarityScore(subject1, subject2)
        if similarity >= similarityThreshold {
            // Additional check: at least one common participant
            if email1.senderEmail == email2.senderEmail {
                return true
            }
        }

        return false
    }

    /// Similarity score with caching
    private func cachedSimilarityScore(_ str1: String, _ str2: String) -> Double {
        let maxLen = max(str1.count, str2.count)
        guard maxLen > 0 else { return 1.0 }

        let distance = cachedLevenshteinDistance(str1, str2)
        return 1.0 - (Double(distance) / Double(maxLen))
    }

    /// Calculate similarity score between two subjects
    private func similarityScore(_ str1: String, _ str2: String) -> Double {
        let maxLen = max(str1.count, str2.count)
        guard maxLen > 0 else { return 1.0 }

        let distance = levenshteinDistance(str1, str2)
        return 1.0 - (Double(distance) / Double(maxLen))
    }

    /// Levenshtein distance with memoization cache
    private func cachedLevenshteinDistance(_ str1: String, _ str2: String) -> Int {
        // Create cache key (order-independent)
        let cacheKey = str1 < str2 ? "\(str1)|\(str2)" : "\(str2)|\(str1)"

        if let cached = levenshteinCache[cacheKey] {
            return cached
        }

        let distance = levenshteinDistance(str1, str2)

        // Evict oldest entries if cache is full
        if levenshteinCache.count >= maxLevenshteinCacheSize {
            // Remove half the cache (simple eviction)
            let keysToRemove = Array(levenshteinCache.keys.prefix(maxLevenshteinCacheSize / 2))
            for key in keysToRemove {
                levenshteinCache.removeValue(forKey: key)
            }
        }

        levenshteinCache[cacheKey] = distance
        return distance
    }

    /// Calculate Levenshtein distance - optimized with single row
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let s1 = Array(str1)
        let s2 = Array(str2)

        // Handle edge cases
        if s1.isEmpty { return s2.count }
        if s2.isEmpty { return s1.count }

        // Use single row optimization (O(n) space instead of O(n*m))
        var previousRow = Array(0...s2.count)
        var currentRow = [Int](repeating: 0, count: s2.count + 1)

        for i in 1...s1.count {
            currentRow[0] = i

            for j in 1...s2.count {
                let cost = s1[i - 1] == s2[j - 1] ? 0 : 1
                currentRow[j] = min(
                    previousRow[j] + 1,      // deletion
                    currentRow[j - 1] + 1,   // insertion
                    previousRow[j - 1] + cost // substitution
                )
            }

            swap(&previousRow, &currentRow)
        }

        return previousRow[s2.count]
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
