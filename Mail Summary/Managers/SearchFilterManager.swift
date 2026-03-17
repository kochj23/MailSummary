//
//  SearchFilterManager.swift
//  Mail Summary
//
//  Fast multi-field email search with caching and filtering
//  Created by Jordan Koch on 2026-01-23
//
//  OPTIMIZED: Proper LRU cache eviction
//

import Foundation

@MainActor
class SearchFilterManager: ObservableObject {
    @Published var filters = SearchFilters()
    @Published var results: [SearchResult] = []
    @Published var isSearching = false

    // OPTIMIZED: LRU cache with access timestamps
    private var searchCache: [String: CachedSearchResult] = [:]
    private let maxCacheSize = 20

    /// Cached search result with timestamp for LRU eviction
    private struct CachedSearchResult {
        let results: [SearchResult]
        var lastAccessed: Date

        init(results: [SearchResult]) {
            self.results = results
            self.lastAccessed = Date()
        }
    }

    // MARK: - Search

    /// Perform search with current filters
    func search(in emails: [Email]) {
        // Clear results if no active filters
        guard filters.isActive else {
            results = []
            return
        }

        isSearching = true

        Task {
            // Check cache first (LRU: update access time on hit)
            let cacheKey = filters.cacheKey()
            if var cached = searchCache[cacheKey] {
                #if DEBUG
                print("🔍 Cache hit for search: \(cacheKey.prefix(50))...")
                #endif
                cached.lastAccessed = Date()
                searchCache[cacheKey] = cached
                results = cached.results
                isSearching = false
                return
            }

            // Perform search
            let startTime = Date()
            var matched: [SearchResult] = []
            let query = filters.query.lowercased()

            for email in emails {
                // Apply category filter
                if !filters.categories.isEmpty,
                   let category = email.category,
                   !filters.categories.contains(category) {
                    continue
                }

                // Apply priority filter
                if let minPri = filters.minPriority,
                   (email.priority ?? 0) < minPri {
                    continue
                }

                if let maxPri = filters.maxPriority,
                   (email.priority ?? 0) > maxPri {
                    continue
                }

                // Apply date range filter
                if let range = filters.dateRange,
                   !(email.dateReceived >= range.0 && email.dateReceived <= range.1) {
                    continue
                }

                // Apply unread filter
                if filters.unreadOnly && email.isRead {
                    continue
                }

                // Apply sender domain filter (Feature 2)
                if let domain = filters.senderDomain,
                   !email.senderEmail.lowercased().contains("@\(domain.lowercased())") {
                    continue
                }

                // Apply VIP filter (Feature 2)
                if filters.senderIsVIP {
                    // TODO: Check if sender is VIP (will be implemented in Sender Intelligence feature)
                    // For now, skip this email
                    continue
                }

                // Apply action items filter (Feature 2)
                if filters.hasActionItems && email.actions.isEmpty {
                    continue
                }

                // Apply word count filter (Feature 2)
                if let range = filters.wordCountRange, let body = email.body {
                    let wordCount = body.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
                    if wordCount < range.min || wordCount > range.max {
                        continue
                    }
                }

                // Text search with field scoring (supports plain text and regex)
                let regex = filters.compiledRegex()
                let hasQuery = !query.isEmpty || regex != nil

                if hasQuery {
                    var score = 0.0
                    var matchedText = ""
                    var matchedFields: Set<String> = []

                    if let regex = regex {
                        // Regex search
                        let subjectMatches = regex.numberOfMatches(in: email.subject, range: NSRange(email.subject.startIndex..., in: email.subject))
                        let senderMatches = regex.numberOfMatches(in: email.sender, range: NSRange(email.sender.startIndex..., in: email.sender)) +
                                           regex.numberOfMatches(in: email.senderEmail, range: NSRange(email.senderEmail.startIndex..., in: email.senderEmail))
                        let bodyMatches = email.body.map { regex.numberOfMatches(in: $0, range: NSRange($0.startIndex..., in: $0)) } ?? 0

                        if subjectMatches > 0 {
                            score = 1.0
                            matchedText = extractRegexMatch(from: email.subject, regex: regex) ?? email.subject
                            matchedFields.insert("subject")
                        } else if senderMatches > 0 {
                            score = 0.7
                            matchedText = extractRegexMatch(from: email.senderEmail, regex: regex) ?? email.sender
                            matchedFields.insert("sender")
                        } else if bodyMatches > 0, let body = email.body {
                            score = 0.5
                            matchedText = extractRegexMatch(from: body, regex: regex) ?? String(body.prefix(100))
                            matchedFields.insert("body")
                        }
                    } else {
                        // Standard text search (case-insensitive contains)
                        // Check subject (highest priority)
                        if email.subject.lowercased().contains(query) {
                            score = 1.0
                            matchedText = email.subject
                            matchedFields.insert("subject")
                        }
                        // Check sender (medium priority)
                        else if email.sender.lowercased().contains(query) ||
                                email.senderEmail.lowercased().contains(query) {
                            score = 0.7
                            matchedText = email.sender
                            matchedFields.insert("sender")
                        }
                        // Check body (lowest priority)
                        else if let body = email.body, body.lowercased().contains(query) {
                            score = 0.5
                            matchedText = extractSnippet(from: body, query: query)
                            matchedFields.insert("body")
                        }
                    }

                    // Only include if text matched
                    if score > 0 {
                        matched.append(SearchResult(
                            id: email.id,
                            email: email,
                            relevanceScore: score,
                            matchedText: matchedText,
                            matchedFields: matchedFields
                        ))
                    }
                } else {
                    // No text query, just filter matches
                    matched.append(SearchResult(
                        id: email.id,
                        email: email,
                        relevanceScore: 1.0,
                        matchedText: email.subject,
                        matchedFields: []
                    ))
                }
            }

            // Sort by relevance score (highest first)
            matched.sort { $0.relevanceScore > $1.relevanceScore }

            let duration = Date().timeIntervalSince(startTime) * 1000
            #if DEBUG
            print("🔍 Search completed in \(Int(duration))ms: \(matched.count) results")
            #endif

            // Cache results with LRU eviction
            searchCache[cacheKey] = CachedSearchResult(results: matched)

            // LRU eviction: remove oldest entries when exceeding max size
            if searchCache.count > maxCacheSize {
                let sortedByAccess = searchCache.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
                let keysToRemove = sortedByAccess.prefix(searchCache.count - maxCacheSize).map { $0.key }
                for key in keysToRemove {
                    searchCache.removeValue(forKey: key)
                }
                #if DEBUG
                print("🗑️ LRU cache eviction: removed \(keysToRemove.count) oldest entries")
                #endif
            }

            results = matched
            isSearching = false
        }
    }

    // MARK: - Utilities

    /// Extract snippet from body around search query
    private func extractSnippet(from text: String, query: String) -> String {
        guard let range = text.lowercased().range(of: query) else {
            return String(text.prefix(100))
        }

        let lowerBound = text.distance(from: text.startIndex, to: range.lowerBound)
        let upperBound = text.distance(from: text.startIndex, to: range.upperBound)

        let start = max(0, lowerBound - 50)
        let end = min(text.count, upperBound + 50)

        let snippet = String(text.dropFirst(start).prefix(end - start))
        return start > 0 ? "..." + snippet : snippet
    }

    /// Extract first regex match with surrounding context
    private func extractRegexMatch(from text: String, regex: NSRegularExpression) -> String? {
        guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }

        guard let range = Range(match.range, in: text) else {
            return nil
        }

        let matchedString = String(text[range])
        let lowerBound = text.distance(from: text.startIndex, to: range.lowerBound)
        let upperBound = text.distance(from: text.startIndex, to: range.upperBound)

        let start = max(0, lowerBound - 30)
        let end = min(text.count, upperBound + 30)

        let prefix = start > 0 ? "..." : ""
        let suffix = end < text.count ? "..." : ""

        let contextStart = text.index(text.startIndex, offsetBy: start)
        let contextEnd = text.index(text.startIndex, offsetBy: end)

        return prefix + String(text[contextStart..<contextEnd]) + suffix
    }

    /// Apply a regex preset
    func applyRegexPreset(_ preset: RegexPreset) {
        filters.useRegex = true
        filters.regexPattern = preset.pattern
    }

    /// Clear regex search
    func clearRegex() {
        filters.useRegex = false
        filters.regexPattern = nil
    }

    /// Clear all filters and results
    func clearFilters() {
        filters = SearchFilters()
        results = []
        #if DEBUG
        print("🧹 Search filters cleared")
        #endif
    }

    /// Invalidate search cache (call when email list changes)
    func invalidateCache() {
        searchCache.removeAll()
        #if DEBUG
        print("🗑️ Search cache invalidated")
        #endif
    }

    /// Apply quick filter preset
    func applyQuickFilter(_ preset: QuickFilterPreset) {
        switch preset {
        case .unreadOnly:
            filters.unreadOnly = true
        case .highPriority:
            filters.minPriority = 7
        case .today:
            let startOfDay = Calendar.current.startOfDay(for: Date())
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
            filters.dateRange = (startOfDay, endOfDay)
        case .thisWeek:
            let startOfWeek = Calendar.current.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: Date()).date!
            let endOfWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: startOfWeek)!
            filters.dateRange = (startOfWeek, endOfWeek)
        }
    }
}

// MARK: - Quick Filter Presets

enum QuickFilterPreset {
    case unreadOnly
    case highPriority
    case today
    case thisWeek
}
