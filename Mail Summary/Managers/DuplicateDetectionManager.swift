//
//  DuplicateDetectionManager.swift
//  Mail Summary
//
//  Detects duplicate emails using multiple algorithms
//  Created by Jordan Koch on 2026-01-30.
//

import Foundation
import CryptoKit

/// Methods for detecting duplicate emails
enum DuplicateDetectionMethod: String, CaseIterable {
    case exactHash = "Exact Hash"
    case fuzzySubjectSender = "Fuzzy Subject + Sender"
    case bodySimilarity = "Body Similarity"
    case attachmentHash = "Attachment Hash"

    var description: String {
        switch self {
        case .exactHash:
            return "Finds exact duplicates by comparing hash of subject + sender + date"
        case .fuzzySubjectSender:
            return "Finds similar emails with matching subjects and senders (ignores Re:/Fwd:)"
        case .bodySimilarity:
            return "Finds emails with similar body content using cosine similarity"
        case .attachmentHash:
            return "Finds emails referencing the same attachments"
        }
    }

    var icon: String {
        switch self {
        case .exactHash: return "number"
        case .fuzzySubjectSender: return "textformat.abc"
        case .bodySimilarity: return "doc.text"
        case .attachmentHash: return "paperclip"
        }
    }
}

/// Group of duplicate emails
struct DuplicateGroup: Identifiable, Hashable, Equatable {
    let id = UUID()
    let method: DuplicateDetectionMethod
    let representativeEmail: Email
    let duplicates: [Email]
    let similarityScore: Double

    var totalCount: Int {
        duplicates.count + 1
    }

    var duplicateCount: Int {
        duplicates.count
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DuplicateGroup, rhs: DuplicateGroup) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manager for detecting duplicate emails
@MainActor
class DuplicateDetectionManager: ObservableObject {
    static let shared = DuplicateDetectionManager()

    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    @Published var lastScanDate: Date?

    // Configuration
    @Published var similarityThreshold: Double = 0.8  // 80% similarity for fuzzy matching

    private init() {}

    // MARK: - Full Duplicate Scan

    /// Scan all emails for duplicates using all methods
    func scanForDuplicates(_ emails: [Email], methods: Set<DuplicateDetectionMethod> = Set(DuplicateDetectionMethod.allCases)) async -> [DuplicateGroup] {
        isScanning = true
        scanProgress = 0.0
        duplicateGroups = []

        var allGroups: [DuplicateGroup] = []
        let methodCount = methods.count
        var completedMethods = 0

        if methods.contains(.exactHash) {
            let groups = await detectExactDuplicates(emails)
            allGroups.append(contentsOf: groups)
            completedMethods += 1
            scanProgress = Double(completedMethods) / Double(methodCount)
        }

        if methods.contains(.fuzzySubjectSender) {
            let groups = await detectFuzzyDuplicates(emails)
            allGroups.append(contentsOf: groups)
            completedMethods += 1
            scanProgress = Double(completedMethods) / Double(methodCount)
        }

        if methods.contains(.bodySimilarity) {
            let groups = await detectBodySimilarDuplicates(emails)
            allGroups.append(contentsOf: groups)
            completedMethods += 1
            scanProgress = Double(completedMethods) / Double(methodCount)
        }

        // Sort by duplicate count (most duplicates first)
        allGroups.sort { $0.duplicateCount > $1.duplicateCount }

        duplicateGroups = allGroups
        isScanning = false
        scanProgress = 1.0
        lastScanDate = Date()

        return allGroups
    }

    // MARK: - Exact Hash Detection

    /// Detect exact duplicates by hashing subject + sender + date
    private func detectExactDuplicates(_ emails: [Email]) async -> [DuplicateGroup] {
        var hashGroups: [String: [Email]] = [:]

        for email in emails {
            let hash = createEmailHash(email)
            hashGroups[hash, default: []].append(email)
        }

        // Filter to only groups with duplicates
        var groups: [DuplicateGroup] = []
        for (_, emailGroup) in hashGroups where emailGroup.count > 1 {
            let sorted = emailGroup.sorted { $0.dateReceived < $1.dateReceived }
            let representative = sorted.first!
            let duplicates = Array(sorted.dropFirst())

            groups.append(DuplicateGroup(
                method: .exactHash,
                representativeEmail: representative,
                duplicates: duplicates,
                similarityScore: 1.0
            ))
        }

        return groups
    }

    /// Create hash for exact duplicate detection
    private func createEmailHash(_ email: Email) -> String {
        let normalizedSubject = normalizeSubject(email.subject)
        let data = "\(normalizedSubject)|\(email.senderEmail.lowercased())"
        let hash = SHA256.hash(data: Data(data.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Fuzzy Subject + Sender Detection

    /// Detect duplicates with similar subjects and same sender
    private func detectFuzzyDuplicates(_ emails: [Email]) async -> [DuplicateGroup] {
        var groups: [DuplicateGroup] = []
        var processedIDs: Set<Int> = []

        // Group by sender first (reduces comparisons)
        let bySender = Dictionary(grouping: emails) { $0.senderEmail.lowercased() }

        for (_, senderEmails) in bySender where senderEmails.count > 1 {
            // Compare subjects within same sender
            for i in 0..<senderEmails.count {
                let email = senderEmails[i]
                if processedIDs.contains(email.id) { continue }

                var duplicates: [Email] = []
                let normalizedSubject = normalizeSubject(email.subject)

                for j in (i + 1)..<senderEmails.count {
                    let other = senderEmails[j]
                    if processedIDs.contains(other.id) { continue }

                    let otherNormalized = normalizeSubject(other.subject)
                    let similarity = calculateStringSimilarity(normalizedSubject, otherNormalized)

                    if similarity >= similarityThreshold {
                        duplicates.append(other)
                        processedIDs.insert(other.id)
                    }
                }

                if !duplicates.isEmpty {
                    processedIDs.insert(email.id)
                    groups.append(DuplicateGroup(
                        method: .fuzzySubjectSender,
                        representativeEmail: email,
                        duplicates: duplicates,
                        similarityScore: similarityThreshold
                    ))
                }
            }
        }

        return groups
    }

    // MARK: - Body Similarity Detection

    /// Detect duplicates with similar body content
    private func detectBodySimilarDuplicates(_ emails: [Email]) async -> [DuplicateGroup] {
        var groups: [DuplicateGroup] = []
        var processedIDs: Set<Int> = []

        // Only consider emails with bodies
        let emailsWithBody = emails.filter { $0.body != nil && !$0.body!.isEmpty }

        // Pre-compute word vectors for efficiency
        var wordVectors: [Int: [String: Int]] = [:]
        for email in emailsWithBody {
            wordVectors[email.id] = createWordVector(email.body!)
        }

        for i in 0..<emailsWithBody.count {
            let email = emailsWithBody[i]
            if processedIDs.contains(email.id) { continue }

            var duplicates: [Email] = []
            let vector1 = wordVectors[email.id]!

            for j in (i + 1)..<emailsWithBody.count {
                let other = emailsWithBody[j]
                if processedIDs.contains(other.id) { continue }

                let vector2 = wordVectors[other.id]!
                let similarity = cosineSimilarity(vector1, vector2)

                if similarity >= similarityThreshold {
                    duplicates.append(other)
                    processedIDs.insert(other.id)
                }
            }

            if !duplicates.isEmpty {
                processedIDs.insert(email.id)
                groups.append(DuplicateGroup(
                    method: .bodySimilarity,
                    representativeEmail: email,
                    duplicates: duplicates,
                    similarityScore: similarityThreshold
                ))
            }
        }

        return groups
    }

    // MARK: - Helper Methods

    /// Normalize subject by removing Re:, Fwd:, etc.
    private func normalizeSubject(_ subject: String) -> String {
        var normalized = subject.lowercased()

        // Remove common prefixes
        let prefixes = ["re:", "re: ", "fwd:", "fwd: ", "fw:", "fw: ", "aw:", "aw: ", "sv:", "sv: "]
        for prefix in prefixes {
            while normalized.hasPrefix(prefix) {
                normalized = String(normalized.dropFirst(prefix.count))
            }
        }

        // Remove extra whitespace
        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized = normalized.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")

        return normalized
    }

    /// Calculate string similarity using Levenshtein distance
    private func calculateStringSimilarity(_ str1: String, _ str2: String) -> Double {
        let maxLen = max(str1.count, str2.count)
        guard maxLen > 0 else { return 1.0 }

        let distance = levenshteinDistance(str1, str2)
        return 1.0 - (Double(distance) / Double(maxLen))
    }

    /// Levenshtein distance calculation (optimized single-row version)
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let s1 = Array(str1)
        let s2 = Array(str2)

        if s1.isEmpty { return s2.count }
        if s2.isEmpty { return s1.count }

        var previousRow = Array(0...s2.count)
        var currentRow = [Int](repeating: 0, count: s2.count + 1)

        for i in 1...s1.count {
            currentRow[0] = i
            for j in 1...s2.count {
                let cost = s1[i - 1] == s2[j - 1] ? 0 : 1
                currentRow[j] = min(
                    previousRow[j] + 1,
                    currentRow[j - 1] + 1,
                    previousRow[j - 1] + cost
                )
            }
            swap(&previousRow, &currentRow)
        }

        return previousRow[s2.count]
    }

    /// Create word frequency vector for body text
    private func createWordVector(_ text: String) -> [String: Int] {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }  // Skip short words
            .filter { !stopWords.contains($0) }

        var vector: [String: Int] = [:]
        for word in words {
            vector[word, default: 0] += 1
        }

        return vector
    }

    /// Calculate cosine similarity between two word vectors
    private func cosineSimilarity(_ vec1: [String: Int], _ vec2: [String: Int]) -> Double {
        let allWords = Set(vec1.keys).union(Set(vec2.keys))

        var dotProduct = 0.0
        var magnitude1 = 0.0
        var magnitude2 = 0.0

        for word in allWords {
            let v1 = Double(vec1[word] ?? 0)
            let v2 = Double(vec2[word] ?? 0)

            dotProduct += v1 * v2
            magnitude1 += v1 * v1
            magnitude2 += v2 * v2
        }

        guard magnitude1 > 0 && magnitude2 > 0 else { return 0.0 }

        return dotProduct / (sqrt(magnitude1) * sqrt(magnitude2))
    }

    /// Common stop words to ignore in body comparison
    private let stopWords: Set<String> = [
        "the", "be", "to", "of", "and", "a", "in", "that", "have", "i",
        "it", "for", "not", "on", "with", "he", "as", "you", "do", "at",
        "this", "but", "his", "by", "from", "they", "we", "say", "her", "she",
        "or", "an", "will", "my", "one", "all", "would", "there", "their", "what",
        "so", "up", "out", "if", "about", "who", "get", "which", "go", "me",
        "when", "make", "can", "like", "time", "no", "just", "him", "know", "take",
        "people", "into", "year", "your", "good", "some", "could", "them", "see", "other",
        "than", "then", "now", "look", "only", "come", "its", "over", "think", "also"
    ]

    // MARK: - Actions

    /// Delete all duplicates in a group (keep representative)
    func deleteDuplicates(in group: DuplicateGroup) async -> (deleted: Int, failed: Int) {
        var deleted = 0
        var failed = 0

        for email in group.duplicates {
            let result = await EmailActionManager.shared.performAction(.delete, on: email)
            if result.isSuccess {
                deleted += 1
            } else {
                failed += 1
            }
        }

        // Remove from our tracking
        if let index = duplicateGroups.firstIndex(where: { $0.id == group.id }) {
            duplicateGroups.remove(at: index)
        }

        return (deleted, failed)
    }

    /// Get total duplicate count across all groups
    var totalDuplicateCount: Int {
        duplicateGroups.reduce(0) { $0 + $1.duplicateCount }
    }

    /// Get duplicate count by method
    func duplicateCount(for method: DuplicateDetectionMethod) -> Int {
        duplicateGroups
            .filter { $0.method == method }
            .reduce(0) { $0 + $1.duplicateCount }
    }
}
