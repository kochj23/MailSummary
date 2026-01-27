import Foundation

//
//  ThreadIntelligenceEngine.swift
//  Mail Summary
//
//  THE LEGENDARY FEATURE: Email Thread Intelligence
//  Summarize long threads, extract decisions, predict outcomes
//
//  Author: Jordan Koch
//  Date: 2026-01-26
//

@MainActor
class ThreadIntelligenceEngine: ObservableObject {

    static let shared = ThreadIntelligenceEngine()

    @Published var isProcessing = false
    @Published var threadCache: [String: ThreadAnalysis] = [:]

    private init() {}

    // MARK: - Thread Summarization

    func summarizeThread(_ emails: [Email]) async throws -> ThreadSummary {

        guard !emails.isEmpty else {
            throw ThreadError.emptyThread
        }

        isProcessing = true
        defer { isProcessing = false }

        // Sort by date
        let sortedEmails = emails.sorted { $0.dateReceived < $1.dateReceived }

        // Extract thread content
        let threadContent = sortedEmails.map { email -> String in
            """
            From: \(email.sender)
            Date: \(email.dateReceived.formatted())
            Subject: \(email.subject)
            Body: \(email.body ?? "")
            ---
            """
        }.joined(separator: "\n\n")

        // Generate AI summary
        let prompt = """
        Summarize this email thread. Provide:
        1. A 2-3 sentence overview
        2. Key points discussed (bullet list)
        3. Current status (open/resolved/waiting)
        4. Next steps or actions needed

        Thread (\(sortedEmails.count) emails):
        \(threadContent)

        Summary (JSON):
        {
          "overview": "...",
          "keyPoints": ["...", "..."],
          "status": "open|resolved|waiting",
          "nextSteps": ["...", "..."]
        }
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You summarize email threads concisely and extract actionable information.",
            temperature: 0.3,
            maxTokens: 500
        )

        let summaryData = try parseSummaryResponse(response)

        return ThreadSummary(
            threadId: sortedEmails.first!.id,
            overview: summaryData.overview,
            keyPoints: summaryData.keyPoints,
            status: summaryData.status,
            nextSteps: summaryData.nextSteps,
            participantCount: countUniqueParticipants(sortedEmails),
            messageCount: sortedEmails.count,
            dateRange: (sortedEmails.first!.dateReceived, sortedEmails.last!.dateReceived)
        )
    }

    // MARK: - Action Item Extraction

    func extractActionItems(_ emails: [Email]) async throws -> [ActionItem] {

        guard !emails.isEmpty else {
            return []
        }

        isProcessing = true
        defer { isProcessing = false }

        let sortedEmails = emails.sorted { $0.dateReceived < $1.dateReceived }

        let threadContent = sortedEmails.map { email -> String in
            """
            From: \(email.sender) (\(email.dateReceived.formatted()))
            \(email.body ?? "")
            """
        }.joined(separator: "\n\n---\n\n")

        let prompt = """
        Extract all action items, decisions, and deadlines from this email thread.

        Thread:
        \(threadContent)

        Return JSON array:
        [
          {
            "type": "task|decision|deadline|meeting",
            "description": "...",
            "assignedTo": "person name or null",
            "dueDate": "ISO8601 or null",
            "status": "pending|completed",
            "priority": "high|medium|low"
          }
        ]
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You extract action items from email threads. Be thorough and specific.",
            temperature: 0.2,
            maxTokens: 600
        )

        return try parseActionItems(response)
    }

    // MARK: - Thread Pattern Detection

    func detectThreadPatterns(_ emails: [Email]) async throws -> [ThreadPattern] {

        guard emails.count >= 3 else {
            return []
        }

        var patterns: [ThreadPattern] = []

        // Pattern 1: Rapid Back-and-Forth
        let sortedEmails = emails.sorted { $0.dateReceived < $1.dateReceived }
        var rapidExchanges = 0

        for i in 1..<sortedEmails.count {
            let timeDiff = sortedEmails[i].dateReceived.timeIntervalSince(sortedEmails[i-1].dateReceived)
            if timeDiff < 300 { // 5 minutes
                rapidExchanges += 1
            }
        }

        if rapidExchanges >= 3 {
            patterns.append(ThreadPattern(
                type: .rapidBackAndForth,
                description: "\(rapidExchanges) rapid exchanges detected",
                significance: "High engagement - requires attention"
            ))
        }

        // Pattern 2: Long Silence
        if let lastEmail = sortedEmails.last {
            let daysSinceLastReply = Calendar.current.dateComponents([.day], from: lastEmail.dateReceived, to: Date()).day ?? 0

            if daysSinceLastReply > 7 {
                patterns.append(ThreadPattern(
                    type: .stalled,
                    description: "No activity for \(daysSinceLastReply) days",
                    significance: "Thread may have stalled - consider follow-up"
                ))
            }
        }

        // Pattern 3: Escalation (many participants)
        let participants = countUniqueParticipants(sortedEmails)
        if participants > 5 {
            patterns.append(ThreadPattern(
                type: .escalating,
                description: "\(participants) participants involved",
                significance: "High visibility - important decision"
            ))
        }

        // Pattern 4: Question Loop (unanswered questions)
        let questionCount = emails.filter { email in
            (email.body ?? "").contains("?")
        }.count

        if questionCount >= 3 {
            patterns.append(ThreadPattern(
                type: .questionLoop,
                description: "\(questionCount) questions in thread",
                significance: "Multiple unresolved questions - needs clarity"
            ))
        }

        return patterns
    }

    // MARK: - Thread Outcome Prediction

    func predictOutcome(_ emails: [Email]) async throws -> ThreadOutcomePrediction {

        guard emails.count >= 2 else {
            return ThreadOutcomePrediction(
                outcome: .unknown,
                confidence: 0.0,
                reasoning: "Not enough emails to predict",
                expectedResolutionDate: nil
            )
        }

        isProcessing = true
        defer { isProcessing = false }

        let sortedEmails = emails.sorted { $0.dateReceived < $1.dateReceived }

        let threadContent = sortedEmails.map { email -> String in
            "[\(email.dateReceived.formatted())] \(email.sender): \(email.body ?? "")"
        }.joined(separator: "\n")

        let prompt = """
        Analyze this email thread and predict the outcome.

        Thread:
        \(threadContent)

        Predict:
        1. Outcome: will_resolve|will_escalate|will_stall|needs_intervention
        2. Confidence: 0.0-1.0
        3. Reasoning: why you predict this outcome
        4. Expected resolution: days from now (or null)

        JSON:
        {
          "outcome": "...",
          "confidence": 0.8,
          "reasoning": "...",
          "daysToResolution": 5
        }
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You predict email thread outcomes based on communication patterns.",
            temperature: 0.4,
            maxTokens: 300
        )

        return try parseOutcomePrediction(response)
    }

    // MARK: - Thread Analysis (Complete)

    func analyzeThread(_ emails: [Email]) async throws -> ThreadAnalysis {

        let threadId = generateThreadId(emails)

        // Check cache
        if let cached = threadCache[threadId] {
            return cached
        }

        isProcessing = true
        defer { isProcessing = false }

        // Parallel analysis
        async let summary = summarizeThread(emails)
        async let actionItems = extractActionItems(emails)
        async let patterns = detectThreadPatterns(emails)
        async let outcome = predictOutcome(emails)

        let (summaryResult, actionItemsResult, patternsResult, outcomeResult) = try await (
            summary,
            actionItems,
            patterns,
            outcome
        )

        let analysis = ThreadAnalysis(
            threadId: threadId,
            summary: summaryResult,
            actionItems: actionItemsResult,
            patterns: patternsResult,
            outcomePrediction: outcomeResult,
            participantCount: countUniqueParticipants(emails),
            totalMessages: emails.count,
            analyzedAt: Date()
        )

        // Cache result
        threadCache[threadId] = analysis

        return analysis
    }

    // MARK: - Thread Insights

    func generateThreadInsights(_ analysis: ThreadAnalysis) -> [ThreadInsight] {

        var insights: [ThreadInsight] = []

        // Insight 1: Thread complexity
        if analysis.totalMessages > 10 {
            insights.append(ThreadInsight(
                type: .complexity,
                title: "Long Thread",
                description: "This thread has \(analysis.totalMessages) messages - consider scheduling a call",
                priority: .medium
            ))
        }

        // Insight 2: Action overload
        if analysis.actionItems.count > 5 {
            insights.append(ThreadInsight(
                type: .actionOverload,
                title: "Many Action Items",
                description: "\(analysis.actionItems.count) action items identified - prioritize",
                priority: .high
            ))
        }

        // Insight 3: Stalled thread
        if analysis.patterns.contains(where: { $0.type == .stalled }) {
            insights.append(ThreadInsight(
                type: .stalled,
                title: "Thread Stalled",
                description: "No recent activity - send follow-up",
                priority: .high
            ))
        }

        // Insight 4: High engagement
        if analysis.patterns.contains(where: { $0.type == .rapidBackAndForth }) {
            insights.append(ThreadInsight(
                type: .highEngagement,
                title: "Active Discussion",
                description: "High engagement detected - important topic",
                priority: .medium
            ))
        }

        // Insight 5: Needs resolution
        if analysis.outcomePrediction.outcome == .needsIntervention {
            insights.append(ThreadInsight(
                type: .needsIntervention,
                title: "Requires Intervention",
                description: analysis.outcomePrediction.reasoning,
                priority: .critical
            ))
        }

        return insights
    }

    // MARK: - Helpers

    private func countUniqueParticipants(_ emails: [Email]) -> Int {
        let senders = Set(emails.map { $0.senderEmail })
        return senders.count
    }

    private func generateThreadId(_ emails: [Email]) -> String {
        // Use subject + first email ID
        guard let firstEmail = emails.first else { return UUID().uuidString }
        return "\(firstEmail.subject)-\(firstEmail.id)"
    }

    // MARK: - Parsing Helpers

    private func parseSummaryResponse(_ response: String) throws -> (overview: String, keyPoints: [String], status: ThreadStatus, nextSteps: [String]) {

        // Attempt JSON parsing
        if let jsonData = response.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {

            let overview = json["overview"] as? String ?? "No summary available"
            let keyPoints = json["keyPoints"] as? [String] ?? []
            let statusString = json["status"] as? String ?? "open"
            let nextSteps = json["nextSteps"] as? [String] ?? []

            let status = ThreadStatus(rawValue: statusString) ?? .open

            return (overview, keyPoints, status, nextSteps)
        }

        // Fallback: parse text
        return (
            overview: response,
            keyPoints: [],
            status: .open,
            nextSteps: []
        )
    }

    private func parseActionItems(_ response: String) throws -> [ActionItem] {

        // Attempt JSON parsing
        if let jsonData = response.data(using: .utf8),
           let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {

            return jsonArray.compactMap { dict in
                guard let typeString = dict["type"] as? String,
                      let description = dict["description"] as? String else {
                    return nil
                }

                let type = ActionItem.ActionType(rawValue: typeString) ?? .task
                let assignedTo = dict["assignedTo"] as? String
                let statusString = dict["status"] as? String ?? "pending"
                let status = ActionItem.Status(rawValue: statusString) ?? .pending
                let priorityString = dict["priority"] as? String ?? "medium"
                let priority = ActionItem.Priority(rawValue: priorityString) ?? .medium

                // Parse due date
                var dueDate: Date?
                if let dueDateString = dict["dueDate"] as? String {
                    let formatter = ISO8601DateFormatter()
                    dueDate = formatter.date(from: dueDateString)
                }

                return ActionItem(
                    type: type,
                    description: description,
                    assignedTo: assignedTo,
                    dueDate: dueDate,
                    status: status,
                    priority: priority
                )
            }
        }

        return []
    }

    private func parseOutcomePrediction(_ response: String) throws -> ThreadOutcomePrediction {

        // Attempt JSON parsing
        if let jsonData = response.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {

            let outcomeString = json["outcome"] as? String ?? "unknown"
            let outcome = ThreadOutcome(rawValue: outcomeString) ?? .unknown
            let confidence = json["confidence"] as? Double ?? 0.5
            let reasoning = json["reasoning"] as? String ?? ""
            let daysToResolution = json["daysToResolution"] as? Int

            var expectedDate: Date?
            if let days = daysToResolution {
                expectedDate = Calendar.current.date(byAdding: .day, value: days, to: Date())
            }

            return ThreadOutcomePrediction(
                outcome: outcome,
                confidence: confidence,
                reasoning: reasoning,
                expectedResolutionDate: expectedDate
            )
        }

        // Fallback
        return ThreadOutcomePrediction(
            outcome: .unknown,
            confidence: 0.5,
            reasoning: response,
            expectedResolutionDate: nil
        )
    }
}

// MARK: - Models

struct ThreadAnalysis {
    let threadId: String
    let summary: ThreadSummary
    let actionItems: [ActionItem]
    let patterns: [ThreadPattern]
    let outcomePrediction: ThreadOutcomePrediction
    let participantCount: Int
    let totalMessages: Int
    let analyzedAt: Date
}

struct ThreadSummary {
    let threadId: Int
    let overview: String
    let keyPoints: [String]
    let status: ThreadStatus
    let nextSteps: [String]
    let participantCount: Int
    let messageCount: Int
    let dateRange: (start: Date, end: Date)
}

enum ThreadStatus: String {
    case open = "open"
    case resolved = "resolved"
    case waiting = "waiting"
    case stalled = "stalled"
}

struct ActionItem: Identifiable {
    let id = UUID()
    let type: ActionType
    let description: String
    let assignedTo: String?
    let dueDate: Date?
    let status: Status
    let priority: Priority

    enum ActionType: String {
        case task = "task"
        case decision = "decision"
        case deadline = "deadline"
        case meeting = "meeting"
    }

    enum Status: String {
        case pending = "pending"
        case completed = "completed"
        case overdue = "overdue"
    }

    enum Priority: String {
        case high = "high"
        case medium = "medium"
        case low = "low"

        var color: String {
            switch self {
            case .high: return "red"
            case .medium: return "orange"
            case .low: return "green"
            }
        }
    }
}

struct ThreadPattern {
    let type: PatternType
    let description: String
    let significance: String

    enum PatternType {
        case rapidBackAndForth
        case stalled
        case escalating
        case questionLoop
        case agreement
        case disagreement
    }
}

struct ThreadOutcomePrediction {
    let outcome: ThreadOutcome
    let confidence: Double // 0.0-1.0
    let reasoning: String
    let expectedResolutionDate: Date?

    var confidencePercent: Int {
        Int(confidence * 100)
    }
}

enum ThreadOutcome: String {
    case willResolve = "will_resolve"
    case willEscalate = "will_escalate"
    case willStall = "will_stall"
    case needsIntervention = "needs_intervention"
    case unknown = "unknown"

    var color: String {
        switch self {
        case .willResolve: return "green"
        case .willEscalate: return "orange"
        case .willStall: return "yellow"
        case .needsIntervention: return "red"
        case .unknown: return "gray"
        }
    }

    var displayText: String {
        switch self {
        case .willResolve: return "Will Resolve"
        case .willEscalate: return "Will Escalate"
        case .willStall: return "Will Stall"
        case .needsIntervention: return "Needs Intervention"
        case .unknown: return "Unknown"
        }
    }
}

struct ThreadInsight {
    let type: InsightType
    let title: String
    let description: String
    let priority: Priority

    enum InsightType {
        case complexity
        case actionOverload
        case stalled
        case highEngagement
        case needsIntervention
    }

    enum Priority {
        case critical
        case high
        case medium
        case low
    }
}

enum ThreadError: LocalizedError {
    case emptyThread
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .emptyThread:
            return "Thread contains no emails"
        case .parsingFailed:
            return "Failed to parse thread analysis"
        }
    }
}

// Placeholder types
typealias Email = EmailModels.Email
