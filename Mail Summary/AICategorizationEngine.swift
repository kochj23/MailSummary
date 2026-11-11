//
//  AICategorizationEngine.swift
//  Mail Summary
//
//  AI-powered email categorization and analysis with graceful fallback.
//  AI goes through NovaAIKit (AppAI.shared): AI on/off, Auto failover, retries, validation. Every feature has a
//  built-in (keyword/rule/template) result used when AI is off, unreachable, or returns something invalid.
//  Created by Jordan Koch on 2026-01-22
//  Updated 2026-11-11 - migrated to NovaAIKit 1.0.0
//

import Foundation
import NovaAIKit

@MainActor
class AICategorizationEngine {
    private let ai: NovaAI

    init(ai: NovaAI? = nil) {
        self.ai = ai ?? AppAI.shared
    }

    // MARK: - AI Categorization

    /// Categorize email using DEEP AI analysis (falls back to keywords if AI unavailable)
    func categorizeEmail(_ email: Email) async -> Email.EmailCategory {
        let fallback = Self.categorizeWithKeywords(email)
        let bodyPreview = email.body?.prefix(1000).description ?? ""

        let prompt = """
        Analyze this email and categorize it accurately.

        Email:
        Subject: \(email.subject)
        Sender: \(email.sender) <\(email.senderEmail)>
        Body: \(bodyPreview)

        Categories:
        - Bills: Invoices, bills, payment requests, utilities
        - Orders: Shipping notifications, purchase confirmations, delivery updates
        - Work: Work-related emails, meetings, projects, colleagues
        - Personal: Family, friends, personal correspondence
        - Marketing: Promotions, sales, advertisements (has unsubscribe link)
        - Newsletters: Regular updates, digests, subscriptions
        - Social: Social media notifications (Facebook, Twitter, LinkedIn)
        - Spam: Unwanted emails, scams, phishing attempts
        - Other: Anything that doesn't fit above

        Analyze the CONTENT and INTENT, not just keywords. Consider:
        - Is there an unsubscribe link? (Marketing/Newsletter)
        - Is there a payment amount? (Bills)
        - Is there a tracking number? (Orders)
        - Is sender from work domain? (Work)
        - Is it from social media? (Social)

        Respond with JSON:
        {
            "category": "CategoryName",
            "confidence": 0.95,
            "reasoning": "Has payment due date and amount"
        }
        """

        let request = NovaAIRequest(
            prompt: prompt,
            system: "You are an expert email categorization system. Analyze content deeply, not just keywords. Always respond with valid JSON.",
            temperature: 0.2,  // Very low for consistent categorization
            maxTokens: 150,
            format: .json
        )
        return await ai.generate(request, validate: { try Self.parseCategory($0) }, fallback: { fallback }).value
    }

    /// Score email IMPORTANCE using deep AI analysis (falls back to rules if AI unavailable)
    func scoreEmailPriority(_ email: Email) async -> Int {
        let fallback = Self.scorePriorityWithRules(email)

        let bodyPreview = email.body?.prefix(1000).description ?? ""

        let prompt = """
        Determine the TRUE IMPORTANCE of this email on a scale of 1-10.

        IMPORTANCE SCALE:
        1-2 = Spam, marketing, can safely ignore
        3-4 = Newsletters, social media, non-urgent
        5-6 = Normal emails, informational
        7-8 = Important, needs attention soon
        9-10 = URGENT, requires immediate action

        EMAIL:
        Subject: \(email.subject)
        Sender: \(email.sender) <\(email.senderEmail)>
        Category: \(email.category?.rawValue ?? "Unknown")
        Body: \(bodyPreview)

        ANALYZE THESE FACTORS:
        1. DEADLINES - Is there a due date mentioned?
        2. ACTION REQUIRED - Does it need a response/action?
        3. FINANCIAL - Does it involve money/payments?
        4. SENDER AUTHORITY - Is it from boss/authority?
        5. URGENCY KEYWORDS - "urgent", "asap", "today", "immediately"
        6. CONSEQUENCES - What happens if ignored?
        7. TIME SENSITIVITY - How old is acceptable for this type?
        8. MEETING INVITES - Does it contain meeting details?

        EXAMPLES:
        - "Bill due tomorrow" = 10 (financial + deadline)
        - "Meeting at 3pm today" = 9 (time-sensitive + action required)
        - "Project update needed" = 7 (work-related + action)
        - "Your package shipped" = 6 (informational)
        - "Weekly newsletter" = 3 (can read later)
        - "50% off sale" = 1 (marketing)

        Respond with JSON:
        {
            "priority": 8,
            "hasDeadline": true,
            "requiresAction": true,
            "isSenderImportant": false,
            "reasoning": "Contains specific deadline and requires payment action"
        }
        """

        let request = NovaAIRequest(
            prompt: prompt,
            system: "You are an expert at determining email importance. Consider context, not just keywords. Deadlines and action items are most important. Always respond with valid JSON.",
            temperature: 0.3,  // Low temperature for consistent scoring
            maxTokens: 200,
            format: .json
        )
        return await ai.generate(request, validate: { try Self.parsePriority($0) }, fallback: { fallback }).value
    }

    /// Generate a 1-2 sentence summary for a single email (built-in: the body's first sentences).
    func generateSummary(for email: Email) async -> String? {
        guard let body = email.body else {
            return nil
        }
        let fallback = Self.basicEmailSummary(body: body)

        let prompt = """
        Create a brief 1-2 sentence summary of this email for someone who needs to quickly scan their inbox.

        Subject: \(email.subject)
        From: \(email.sender)

        Body:
        \(body.prefix(1000))

        Summary (concise, actionable, 1-2 sentences):
        """

        let request = NovaAIRequest(
            prompt: prompt,
            system: "You are an email summarization expert. Create concise, useful summaries that highlight key information and action items.",
            temperature: 0.5,
            maxTokens: 100
        )
        let summary = await ai.text(request, validate: { try Self.validateShortText($0) }, fallback: { fallback }).value
        return summary.isEmpty ? nil : summary
    }

    /// Extract action items from email using AI
    func extractActions(from email: Email) async -> [EmailAction] {
        guard let body = email.body else {
            return []
        }
        let fallback = Self.extractActionsWithRules(subject: email.subject, body: body)

        let prompt = """
        Extract any action items, deadlines, or tasks from this email.

        Subject: \(email.subject)
        Body: \(body)

        Respond in JSON with this format:
        {
            "actions": [
                {
                    "type": "deadline",
                    "text": "Pay electric bill",
                    "date": "2026-01-25T23:59:00Z"
                },
                {
                    "type": "meeting",
                    "text": "Team meeting",
                    "date": "2026-01-28T15:00:00Z"
                }
            ]
        }

        Types: deadline, meeting, task, reminder
        Only include actual action items - not general information.
        Return empty array if no actions found: {"actions": []}
        """

        let request = NovaAIRequest(
            prompt: prompt,
            system: "You are an expert at extracting action items and deadlines from emails. Always respond with valid JSON.",
            temperature: 0.3,
            maxTokens: 500,
            format: .json
        )
        return await ai.generate(request, validate: { try Self.parseActions($0) }, fallback: { fallback }).value
    }

    /// Generate overall mailbox summary using AI
    func generateOverallSummary(emails: [Email], stats: MailboxStats) async -> String {
        await overallSummary(emails: emails, stats: stats).value
    }

    /// Mailbox summary plus where it came from ("AI · Ollama (model)" / "Built-in").
    func overallSummary(emails: [Email], stats: MailboxStats) async -> NovaAIResult<String> {
        let fallback = Self.generateBasicSummary(emails: emails, stats: stats)

        let breakdown = """
        Total emails: \(stats.totalEmails)
        Unread: \(stats.unreadEmails)
        High priority: \(stats.highPriorityEmails)
        Action items: \(stats.actionsCount)

        By category:
        - Bills: \(emails.filter { $0.category == .bills }.count)
        - Work: \(emails.filter { $0.category == .work }.count)
        - Marketing: \(emails.filter { $0.category == .marketing }.count)
        - Orders: \(emails.filter { $0.category == .orders }.count)
        - Personal: \(emails.filter { $0.category == .personal }.count)
        - Other: \(emails.filter { $0.category == .other }.count)
        """

        let prompt = """
        Summarize this mailbox status for someone who wants a quick overview.

        \(breakdown)

        Write 2-3 sentences that give a clear picture of what needs attention most urgently.
        Be specific and actionable.
        """

        let request = NovaAIRequest(
            prompt: prompt,
            system: "You are a helpful email assistant. Provide actionable mailbox summaries that highlight what's important. Only use the numbers you are given.",
            temperature: 0.6,
            maxTokens: 150
        )
        return await ai.text(request, validate: { try Self.validateGroundedSummary($0, source: breakdown) }, fallback: { fallback })
    }

    // MARK: - Validators (reject by throwing NovaAIValidationError; clamp by returning a fixed value)

    /// AI category reply → a known category. Unknown names are rejected (the keyword result is used instead).
    nonisolated static func parseCategory(_ text: String) throws -> Email.EmailCategory {
        struct Reply: Decodable { let category: String }
        let reply = try NovaAIText.decode(Reply.self, from: text)
        let normalized = reply.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let category = Email.EmailCategory.allCases.first(where: { $0.rawValue.lowercased() == normalized }) else {
            throw NovaAIValidationError("category must be one of: \(Email.EmailCategory.allCases.map(\.rawValue).joined(separator: ", "))")
        }
        return category
    }

    /// AI priority reply → 1...10 (clamped). Missing or non-numeric values are rejected.
    nonisolated static func parsePriority(_ text: String) throws -> Int {
        struct Reply: Decodable { let priority: Double }
        let reply = try NovaAIText.decode(Reply.self, from: text)
        guard reply.priority.isFinite else { throw NovaAIValidationError("priority must be a number from 1 to 10") }
        return min(max(Int(reply.priority.rounded()), 1), 10)
    }

    /// AI sender importance → 0...1 (clamped).
    nonisolated static func parseImportance(_ text: String) throws -> Double {
        struct Reply: Decodable { let importance: Double }
        let reply = try NovaAIText.decode(Reply.self, from: text)
        guard reply.importance.isFinite else { throw NovaAIValidationError("importance must be a number from 0 to 1") }
        return min(max(reply.importance, 0.0), 1.0)
    }

    /// Maximum action items accepted from one email.
    nonisolated static let maxActions = 10

    /// AI action list → at most `maxActions` items with non-empty text; unknown types become tasks.
    nonisolated static func parseActions(_ text: String) throws -> [EmailAction] {
        struct Item: Decodable { let type: String?; let text: String?; let date: String? }
        struct Reply: Decodable { let actions: [Item] }
        let reply = try NovaAIText.decode(Reply.self, from: text)
        let formatter = ISO8601DateFormatter()
        return reply.actions.prefix(maxActions).compactMap { item in
            let text = NovaAIText.plain(item.text ?? "", max: 200)
            guard !text.isEmpty else { return nil }
            let type = EmailAction.ActionType(rawValue: (item.type ?? "").lowercased()) ?? .task
            return EmailAction(type: type, text: text, date: item.date.flatMap { formatter.date(from: $0) })
        }
    }

    /// Short summaries: non-empty, plain text, at most 400 characters.
    nonisolated static func validateShortText(_ text: String) throws -> String {
        let plain = NovaAIText.plain(try NovaAI.nonEmpty(text), max: 400)
        guard !plain.isEmpty else { throw NovaAIValidationError("empty reply") }
        return plain
    }

    /// Mailbox summary: short plain text that invents no numbers (every figure must appear in `source`).
    nonisolated static func validateGroundedSummary(_ text: String, source: String) throws -> String {
        let plain = try validateShortText(text)
        guard NovaAIText.grounded(plain, in: source) else {
            throw NovaAIValidationError("use only the numbers given in the mailbox breakdown")
        }
        return plain
    }

    // MARK: - Built-in Methods (keyword/rule based; used when AI is off, down or rejected)

    /// Categorize email using keyword matching.
    nonisolated static func categorizeWithKeywords(_ email: Email) -> Email.EmailCategory {
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

    /// Score email priority using rules.
    nonisolated static func scorePriorityWithRules(_ email: Email) -> Int {
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

    /// First one or two sentences of the body (whitespace collapsed, max 240 characters).
    nonisolated static func basicEmailSummary(body: String) -> String {
        let flat = body.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        var sentences: [String] = []
        flat.enumerateSubstrings(in: flat.startIndex..., options: .bySentences) { sub, _, _, stop in
            if let sub, !sub.trimmingCharacters(in: .whitespaces).isEmpty { sentences.append(sub.trimmingCharacters(in: .whitespaces)) }
            if sentences.count >= 2 { stop = true }
        }
        let summary = sentences.isEmpty ? flat : sentences.joined(separator: " ")
        return summary.count > 240 ? String(summary.prefix(239)) + "…" : summary
    }

    /// Keyword-based action items: one per line that mentions a deadline, meeting, payment or request.
    nonisolated static func extractActionsWithRules(subject: String, body: String) -> [EmailAction] {
        let rules: [(EmailAction.ActionType, [String])] = [
            (.deadline, ["due ", "deadline", "by friday", "by monday", "by tomorrow", "expires"]),
            (.meeting, ["meeting", "call at", "invite", "zoom", "teams link"]),
            (.task, ["please ", "action required", "can you", "could you", "need you to"]),
        ]
        var actions: [EmailAction] = []
        for line in ([subject] + body.components(separatedBy: .newlines)) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 6 else { continue }
            let lower = trimmed.lowercased()
            if let (type, _) = rules.first(where: { $0.1.contains(where: lower.contains) }) {
                actions.append(EmailAction(type: type, text: String(trimmed.prefix(200)), date: nil))
            }
            if actions.count >= maxActions { break }
        }
        return actions
    }

    /// Rule-based actionable factors (keywords in subject/body).
    nonisolated static func actionableFactorsWithRules(subject: String, body: String) -> ActionableFactors {
        let text = (subject + "\n" + body).lowercased()
        let urgent = ["urgent", "asap", "immediately", "today"].contains(where: text.contains)
        return ActionableFactors(
            hasDeadline: ["deadline", "due ", "expires", "by end of"].contains(where: text.contains),
            hasMeeting: ["meeting", "invite", "calendar", "zoom"].contains(where: text.contains),
            requiresResponse: text.contains("?") || ["please reply", "let me know", "respond"].contains(where: text.contains),
            hasPayment: ["payment", "invoice", "amount due", "bill"].contains(where: text.contains),
            urgencyScore: urgent ? 0.8 : 0.2
        )
    }

    /// Heuristic sender importance: open rate, nudged by category.
    nonisolated static func basicSenderImportance(openRate: Double, category: Email.EmailCategory?) -> Double {
        var score = openRate.isFinite ? openRate : 0.5
        switch category {
        case .bills?, .work?, .personal?: score += 0.2
        case .marketing?, .spam?, .social?: score -= 0.2
        default: break
        }
        return min(max(score, 0.0), 1.0)
    }

    /// Generate basic mailbox summary without AI.
    nonisolated static func generateBasicSummary(emails: [Email], stats: MailboxStats) -> String {
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

    // MARK: - Enhanced AI Analysis

    /// Analyze sender importance and reputation
    func analyzeSenderImportance(_ email: Email, emailHistory: [Email]) async -> Double {

        // Get sender's email history
        let senderEmails = emailHistory.filter { $0.senderEmail == email.senderEmail }
        let replyRate = calculateReplyRate(for: email.senderEmail, in: emailHistory)
        let openRate = calculateOpenRate(for: email.senderEmail, in: emailHistory)
        let fallback = Self.basicSenderImportance(openRate: openRate, category: email.category)

        let prompt = """
        Analyze this email sender's importance based on historical patterns.

        SENDER: \(email.sender) <\(email.senderEmail)>
        CURRENT EMAIL SUBJECT: \(email.subject)

        HISTORICAL DATA:
        - Total emails from this sender: \(senderEmails.count)
        - Your reply rate to this sender: \(Int(replyRate * 100))%
        - Your open rate for this sender: \(Int(openRate * 100))%
        - Recent categories: \(senderEmails.prefix(5).compactMap { $0.category?.rawValue }.joined(separator: ", "))

        ANALYZE:
        1. Is this sender consistently important to you? (high reply/open rates)
        2. Do you act on their emails quickly?
        3. Are they from a critical domain (work, bills, orders)?
        4. Do their emails require action?

        Respond with JSON:
        {
            "importance": 0.85,
            "reasoning": "High reply rate indicates important sender",
            "isCritical": true
        }

        Importance: 0.0 = ignore, 0.5 = neutral, 1.0 = critical
        """

        let request = NovaAIRequest(
            prompt: prompt,
            system: "You are analyzing sender patterns to determine importance. Be data-driven.",
            temperature: 0.3,
            maxTokens: 150,
            format: .json
        )
        return await ai.generate(request, validate: { try Self.parseImportance($0) }, fallback: { fallback }).value
    }

    /// Detect actionable items in email
    func detectActionableFactors(_ email: Email) async -> ActionableFactors {
        guard let body = email.body else {
            return ActionableFactors()
        }
        let fallback = Self.actionableFactorsWithRules(subject: email.subject, body: body)

        let prompt = """
        Analyze this email for actionable factors.

        Subject: \(email.subject)
        Body: \(body)

        DETECT:
        1. DEADLINES - Specific dates/times mentioned
        2. MEETINGS - Meeting invites with time/location
        3. RESPONSE REQUIRED - Needs reply or decision
        4. PAYMENT DUE - Bills or payment requests
        5. ACTION ITEMS - Tasks to complete
        6. URGENT KEYWORDS - "urgent", "asap", "today", "immediately"

        Respond with JSON:
        {
            "hasDeadline": true,
            "deadlineDate": "2026-01-25",
            "hasMeeting": false,
            "requiresResponse": true,
            "hasPayment": true,
            "paymentAmount": "$156.78",
            "urgencyScore": 0.9,
            "actionItems": ["Pay bill by Jan 25", "Review charges"]
        }
        """

        let request = NovaAIRequest(
            prompt: prompt,
            system: "You are an expert at extracting actionable information from emails. Be precise.",
            temperature: 0.2,
            maxTokens: 300,
            format: .json
        )
        return await ai.generate(request, validate: { try Self.parseActionableFactors($0) }, fallback: { fallback }).value
    }

    // MARK: - Helper Methods

    private func calculateReplyRate(for sender: String, in emails: [Email]) -> Double {
        let senderEmails = emails.filter { $0.senderEmail == sender }
        guard !senderEmails.isEmpty else { return 0.0 }

        // This would need to track actual replies - placeholder for now
        // In real implementation, would track reply actions
        return 0.5
    }

    private func calculateOpenRate(for sender: String, in emails: [Email]) -> Double {
        let senderEmails = emails.filter { $0.senderEmail == sender }
        guard !senderEmails.isEmpty else { return 0.0 }

        let opened = senderEmails.filter { $0.isRead }.count
        return Double(opened) / Double(senderEmails.count)
    }

    /// AI actionable factors → clamped (urgency 0...1).
    nonisolated static func parseActionableFactors(_ text: String) throws -> ActionableFactors {
        struct Reply: Decodable {
            let hasDeadline: Bool?, hasMeeting: Bool?, requiresResponse: Bool?, hasPayment: Bool?, urgencyScore: Double?
        }
        let r = try NovaAIText.decode(Reply.self, from: text)
        let urgency = r.urgencyScore.map { $0.isFinite ? min(max($0, 0), 1) : 0 } ?? 0
        return ActionableFactors(
            hasDeadline: r.hasDeadline ?? false,
            hasMeeting: r.hasMeeting ?? false,
            requiresResponse: r.requiresResponse ?? false,
            hasPayment: r.hasPayment ?? false,
            urgencyScore: urgency
        )
    }
}

/// Actionable factors detected in email
struct ActionableFactors: Equatable, Sendable {
    var hasDeadline: Bool = false
    var hasMeeting: Bool = false
    var requiresResponse: Bool = false
    var hasPayment: Bool = false
    var urgencyScore: Double = 0.0

    var isActionable: Bool {
        hasDeadline || hasMeeting || requiresResponse || hasPayment || urgencyScore > 0.7
    }

    var urgencyMultiplier: Double {
        var multiplier = 1.0
        if hasDeadline { multiplier += 0.5 }
        if hasMeeting { multiplier += 0.4 }
        if requiresResponse { multiplier += 0.3 }
        if hasPayment { multiplier += 0.5 }
        if urgencyScore > 0.7 { multiplier += urgencyScore }
        return multiplier
    }
}

// MARK: - Natural Language Search (Feature 10)

extension AICategorizationEngine {
    /// Parse natural language query into structured SearchFilters
    func parseNaturalLanguageQuery(_ query: String) async -> SearchFilters {
        // Built-in: keyword extraction.
        let fallback = Self.extractKeywordFilters(from: query)

        let prompt = """
        Parse this natural language search query into structured search filters for an email search system.

        Query: "\(query)"

        Extract these filter parameters if mentioned:
        1. Sender name or email address
        2. Subject keywords (words that should appear in subject)
        3. Category (Bills, Orders, Work, Personal, Marketing, Newsletters, Social, Spam, Other)
        4. Priority level (mentioned as "urgent", "important", "high priority" = 8-10)
        5. Date range (mentioned as "today", "this week", "last month", etc.)
        6. Read status ("unread" = unread only)
        7. Action items ("with deadlines", "needs action" = has action items)

        Examples:
        - "urgent bills from last week" → category: Bills, minPriority: 8, dateRange: last 7 days
        - "emails from John about project" → sender contains "John", subject keywords: ["project"]
        - "unread work emails from today" → category: Work, unread: true, dateRange: today

        Respond with JSON:
        {
            "senderContains": "john",
            "subjectKeywords": ["project", "update"],
            "category": "Work",
            "minPriority": 8,
            "dateRange": "last_week",
            "unreadOnly": true,
            "hasActionItems": false
        }

        If a parameter isn't mentioned, omit it from the JSON. Return only valid JSON.
        """

        let request = NovaAIRequest(
            prompt: prompt,
            system: "You are an expert at parsing natural language queries for email search. Always respond with valid JSON.",
            temperature: 0.2,
            maxTokens: 300,
            format: .json
        )
        return await ai.generate(request, validate: { try Self.parseQueryResponse($0) }, fallback: { fallback }).value
    }

    /// AI query reply → SearchFilters (unknown categories dropped, priority clamped to 1...10). No JSON → rejected.
    nonisolated static func parseQueryResponse(_ json: String) throws -> SearchFilters {
        var filters = SearchFilters()

        guard let payload = NovaAIText.jsonPayload(json), let data = payload.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NovaAIValidationError("The reply contained no JSON object.")
        }

        // Extract sender
        if let sender = dict["senderContains"] as? String {
            filters.query = String(sender.prefix(200))
        }

        // Extract subject keywords
        if let keywords = dict["subjectKeywords"] as? [String], !keywords.isEmpty {
            if filters.query.isEmpty {
                filters.query = keywords.joined(separator: " ")
            }
        }

        // Extract category
        if let categoryStr = dict["category"] as? String,
           let category = Email.EmailCategory(rawValue: categoryStr) {
            filters.categories.insert(category)
        }

        // Extract priority
        if let minPri = dict["minPriority"] as? Int {
            filters.minPriority = min(max(minPri, 1), 10)
        }

        // Extract date range
        if let dateRangeStr = dict["dateRange"] as? String {
            filters.dateRange = parseDateRange(dateRangeStr)
        }

        // Extract unread status
        if let unread = dict["unreadOnly"] as? Bool {
            filters.unreadOnly = unread
        }

        // Extract action items
        if let hasActions = dict["hasActionItems"] as? Bool {
            filters.hasActionItems = hasActions
        }

        return filters
    }

    /// Parse date range string into Date tuple
    nonisolated static func parseDateRange(_ rangeStr: String) -> (Date, Date)? {
        let now = Date()
        let calendar = Calendar.current

        switch rangeStr.lowercased() {
        case "today":
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            return (start, end)

        case "yesterday":
            let start = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) ?? now
            let end = calendar.startOfDay(for: now)
            return (start, end)

        case "this_week", "thisweek":
            let start = calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: now).date ?? now
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? now
            return (start, end)

        case "last_week", "lastweek":
            let thisWeekStart = calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: now).date ?? now
            let start = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? now
            return (start, thisWeekStart)

        case "this_month", "thismonth":
            let start = calendar.dateComponents([.calendar, .year, .month], from: now).date ?? now
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? now
            return (start, end)

        case "last_month", "lastmonth":
            let thisMonthStart = calendar.dateComponents([.calendar, .year, .month], from: now).date ?? now
            let start = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) ?? now
            return (start, thisMonthStart)

        default:
            return nil
        }
    }

    /// Fallback: Extract basic keyword filters
    nonisolated static func extractKeywordFilters(from query: String) -> SearchFilters {
        var filters = SearchFilters()
        let lowercased = query.lowercased()

        // Check for unread
        if lowercased.contains("unread") {
            filters.unreadOnly = true
        }

        // Check for urgency
        if lowercased.contains("urgent") || lowercased.contains("important") || lowercased.contains("priority") {
            filters.minPriority = 8
        }

        // Check for categories
        for category in Email.EmailCategory.allCases {
            if lowercased.contains(category.rawValue.lowercased()) {
                filters.categories.insert(category)
            }
        }

        // Check for date ranges
        if lowercased.contains("today") {
            filters.dateRange = parseDateRange("today")
        } else if lowercased.contains("this week") || lowercased.contains("thisweek") {
            filters.dateRange = parseDateRange("this_week")
        } else if lowercased.contains("last week") || lowercased.contains("lastweek") {
            filters.dateRange = parseDateRange("last_week")
        }

        // Remaining text becomes search query
        var cleanedQuery = query
        for word in ["unread", "urgent", "important", "priority", "today", "this week", "last week"] {
            cleanedQuery = cleanedQuery.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
        }
        filters.query = cleanedQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        return filters
    }
}

// MARK: - Email Insights AI (Feature 12)

extension AICategorizationEngine {
    /// Generate comprehensive email insights using AI and analytics data
    func generateInsights(emails: [Email], analytics: EmailAnalytics) async -> EmailInsights {
        let fallback = generateBasicInsights(emails: emails, analytics: analytics)

        // Prepare analytics summary for AI
        let summary = generateAnalyticsSummary(emails: emails, analytics: analytics)

        let prompt = """
        Analyze this user's email patterns and generate actionable insights.

        \(summary)

        Generate insights in these categories:

        1. DAILY DIGEST: 2-3 sentence summary of what needs immediate attention
        2. TRENDS: Identify 2-3 significant patterns (increasing, decreasing, stable)
        3. RECOMMENDATIONS: 3-5 actionable recommendations with priority (1-10)
        4. PREDICTIONS: 1-2 predictions about future email patterns

        Respond with JSON:
        {
            "dailyDigest": "You have 3 bills due this week and 12 unread work emails requiring attention.",
            "trends": [
                {"type": "increasing", "category": "Work", "description": "Work email volume up 40% this week", "percentageChange": 40, "isPositive": false}
            ],
            "recommendations": [
                {"priority": 9, "title": "Review overdue bills", "description": "3 bills are overdue, total $450", "actionable": true, "suggestedAction": "Pay bills", "category": "Bills"}
            ],
            "predictions": [
                {"prediction": "You'll receive 15-20 work emails tomorrow based on weekly patterns", "confidence": 0.75, "basis": "Historical weekday average", "category": "Work"}
            ]
        }
        """

        let request = NovaAIRequest(
            prompt: prompt,
            system: "You are an AI email insights analyst. Provide actionable, data-driven insights. Be specific and helpful.",
            temperature: 0.6,
            maxTokens: 1000,
            format: .json
        )
        return await ai.generate(request, validate: { try Self.parseInsights($0) }, fallback: { fallback }).value
    }

    /// Generate analytics summary for AI context
    private func generateAnalyticsSummary(emails: [Email], analytics: EmailAnalytics) -> String {
        let unreadCount = emails.filter { !$0.isRead }.count
        let highPriorityCount = emails.filter { ($0.priority ?? 0) >= 8 }.count

        let categoryBreakdown = Dictionary(grouping: emails) { $0.category ?? .other }
            .map { "\($0.key.rawValue): \($0.value.count)" }
            .joined(separator: ", ")

        let topSenders = analytics.topSenders(limit: 5)
            .map { "\($0.email): \($0.stats.totalEmails) emails" }
            .joined(separator: ", ")

        return """
        CURRENT INBOX STATE:
        - Total emails: \(emails.count)
        - Unread: \(unreadCount)
        - High priority: \(highPriorityCount)
        - Categories: \(categoryBreakdown)

        TOP SENDERS:
        \(topSenders)

        STATISTICS:
        - Daily stats tracked: \(analytics.dailyStats.count) days
        - Unique senders: \(analytics.senderStats.count)
        - Avg response time: \(formatDuration(analytics.responseTimeAvg))
        """
    }

    /// AI insights reply → EmailInsights. A missing digest is rejected; priorities (1...10), confidences (0...1)
    /// and list lengths (5 each) are clamped.
    nonisolated static func parseInsights(_ json: String) throws -> EmailInsights {
        guard let payload = NovaAIText.jsonPayload(json), let data = payload.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NovaAIValidationError("The reply contained no JSON object.")
        }

        let dailyDigest = NovaAIText.plain(dict["dailyDigest"] as? String ?? "", max: 600)
        guard !dailyDigest.isEmpty else { throw NovaAIValidationError("dailyDigest is required") }

        // Parse trends
        var trends: [Trend] = []
        if let trendsArray = dict["trends"] as? [[String: Any]] {
            for trendDict in trendsArray {
                if let typeStr = trendDict["type"] as? String,
                   let type = Trend.TrendType(rawValue: typeStr.capitalized),
                   let description = trendDict["description"] as? String,
                   let percentageChange = trendDict["percentageChange"] as? Double {
                    let category = trendDict["category"] as? String
                    let isPositive = trendDict["isPositive"] as? Bool ?? true
                    trends.append(Trend(type: type, category: category, description: description, percentageChange: percentageChange, isPositive: isPositive))
                }
            }
        }

        // Parse recommendations
        var recommendations: [Recommendation] = []
        if let recsArray = dict["recommendations"] as? [[String: Any]] {
            for recDict in recsArray {
                if let priority = recDict["priority"] as? Int,
                   let title = recDict["title"] as? String,
                   let description = recDict["description"] as? String {
                    let actionable = recDict["actionable"] as? Bool ?? true
                    let suggestedAction = recDict["suggestedAction"] as? String
                    let category = recDict["category"] as? String
                    recommendations.append(Recommendation(priority: min(max(priority, 1), 10), title: title, description: description, actionable: actionable, suggestedAction: suggestedAction, category: category))
                }
            }
        }

        // Parse predictions
        var predictions: [Prediction] = []
        if let predsArray = dict["predictions"] as? [[String: Any]] {
            for predDict in predsArray {
                if let prediction = predDict["prediction"] as? String,
                   let confidence = predDict["confidence"] as? Double,
                   let basis = predDict["basis"] as? String {
                    let category = predDict["category"] as? String
                    predictions.append(Prediction(prediction: prediction, confidence: confidence.isFinite ? min(max(confidence, 0), 1) : 0, basis: basis, category: category))
                }
            }
        }

        return EmailInsights(dailyDigest: dailyDigest, trends: Array(trends.prefix(5)),
                             recommendations: Array(recommendations.prefix(5)), predictions: Array(predictions.prefix(5)))
    }

    /// Generate basic insights without AI
    private func generateBasicInsights(emails: [Email], analytics: EmailAnalytics) -> EmailInsights {
        var insights = EmailInsights()

        // Basic daily digest
        let unreadCount = emails.filter { !$0.isRead }.count
        let highPriorityCount = emails.filter { ($0.priority ?? 0) >= 8 }.count
        let billsCount = emails.filter { $0.category == .bills }.count

        insights.dailyDigest = "You have \(unreadCount) unread emails"
        if highPriorityCount > 0 {
            insights.dailyDigest += ", including \(highPriorityCount) high priority"
        }
        if billsCount > 0 {
            insights.dailyDigest += ". \(billsCount) bills need attention"
        }

        // Basic trend: email volume change
        let thisWeek = analytics.totalEmailsReceived(from: Date().addingTimeInterval(-7*86400), to: Date())
        let lastWeek = analytics.totalEmailsReceived(from: Date().addingTimeInterval(-14*86400), to: Date().addingTimeInterval(-7*86400))

        if lastWeek > 0 {
            let change = Double(thisWeek - lastWeek) / Double(lastWeek) * 100
            if abs(change) > 20 {
                let type: Trend.TrendType = change > 0 ? .increasing : .decreasing
                let trend = Trend(type: type, category: nil, description: "Email volume \(type.rawValue.lowercased()) by \(Int(abs(change)))% this week", percentageChange: abs(change), isPositive: change < 0)
                insights.trends.append(trend)
            }
        }

        // Basic recommendation: clear old marketing
        let oldMarketing = emails.filter {
            $0.category == .marketing &&
            Date().timeIntervalSince($0.dateReceived) > 7*86400
        }.count

        if oldMarketing > 0 {
            insights.recommendations.append(Recommendation(
                priority: 6,
                title: "Clear old marketing emails",
                description: "\(oldMarketing) marketing emails older than 7 days",
                actionable: true,
                suggestedAction: "Bulk delete marketing",
                category: "Marketing"
            ))
        }

        return insights
    }

    /// Format duration for display
    private func formatDuration(_ interval: TimeInterval) -> String {
        if interval < 3600 {
            return "\(Int(interval/60)) minutes"
        } else if interval < 86400 {
            return "\(Int(interval/3600)) hours"
        } else {
            return "\(Int(interval/86400)) days"
        }
    }
}
