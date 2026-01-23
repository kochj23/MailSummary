//
//  AICategorizationEngine.swift
//  Mail Summary
//
//  AI-powered email categorization and analysis with graceful fallback
//  Uses AIBackendManager (Ollama, TinyLLM, etc.)
//  Created by Jordan Koch on 2026-01-22
//  Updated by Jordan Koch on 2026-01-23 - Added real AI integration
//

import Foundation

@MainActor
class AICategorizationEngine {
    private let ai = AIBackendManager.shared

    // MARK: - AI Categorization

    /// Categorize email using DEEP AI analysis (falls back to keywords if AI unavailable)
    func categorizeEmail(_ email: Email) async -> Email.EmailCategory {
        // Check if AI backend is available
        guard ai.activeBackend != nil else {
            return categorizeWithKeywords(email)
        }

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

        do {
            let response = try await ai.generate(
                prompt: prompt,
                systemPrompt: "You are an expert email categorization system. Analyze content deeply, not just keywords. Always respond with valid JSON.",
                temperature: 0.2,  // Very low for consistent categorization
                maxTokens: 150
            )

            if let category = parseCategory(from: response) {
                print("🤖 AI deep categorized as \(category.rawValue)")
                return category
            }

            // JSON parsing failed, fall back
            print("⚠️ AI response parsing failed, using keywords")
            return categorizeWithKeywords(email)

        } catch {
            print("❌ AI categorization error: \(error.localizedDescription)")
            return categorizeWithKeywords(email)
        }
    }

    /// Score email IMPORTANCE using deep AI analysis (falls back to rules if AI unavailable)
    func scoreEmailPriority(_ email: Email) async -> Int {
        guard ai.activeBackend != nil else {
            return scorePriorityWithRules(email)
        }

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

        do {
            let response = try await ai.generate(
                prompt: prompt,
                systemPrompt: "You are an expert at determining email importance. Consider context, not just keywords. Deadlines and action items are most important. Always respond with valid JSON.",
                temperature: 0.3,  // Low temperature for consistent scoring
                maxTokens: 200
            )

            if let priority = parsePriority(from: response) {
                print("🤖 AI importance scored as \(priority)")
                return priority
            }

            print("⚠️ AI priority parsing failed, using rules")
            return scorePriorityWithRules(email)

        } catch {
            print("❌ AI priority error: \(error.localizedDescription)")
            return scorePriorityWithRules(email)
        }
    }

    /// Generate AI summary for single email
    func generateSummary(for email: Email) async -> String? {
        guard ai.activeBackend != nil, let body = email.body else {
            return nil
        }

        let prompt = """
        Create a brief 1-2 sentence summary of this email for someone who needs to quickly scan their inbox.

        Subject: \(email.subject)
        From: \(email.sender)

        Body:
        \(body.prefix(1000))

        Summary (concise, actionable, 1-2 sentences):
        """

        do {
            let summary = try await ai.generate(
                prompt: prompt,
                systemPrompt: "You are an email summarization expert. Create concise, useful summaries that highlight key information and action items.",
                temperature: 0.5,
                maxTokens: 100
            )

            let cleaned = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            print("🤖 AI summary generated: \(cleaned.prefix(50))...")
            return cleaned

        } catch {
            print("❌ AI summary error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Extract action items from email using AI
    func extractActions(from email: Email) async -> [EmailAction] {
        guard ai.activeBackend != nil, let body = email.body else {
            return []
        }

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

        do {
            let response = try await ai.generate(
                prompt: prompt,
                systemPrompt: "You are an expert at extracting action items and deadlines from emails. Always respond with valid JSON.",
                temperature: 0.3,
                maxTokens: 500
            )

            let actions = parseActions(from: response)
            print("🤖 AI extracted \(actions.count) actions")
            return actions

        } catch {
            print("❌ AI action extraction error: \(error.localizedDescription)")
            return []
        }
    }

    /// Generate overall mailbox summary using AI
    func generateOverallSummary(emails: [Email], stats: MailboxStats) async -> String {
        guard ai.activeBackend != nil else {
            return generateBasicSummary(emails: emails, stats: stats)
        }

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

        do {
            let summary = try await ai.generate(
                prompt: prompt,
                systemPrompt: "You are a helpful email assistant. Provide actionable mailbox summaries that highlight what's important.",
                temperature: 0.6,
                maxTokens: 150
            )

            return summary.trimmingCharacters(in: .whitespacesAndNewlines)

        } catch {
            print("❌ AI overall summary error: \(error.localizedDescription)")
            return generateBasicSummary(emails: emails, stats: stats)
        }
    }

    // MARK: - JSON Parsing

    /// Parse category from AI JSON response
    private func parseCategory(from json: String) -> Email.EmailCategory? {
        // Try to extract JSON
        guard let jsonData = json.data(using: .utf8) else { return nil }

        do {
            if let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let categoryStr = dict["category"] as? String {
                // Normalize and map to enum
                let normalized = categoryStr.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

                switch normalized {
                case "bills": return .bills
                case "orders": return .orders
                case "work": return .work
                case "personal": return .personal
                case "marketing": return .marketing
                case "newsletters": return .newsletters
                case "social": return .social
                case "spam": return .spam
                default: return .other
                }
            }
        } catch {
            // Try regex fallback
            if let range = json.range(of: #""category"\s*:\s*"([^"]+)""#, options: .regularExpression) {
                let categoryStr = String(json[range]).replacingOccurrences(of: "\"category\":", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return Email.EmailCategory(rawValue: categoryStr)
            }
        }

        return nil
    }

    /// Parse priority from AI JSON response
    private func parsePriority(from json: String) -> Int? {
        guard let jsonData = json.data(using: .utf8) else { return nil }

        do {
            if let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let priority = dict["priority"] as? Int {
                return min(max(priority, 1), 10)  // Clamp to 1-10
            }
        } catch {
            // Try regex fallback
            if let range = json.range(of: #""priority"\s*:\s*(\d+)"#, options: .regularExpression) {
                let priorityStr = String(json[range]).replacingOccurrences(of: "\"priority\":", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let priority = Int(priorityStr) {
                    return min(max(priority, 1), 10)
                }
            }
        }

        return nil
    }

    /// Parse actions array from AI JSON response
    private func parseActions(from json: String) -> [EmailAction] {
        guard let jsonData = json.data(using: .utf8) else { return [] }

        do {
            if let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let actionsArray = dict["actions"] as? [[String: Any]] {

                var actions: [EmailAction] = []

                for actionDict in actionsArray {
                    guard let typeStr = actionDict["type"] as? String,
                          let text = actionDict["text"] as? String else {
                        continue
                    }

                    // Parse type
                    let type: EmailAction.ActionType
                    switch typeStr.lowercased() {
                    case "deadline": type = .deadline
                    case "meeting": type = .meeting
                    case "task": type = .task
                    case "reminder": type = .reminder
                    default: type = .task
                    }

                    // Parse optional date
                    var date: Date? = nil
                    if let dateStr = actionDict["date"] as? String {
                        let formatter = ISO8601DateFormatter()
                        date = formatter.date(from: dateStr)
                    }

                    actions.append(EmailAction(type: type, text: text, date: date))
                }

                return actions
            }
        } catch {
            print("⚠️ Failed to parse actions JSON: \(error)")
        }

        return []
    }

    // MARK: - Fallback Methods (Keyword-Based)

    /// Categorize email using keyword matching (fallback when AI unavailable)
    private func categorizeWithKeywords(_ email: Email) -> Email.EmailCategory {
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

    /// Score email priority using rules (fallback when AI unavailable)
    private func scorePriorityWithRules(_ email: Email) -> Int {
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

    /// Generate basic summary without AI
    private func generateBasicSummary(emails: [Email], stats: MailboxStats) -> String {
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
        guard ai.activeBackend != nil else {
            return 0.5  // Neutral reputation
        }

        // Get sender's email history
        let senderEmails = emailHistory.filter { $0.senderEmail == email.senderEmail }
        let replyRate = calculateReplyRate(for: email.senderEmail, in: emailHistory)
        let openRate = calculateOpenRate(for: email.senderEmail, in: emailHistory)

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

        do {
            let response = try await ai.generate(
                prompt: prompt,
                systemPrompt: "You are analyzing sender patterns to determine importance. Be data-driven.",
                temperature: 0.3,
                maxTokens: 150
            )

            if let dict = try? JSONSerialization.jsonObject(with: response.data(using: .utf8)!, options: []) as? [String: Any],
               let importance = dict["importance"] as? Double {
                return min(max(importance, 0.0), 1.0)
            }

            return 0.5

        } catch {
            return 0.5
        }
    }

    /// Detect actionable items in email
    func detectActionableFactors(_ email: Email) async -> ActionableFactors {
        guard ai.activeBackend != nil, let body = email.body else {
            return ActionableFactors()
        }

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

        do {
            let response = try await ai.generate(
                prompt: prompt,
                systemPrompt: "You are an expert at extracting actionable information from emails. Be precise.",
                temperature: 0.2,
                maxTokens: 300
            )

            return parseActionableFactors(response)

        } catch {
            return ActionableFactors()
        }
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

    private func parseActionableFactors(_ json: String) -> ActionableFactors {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ActionableFactors()
        }

        return ActionableFactors(
            hasDeadline: dict["hasDeadline"] as? Bool ?? false,
            hasMeeting: dict["hasMeeting"] as? Bool ?? false,
            requiresResponse: dict["requiresResponse"] as? Bool ?? false,
            hasPayment: dict["hasPayment"] as? Bool ?? false,
            urgencyScore: dict["urgencyScore"] as? Double ?? 0.0
        )
    }
}

/// Actionable factors detected in email
struct ActionableFactors {
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
