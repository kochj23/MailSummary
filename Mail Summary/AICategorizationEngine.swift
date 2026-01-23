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

    /// Categorize email using AI (falls back to keywords if AI unavailable)
    func categorizeEmail(_ email: Email) async -> Email.EmailCategory {
        // Check if AI backend is available
        guard ai.activeBackend != nil else {
            return categorizeWithKeywords(email)
        }

        let bodyPreview = email.body?.prefix(500).description ?? ""

        let prompt = """
        Categorize this email into ONE category.

        Email:
        Subject: \(email.subject)
        Sender: \(email.sender) <\(email.senderEmail)>
        Body: \(bodyPreview)

        Categories: Bills, Orders, Work, Personal, Marketing, Newsletters, Social, Spam, Other

        Respond with JSON:
        {
            "category": "CategoryName",
            "confidence": 0.95
        }
        """

        do {
            let response = try await ai.generate(
                prompt: prompt,
                systemPrompt: "You are an email categorization assistant. Always respond with valid JSON. Be accurate and consistent.",
                temperature: 0.3,  // Low temperature for consistent categorization
                maxTokens: 100
            )

            if let category = parseCategory(from: response) {
                print("🤖 AI categorized as \(category.rawValue)")
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

    /// Score email priority 1-10 using AI (falls back to rules if AI unavailable)
    func scoreEmailPriority(_ email: Email) async -> Int {
        guard ai.activeBackend != nil else {
            return scorePriorityWithRules(email)
        }

        let bodyPreview = email.body?.prefix(300).description ?? ""

        let prompt = """
        Rate the importance/urgency of this email on a scale of 1-10.

        1 = not important at all (spam, newsletters)
        5 = normal personal/work email
        10 = critical/urgent (emergencies, bills due today, deadlines)

        Email:
        Subject: \(email.subject)
        Sender: \(email.sender)
        Category: \(email.category?.rawValue ?? "Unknown")
        Body: \(bodyPreview)

        Respond with JSON:
        {
            "priority": 7,
            "reasoning": "Contains deadline keywords"
        }
        """

        do {
            let response = try await ai.generate(
                prompt: prompt,
                systemPrompt: "You are an expert at assessing email urgency. Be consistent and accurate.",
                temperature: 0.4,
                maxTokens: 150
            )

            if let priority = parsePriority(from: response) {
                print("🤖 AI priority scored as \(priority)")
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
}
