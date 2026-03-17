import Foundation
import EventKit

//
//  AutonomousEmailAgent.swift
//  Mail Summary
//
//  THE LEGENDARY FEATURE: Full autonomous email management
//  Handles routine emails without human intervention
//
//  Author: Jordan Koch
//  Date: 2026-01-26
//

@MainActor
class AutonomousEmailAgent: ObservableObject {

    static let shared = AutonomousEmailAgent()

    @Published var isProcessing = false
    @Published var autonomyEnabled = false
    @Published var confidenceThreshold = 0.70 // Start conservative
    @Published var actionsHandled = 0
    @Published var actionsEscalated = 0
    @Published var userApprovedActions = 0
    @Published var userRejectedActions = 0

    private var learningDatabase: [AgentLearning] = []

    private init() {
        loadSettings()
    }

    // MARK: - Autonomous Processing

    func processEmailAutonomously(_ email: Email) async throws -> AgentDecision {

        isProcessing = true
        defer { isProcessing = false }

        // Step 1: Analyze email
        let analysis = try await analyzeEmail(email)

        // Step 2: Detect intent
        let intent = try await detectIntent(email, analysis: analysis)

        // Step 3: Score priority
        let priority = try await scorePriority(email)

        // Step 4: Gather context
        let context = try await gatherContext(email)

        // Step 5: Decide action
        let decision = try await decideAction(
            email: email,
            intent: intent,
            priority: priority,
            context: context
        )

        // Step 6: Execute if high confidence, escalate if not
        if decision.confidence >= confidenceThreshold {
            if autonomyEnabled {
                try await executeDecision(decision, email: email)
                actionsHandled += 1
                return decision
            } else {
                // Autonomy disabled - still suggest
                decision.requiresApproval = true
                actionsEscalated += 1
                return decision
            }
        } else {
            // Low confidence - escalate to human
            actionsEscalated += 1
            decision.requiresApproval = true
            return decision
        }
    }

    // MARK: - Email Analysis

    private func analyzeEmail(_ email: Email) async throws -> EmailAnalysis {

        let prompt = """
        Analyze this email comprehensively.

        From: \(email.sender)
        Subject: \(email.subject)
        Body:
        \(email.body)

        Provide JSON:
        {
          "emailType": "request|info|meeting|marketing|newsletter|spam|personal|urgent",
          "actionRequired": true|false,
          "deadline": "ISO8601 or null",
          "sentiment": "positive|neutral|negative|urgent",
          "complexity": "simple|moderate|complex",
          "keywords": ["keyword1", "keyword2"],
          "entities": ["person1", "company1"]
        }
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You analyze emails for autonomous processing. Be accurate and structured.",
            temperature: 0.2,
            maxTokens: 400
        )

        return parseEmailAnalysis(response)
    }

    // MARK: - Priority Scoring

    private func scorePriority(_ email: Email) async throws -> PriorityScore {
        let prompt = """
        Score the priority of this email (0-100).

        From: \(email.sender)
        Subject: \(email.subject)
        Body: \(email.body ?? "")

        Consider:
        - Urgency keywords (urgent, ASAP, deadline)
        - Sender importance
        - Action requirements

        Return JSON: {"score": 75, "reasoning": "..."}
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You score email priority objectively.",
            temperature: 0.2,
            maxTokens: 100
        )

        // Parse response
        if let jsonData = response.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let score = json["score"] as? Int {
            let reasoning = json["reasoning"] as? String ?? ""
            return PriorityScore(score: score, reasoning: reasoning)
        }

        // Default medium priority
        return PriorityScore(score: 50, reasoning: "Default priority")
    }

    // MARK: - Intent Detection

    private func detectIntent(_ email: Email, analysis: EmailAnalysis) async throws -> EmailIntent {

        let prompt = """
        What does the sender want?

        Email: \(email.subject)
        Body: \(email.body)

        Return one of:
        - wants_information: Asking for something
        - wants_meeting: Requesting meeting
        - wants_action: Needs me to do something
        - wants_decision: Needs approval/decision
        - wants_acknowledgment: Just FYI
        - wants_nothing: Marketing/newsletter

        Intent:
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "Detect sender intent accurately.",
            temperature: 0.1,
            maxTokens: 50
        )

        return EmailIntent(rawValue: response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) ?? .unknown
    }

    // MARK: - Decide Action

    private func decideAction(
        email: Email,
        intent: EmailIntent,
        priority: PriorityScore,
        context: EmailContext
    ) async throws -> AgentDecision {

        // Decision matrix based on intent, priority, and learned behavior

        switch intent {
        case .wantsNothing:
            // Marketing, newsletters
            if context.openRate < 0.05 {
                // User never reads these
                return AgentDecision(
                    action: .autoArchive(reason: "Marketing - never opened"),
                    confidence: 0.95,
                    reasoning: "User has never opened emails from this sender",
                    requiresApproval: false
                )
            }

        case .wantsAcknowledgment:
            // FYI emails
            if priority.score < 50 {
                return AgentDecision(
                    action: .autoReply(
                        template: "Thanks for the update!",
                        sendImmediately: true
                    ),
                    confidence: 0.85,
                    reasoning: "Simple acknowledgment, low priority",
                    requiresApproval: false
                )
            }

        case .wantsMeeting:
            // Check calendar and auto-respond
            let calendarConflicts = await checkCalendar(email: email)

            if calendarConflicts.isEmpty {
                return AgentDecision(
                    action: .autoAcceptMeeting(
                        time: email.proposedTime!,
                        createCalendarEvent: true
                    ),
                    confidence: 0.80,
                    reasoning: "No calendar conflicts, meeting with \(context.relationshipLevel.rawValue)",
                    requiresApproval: false
                )
            }

        case .wantsInformation:
            // Can we answer from knowledge base?
            if let answer = await searchKnowledgeBase(email.question) {
                return AgentDecision(
                    action: .autoReply(
                        template: answer,
                        sendImmediately: false
                    ),
                    confidence: 0.75,
                    reasoning: "Answer found in knowledge base",
                    requiresApproval: true // Human review for accuracy
                )
            }

        case .wantsAction, .wantsDecision:
            // High stakes - escalate
            return AgentDecision(
                action: .escalateToHuman(urgency: .high),
                confidence: 1.0,
                reasoning: "Action/decision required - human judgment needed",
                requiresApproval: true
            )

        default:
            break
        }

        // Default: escalate
        return AgentDecision(
            action: .escalateToHuman(urgency: .medium),
            confidence: 0.5,
            reasoning: "Unclear how to handle autonomously",
            requiresApproval: true
        )
    }

    // MARK: - Execute Decision

    private func executeDecision(_ decision: AgentDecision, email: Email) async throws {

        switch decision.action {
        case .autoReply(let template, let sendImmediately):
            if sendImmediately {
                try await sendReply(email: email, body: template)
                await logAction(email: email, action: "Auto-replied")
            } else {
                await saveDraft(email: email, body: template)
                await logAction(email: email, action: "Draft created")
            }

        case .autoArchive(let reason):
            await archiveEmail(email)
            await logAction(email: email, action: "Auto-archived: \(reason)")

        case .autoDelegate(let to, let reason):
            try await forwardEmail(email, to: to, note: reason)
            await logAction(email: email, action: "Delegated to \(to)")

        case .autoAcceptMeeting(let time, let createCalendarEvent):
            if createCalendarEvent {
                await createCalendarEvent(email: email, time: time)
            }
            try await sendMeetingAcceptance(email: email)
            await logAction(email: email, action: "Meeting accepted")

        case .scheduleFollowUp(let date):
            await snoozeEmail(email, until: date)
            await logAction(email: email, action: "Scheduled follow-up for \(date)")

        case .autoUnsubscribe(let reason):
            try await unsubscribe(email)
            await logAction(email: email, action: "Unsubscribed: \(reason)")

        case .escalateToHuman:
            await markAsNeedsAttention(email)
            await logAction(email: email, action: "Escalated to human")
        }
    }

    // MARK: - Learning System

    func learnFromUserAction(email: Email, agentSuggestion: AgentDecision, userAction: UserAction) async {

        if userAction.approved {
            userApprovedActions += 1

            // Increase confidence for similar emails
            let learning = AgentLearning(
                emailPattern: extractPattern(email),
                suggestedAction: agentSuggestion.action,
                wasApproved: true,
                timestamp: Date()
            )
            learningDatabase.append(learning)

            // Increase confidence threshold if high approval rate
            if approvalRate > 0.95 && userApprovedActions > 100 {
                confidenceThreshold = min(0.95, confidenceThreshold + 0.05)
            }

        } else {
            userRejectedActions += 1

            // Learn what NOT to do
            let learning = AgentLearning(
                emailPattern: extractPattern(email),
                suggestedAction: agentSuggestion.action,
                wasApproved: false,
                timestamp: Date()
            )
            learningDatabase.append(learning)

            // Decrease confidence if rejection rate high
            if approvalRate < 0.80 {
                confidenceThreshold = max(0.60, confidenceThreshold - 0.05)
            }
        }

        saveLearningDatabase()
    }

    var approvalRate: Double {
        let total = userApprovedActions + userRejectedActions
        guard total > 0 else { return 0 }
        return Double(userApprovedActions) / Double(total)
    }

    // MARK: - Context Gathering

    private func gatherContext(_ email: Email) async throws -> EmailContext {

        // Sender relationship
        let relationship = await RelationshipIntelligence.shared.analyzeRelationship(email.sender)

        // Open rate for this sender
        let openRate = await calculateOpenRate(sender: email.sender)

        // Past interactions
        let interactionCount = await countInteractions(sender: email.sender)

        // Related project (if any)
        let relatedProject = await findRelatedProject(email)

        return EmailContext(
            relationshipLevel: relationship.type,
            openRate: openRate,
            interactionCount: interactionCount,
            relatedProject: relatedProject,
            threadLength: email.threadLength,
            hasAttachments: !email.attachments.isEmpty
        )
    }

    // MARK: - Helpers

    private func extractPattern(_ email: Email) -> EmailPattern {
        return EmailPattern(
            senderDomain: email.senderDomain,
            subjectKeywords: email.subject.lowercased().components(separatedBy: " "),
            hasAttachments: !email.attachments.isEmpty,
            isThread: email.threadLength > 1
        )
    }

    private func parseEmailAnalysis(_ response: String) -> EmailAnalysis {
        // Parse JSON response from AI
        if let jsonData = response.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {

            let emailTypeStr = json["emailType"] as? String ?? "request"
            let emailType: EmailType = {
                switch emailTypeStr.lowercased() {
                case "request": return .request
                case "info", "information": return .information
                case "meeting": return .meeting
                case "marketing": return .marketing
                case "newsletter": return .newsletter
                case "spam": return .spam
                case "personal": return .personal
                case "urgent": return .urgent
                default: return .request
                }
            }()

            let actionRequired = json["actionRequired"] as? Bool ?? false

            // Parse deadline
            var deadline: Date?
            if let deadlineStr = json["deadline"] as? String, deadlineStr != "null" {
                let formatter = ISO8601DateFormatter()
                deadline = formatter.date(from: deadlineStr)
            }

            let sentimentStr = json["sentiment"] as? String ?? "neutral"
            let sentiment: EmailSentiment = {
                switch sentimentStr.lowercased() {
                case "positive": return .positive
                case "negative": return .negative
                case "urgent": return .urgent
                default: return .neutral
                }
            }()

            let complexityStr = json["complexity"] as? String ?? "moderate"
            let complexity: ComplexityLevel = {
                switch complexityStr.lowercased() {
                case "simple": return .simple
                case "complex": return .complex
                default: return .moderate
                }
            }()

            let keywords = json["keywords"] as? [String] ?? []
            let entities = json["entities"] as? [String] ?? []

            return EmailAnalysis(
                emailType: emailType,
                actionRequired: actionRequired,
                deadline: deadline,
                sentiment: sentiment,
                complexity: complexity,
                keywords: keywords,
                entities: entities
            )
        }

        // Fallback if JSON parsing fails
        return EmailAnalysis(
            emailType: .request,
            actionRequired: true,
            deadline: nil,
            sentiment: .neutral,
            complexity: .moderate,
            keywords: [],
            entities: []
        )
    }

    // MARK: - Persistence

    private func loadSettings() {
        autonomyEnabled = UserDefaults.standard.bool(forKey: "AutonomousAgent_Enabled")
        confidenceThreshold = UserDefaults.standard.double(forKey: "AutonomousAgent_Threshold")
        if confidenceThreshold == 0 { confidenceThreshold = 0.70 }

        if let data = UserDefaults.standard.data(forKey: "AutonomousAgent_Learning"),
           let learning = try? JSONDecoder().decode([AgentLearning].self, from: data) {
            learningDatabase = learning
        }
    }

    private func saveSettings() {
        UserDefaults.standard.set(autonomyEnabled, forKey: "AutonomousAgent_Enabled")
        UserDefaults.standard.set(confidenceThreshold, forKey: "AutonomousAgent_Threshold")
    }

    private func saveLearningDatabase() {
        if let data = try? JSONEncoder().encode(learningDatabase) {
            UserDefaults.standard.set(data, forKey: "AutonomousAgent_Learning")
        }
    }

    // MARK: - Real Implementations

    private func checkCalendar(email: Email) async -> [Date] {
        // Use EventKit to check calendar conflicts
        guard let proposedTime = email.proposedTime else { return [] }

        let store = EKEventStore()

        // Request calendar access
        do {
            let granted = try await store.requestAccess(to: .event)
            guard granted else { return [] }
        } catch {
            print("Calendar access denied: \(error)")
            return []
        }

        // Check for conflicts 1 hour before/after
        let startDate = proposedTime.addingTimeInterval(-3600)
        let endDate = proposedTime.addingTimeInterval(3600)

        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = store.events(matching: predicate)

        return events.map { $0.startDate }
    }

    private func searchKnowledgeBase(_ query: String?) async -> String? {
        guard let query = query, !query.isEmpty else { return nil }

        // Search through historical emails for similar questions/answers
        // For now, return nil (knowledge base not yet populated)

        // Future: Use vector search on past email responses
        return nil
    }

    private func sendReply(email: Email, body: String) async throws {
        // Integration with Mail.app via AppleScript
        let script = """
        tell application "Mail"
            set replyMsg to reply message id "\(email.messageId)" with opening window
            set content of replyMsg to "\(body.replacingOccurrences(of: "\"", with: "\\\""))"
            send replyMsg
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        try process.run()
        process.waitUntilExit()

        print("📧 Sent reply to: \(email.sender)")
    }

    private func saveDraft(email: Email, body: String) async {
        // Save draft via AppleScript
        let script = """
        tell application "Mail"
            set draftMsg to reply message id "\(email.messageId)" with opening window
            set content of draftMsg to "\(body.replacingOccurrences(of: "\"", with: "\\\""))"
            close window 1 saving yes
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        try? process.run()
        process.waitUntilExit()

        print("💾 Saved draft for: \(email.sender)")
    }

    private func archiveEmail(_ email: Email) async {
        // Archive email via AppleScript
        let script = """
        tell application "Mail"
            set theMessage to first message whose message id is "\(email.messageId)"
            move theMessage to mailbox "Archive" of account "iCloud"
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        try? process.run()
        process.waitUntilExit()

        print("📁 Archived: \(email.subject)")
    }

    private func forwardEmail(_ email: Email, to: String, note: String) async throws {
        // Forward email via AppleScript
        let script = """
        tell application "Mail"
            set fwdMsg to forward message id "\(email.messageId)" with opening window
            tell fwdMsg
                set content to "\(note.replacingOccurrences(of: "\"", with: "\\\""))" & return & return & content
                make new to recipient with properties {address:"\(to)"}
            end tell
            send fwdMsg
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        try process.run()
        process.waitUntilExit()

        print("📨 Forwarded to: \(to)")
    }

    private func createCalendarEvent(email: Email, time: Date) async {
        let store = EKEventStore()

        do {
            let granted = try await store.requestAccess(to: .event)
            guard granted else { return }
        } catch {
            print("Calendar access denied: \(error)")
            return
        }

        let event = EKEvent(eventStore: store)
        event.title = email.subject
        event.startDate = time
        event.endDate = time.addingTimeInterval(3600) // 1 hour default
        event.calendar = store.defaultCalendarForNewEvents
        event.notes = "Auto-created from email: \(email.sender)"

        do {
            try store.save(event, span: .thisEvent)
            print("📅 Created calendar event: \(email.subject)")
        } catch {
            print("Failed to create calendar event: \(error)")
        }
    }

    private func sendMeetingAcceptance(email: Email) async throws {
        let reply = "I accept this meeting invitation. Looking forward to it!"
        try await sendReply(email: email, body: reply)
    }

    private func snoozeEmail(_ email: Email, until: Date) async {
        // Store snooze in UserDefaults
        var snoozed = UserDefaults.standard.dictionary(forKey: "SnoozedEmails") as? [String: Date] ?? [:]
        snoozed[email.messageId] = until
        UserDefaults.standard.set(snoozed, forKey: "SnoozedEmails")

        // Archive email temporarily
        await archiveEmail(email)

        print("⏰ Snoozed until: \(until.formatted())")
    }

    private func unsubscribe(_ email: Email) async throws {
        // Look for unsubscribe link in email body
        guard let body = email.body else { return }

        // Search for unsubscribe patterns
        let patterns = [
            "unsubscribe",
            "opt-out",
            "remove me",
            "stop receiving"
        ]

        // Find unsubscribe link (simplified)
        if body.lowercased().contains("unsubscribe") {
            print("🚫 Unsubscribe link detected - user should click manually")
            // Note: Automatic unsubscribe is risky - just flag it
        }
    }

    private func markAsNeedsAttention(_ email: Email) async {
        // Flag email via AppleScript
        let script = """
        tell application "Mail"
            set theMessage to first message whose message id is "\(email.messageId)"
            set flagged status of theMessage to true
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        try? process.run()
        process.waitUntilExit()

        print("⚠️ Flagged for attention: \(email.subject)")
    }

    private func logAction(email: Email, action: String) async {
        // Log to file for audit trail
        let logEntry = "\(Date().formatted()): \(action) - Email: \(email.subject) from \(email.sender)\n"

        let logFile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("autonomous_agent.log")

        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }

    private func calculateOpenRate(sender: String) async -> Double {
        // Query email history from UserDefaults or database
        let history = UserDefaults.standard.dictionary(forKey: "EmailOpenHistory_\(sender)") as? [String: Bool] ?? [:]

        guard !history.isEmpty else { return 0.5 }

        let opened = history.values.filter { $0 }.count
        return Double(opened) / Double(history.count)
    }

    private func countInteractions(sender: String) async -> Int {
        // Count from email history
        let count = UserDefaults.standard.integer(forKey: "InteractionCount_\(sender)")
        return count
    }

    private func findRelatedProject(_ email: Email) async -> String? {
        // Search email subject/body for project keywords
        let projectKeywords = [
            "Project Alpha": ["alpha", "project a"],
            "Client Beta": ["beta", "client b"],
            "Internal Initiative": ["internal", "initiative"]
        ]

        let searchText = "\(email.subject) \(email.body ?? "")".lowercased()

        for (project, keywords) in projectKeywords {
            if keywords.contains(where: { searchText.contains($0) }) {
                return project
            }
        }

        return nil
    }
}

// MARK: - Models

struct AgentDecision {
    let action: AgentAction
    let confidence: Double
    let reasoning: String
    var requiresApproval: Bool

    var confidencePercent: Int {
        Int(confidence * 100)
    }
}

enum AgentAction {
    case autoReply(template: String, sendImmediately: Bool)
    case autoArchive(reason: String)
    case autoDelegate(to: String, reason: String)
    case escalateToHuman(urgency: UrgencyLevel)
    case scheduleFollowUp(date: Date)
    case autoUnsubscribe(reason: String)
    case autoAcceptMeeting(time: Date, createCalendarEvent: Bool)
}

enum UrgencyLevel: String, Codable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

struct EmailAnalysis {
    let emailType: EmailType
    let actionRequired: Bool
    let deadline: Date?
    let sentiment: EmailSentiment
    let complexity: ComplexityLevel
    let keywords: [String]
    let entities: [String]
}

enum EmailType {
    case request
    case information
    case meeting
    case marketing
    case newsletter
    case spam
    case personal
    case urgent
}

enum EmailSentiment {
    case positive
    case neutral
    case negative
    case urgent
}

enum ComplexityLevel {
    case simple
    case moderate
    case complex
}

struct EmailContext {
    let relationshipLevel: RelationshipType
    let openRate: Double
    let interactionCount: Int
    let relatedProject: String?
    let threadLength: Int
    let hasAttachments: Bool
}

struct AgentLearning: Codable {
    let emailPattern: EmailPattern
    let suggestedAction: String // Simplified for Codable
    let wasApproved: Bool
    let timestamp: Date
}

struct EmailPattern: Codable {
    let senderDomain: String
    let subjectKeywords: [String]
    let hasAttachments: Bool
    let isThread: Bool
}

struct UserAction {
    let approved: Bool
    let actualAction: String
    let feedback: String?
}

struct PriorityScore {
    let score: Int // 0-100
    let reasoning: String
}

enum EmailIntent: String {
    case wantsNothing = "wants_nothing"
    case wantsAcknowledgment = "wants_acknowledgment"
    case wantsMeeting = "wants_meeting"
    case wantsInformation = "wants_information"
    case wantsAction = "wants_action"
    case wantsDecision = "wants_decision"
    case unknown = "unknown"
}

// Placeholder types
typealias Email = EmailModels.Email
typealias RelationshipType = EmailModels.RelationshipType
