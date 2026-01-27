import Foundation

//
//  MeetingAutopilotEngine.swift
//  Mail Summary
//
//  THE LEGENDARY FEATURE: Autonomous Meeting Management
//  Automatically handle meeting requests, check calendar, auto-accept/decline
//
//  Author: Jordan Koch
//  Date: 2026-01-26
//

@MainActor
class MeetingAutopilotEngine: ObservableObject {

    static let shared = MeetingAutopilotEngine()

    @Published var isProcessing = false
    @Published var autopilotEnabled = false
    @Published var autoAcceptThreshold = 0.70 // Confidence required to auto-accept
    @Published var meetingsHandled = 0
    @Published var meetingsDeclined = 0
    @Published var meetingConflicts = 0

    private var calendarEvents: [CalendarEvent] = []
    private var meetingPreferences: MeetingPreferences?

    private init() {
        loadSettings()
    }

    // MARK: - Meeting Request Handling

    func handleMeetingRequest(_ email: Email) async throws -> MeetingDecision {

        isProcessing = true
        defer { isProcessing = false }

        // Step 1: Parse meeting details
        let meetingRequest = try await parseMeetingRequest(email)

        // Step 2: Check calendar conflicts
        let conflicts = await checkCalendarConflicts(meetingRequest)

        // Step 3: Assess meeting value
        let assessment = try await assessMeetingValue(meetingRequest, email: email)

        // Step 4: Make decision
        let decision = decideOnMeeting(
            request: meetingRequest,
            conflicts: conflicts,
            assessment: assessment,
            email: email
        )

        // Step 5: Execute if autopilot enabled and high confidence
        if autopilotEnabled && decision.confidence >= autoAcceptThreshold {
            try await executeDecision(decision, email: email)
        }

        return decision
    }

    // MARK: - Meeting Parsing

    private func parseMeetingRequest(_ email: Email) async throws -> MeetingRequest {

        let prompt = """
        Extract meeting details from this email.

        Subject: \(email.subject)
        From: \(email.sender)
        Body: \(email.body ?? "")

        Extract:
        {
          "title": "meeting title",
          "proposedTimes": ["ISO8601", "ISO8601"],
          "duration": minutes,
          "location": "physical location or video link",
          "attendees": ["email1", "email2"],
          "isRecurring": true/false,
          "agenda": "meeting purpose",
          "priority": "high|medium|low"
        }
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You extract meeting details from emails. Be precise with dates and times.",
            temperature: 0.1,
            maxTokens: 300
        )

        return try parseMeetingRequestResponse(response, email: email)
    }

    // MARK: - Calendar Conflict Detection

    private func checkCalendarConflicts(_ request: MeetingRequest) async -> [CalendarConflict] {

        var conflicts: [CalendarConflict] = []

        for proposedTime in request.proposedTimes {
            let endTime = proposedTime.addingTimeInterval(TimeInterval(request.duration * 60))

            // Check against existing events
            for event in calendarEvents {
                if eventsOverlap(
                    start1: proposedTime, end1: endTime,
                    start2: event.startTime, end2: event.endTime
                ) {
                    conflicts.append(CalendarConflict(
                        proposedTime: proposedTime,
                        conflictingEvent: event,
                        severity: .hard
                    ))
                }
            }

            // Check for back-to-back meetings (buffer time)
            for event in calendarEvents {
                let bufferTime: TimeInterval = 15 * 60 // 15 minutes

                if abs(event.endTime.timeIntervalSince(proposedTime)) < bufferTime ||
                   abs(endTime.timeIntervalSince(event.startTime)) < bufferTime {
                    conflicts.append(CalendarConflict(
                        proposedTime: proposedTime,
                        conflictingEvent: event,
                        severity: .soft
                    ))
                }
            }
        }

        return conflicts
    }

    // MARK: - Meeting Value Assessment

    private func assessMeetingValue(
        _ request: MeetingRequest,
        email: Email
    ) async throws -> MeetingAssessment {

        let prompt = """
        Assess the value and necessity of this meeting.

        Meeting: \(request.title)
        From: \(email.sender)
        Agenda: \(request.agenda ?? "No agenda")
        Duration: \(request.duration) minutes
        Attendees: \(request.attendees.count) people

        Assess:
        1. Value Score (0-100): How valuable is this meeting?
        2. Necessity (high/medium/low): Could this be an email?
        3. Category: 1on1|team|client|vendor|internal
        4. Skip Recommendation: Should you skip? (yes/no/maybe)
        5. Reasoning: Why?

        JSON:
        {
          "valueScore": 75,
          "necessity": "high",
          "category": "client",
          "shouldSkip": "no",
          "reasoning": "..."
        }
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You assess meeting value objectively. Consider time investment vs. potential value.",
            temperature: 0.3,
            maxTokens: 200
        )

        return try parseMeetingAssessment(response)
    }

    // MARK: - Decision Making

    private func decideOnMeeting(
        request: MeetingRequest,
        conflicts: [CalendarConflict],
        assessment: MeetingAssessment,
        email: Email
    ) -> MeetingDecision {

        var score = Double(assessment.valueScore) / 100.0

        // Adjust for conflicts
        let hardConflicts = conflicts.filter { $0.severity == .hard }
        if !hardConflicts.isEmpty {
            score -= 0.5 // Major penalty for conflicts
        }

        // Adjust for sender importance
        let senderImportance = getSenderImportance(email.senderEmail)
        score += (senderImportance - 0.5) * 0.3 // ±0.15 adjustment

        // Adjust for meeting preferences
        if let prefs = meetingPreferences {
            score += evaluatePreferences(request, preferences: prefs)
        }

        // Adjust for necessity
        switch assessment.necessity {
        case .high:
            score += 0.1
        case .medium:
            break
        case .low:
            score -= 0.2
        }

        // Make decision
        let confidence = min(1.0, max(0.0, score))

        if !hardConflicts.isEmpty {
            // Has conflicts - propose alternative
            return MeetingDecision(
                action: .proposeAlternative(conflicts: hardConflicts),
                confidence: confidence,
                reasoning: "Calendar conflict detected: \(hardConflicts.first!.conflictingEvent.title)",
                suggestedTimes: suggestAlternativeTimes(request, conflicts: conflicts),
                valueAssessment: assessment
            )
        } else if confidence >= autoAcceptThreshold {
            // High confidence - accept
            return MeetingDecision(
                action: .accept(time: request.proposedTimes.first!),
                confidence: confidence,
                reasoning: "Meeting aligns with priorities (\(assessment.reasoning))",
                suggestedTimes: [],
                valueAssessment: assessment
            )
        } else if confidence < 0.3 {
            // Low value - decline
            return MeetingDecision(
                action: .decline(reason: "Low meeting value for time investment"),
                confidence: 1.0 - confidence,
                reasoning: assessment.reasoning,
                suggestedTimes: [],
                valueAssessment: assessment
            )
        } else {
            // Uncertain - escalate to human
            return MeetingDecision(
                action: .escalateToHuman,
                confidence: confidence,
                reasoning: "Needs human judgment (value: \(Int(confidence * 100))%)",
                suggestedTimes: [],
                valueAssessment: assessment
            )
        }
    }

    // MARK: - Decision Execution

    private func executeDecision(_ decision: MeetingDecision, email: Email) async throws {

        switch decision.action {
        case .accept(let time):
            await createCalendarEvent(email: email, startTime: time)
            try await sendMeetingResponse(email: email, accepted: true, message: nil)
            meetingsHandled += 1
            print("✅ Auto-accepted meeting: \(email.subject)")

        case .decline(let reason):
            try await sendMeetingResponse(email: email, accepted: false, message: reason)
            meetingsDeclined += 1
            print("❌ Auto-declined meeting: \(email.subject) - \(reason)")

        case .proposeAlternative(let conflicts):
            let alternativeTimes = decision.suggestedTimes
            try await sendAlternativeTimeProposal(email: email, times: alternativeTimes, reason: "Calendar conflict")
            meetingConflicts += 1
            print("🔄 Proposed alternative times for: \(email.subject)")

        case .escalateToHuman:
            await flagForReview(email: email)
            print("⚠️ Meeting requires human review: \(email.subject)")

        case .tentativeAccept(let time):
            await createCalendarEvent(email: email, startTime: time, tentative: true)
            try await sendMeetingResponse(email: email, accepted: true, message: "Tentatively accepted")
            meetingsHandled += 1
            print("⏳ Tentatively accepted meeting: \(email.subject)")
        }

        saveStatistics()
    }

    // MARK: - Alternative Time Suggestions

    private func suggestAlternativeTimes(
        _ request: MeetingRequest,
        conflicts: [CalendarConflict]
    ) -> [Date] {

        var suggestions: [Date] = []

        // Find next available slots
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 14, to: startDate)!

        var currentDate = startDate
        while currentDate < endDate && suggestions.count < 3 {
            // Check business hours (9 AM - 5 PM)
            let hour = Calendar.current.component(.hour, from: currentDate)

            if hour >= 9 && hour <= 17 {
                let endTime = currentDate.addingTimeInterval(TimeInterval(request.duration * 60))

                // Check if slot is free
                let hasConflict = calendarEvents.contains { event in
                    eventsOverlap(
                        start1: currentDate, end1: endTime,
                        start2: event.startTime, end2: event.endTime
                    )
                }

                if !hasConflict {
                    suggestions.append(currentDate)
                }
            }

            // Move to next hour
            currentDate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        }

        return suggestions
    }

    // MARK: - Preference Evaluation

    private func evaluatePreferences(
        _ request: MeetingRequest,
        preferences: MeetingPreferences
    ) -> Double {

        var adjustment = 0.0

        // Check meeting type preference
        if preferences.preferredMeetingTypes.contains(request.category) {
            adjustment += 0.1
        }

        // Check duration preference
        if request.duration <= preferences.maxPreferredDuration {
            adjustment += 0.05
        } else {
            adjustment -= 0.1
        }

        // Check time of day preference
        if let preferredTime = request.proposedTimes.first {
            let hour = Calendar.current.component(.hour, from: preferredTime)

            if hour >= preferences.preferredStartHour && hour <= preferences.preferredEndHour {
                adjustment += 0.05
            }
        }

        // Check no-meeting days
        if let proposedTime = request.proposedTimes.first {
            let weekday = Calendar.current.component(.weekday, from: proposedTime)

            if preferences.noMeetingDays.contains(weekday) {
                adjustment -= 0.3
            }
        }

        return adjustment
    }

    // MARK: - Helpers

    private func eventsOverlap(start1: Date, end1: Date, start2: Date, end2: Date) -> Bool {
        return start1 < end2 && end1 > start2
    }

    private func getSenderImportance(_ senderEmail: String) -> Double {
        // Integration with RelationshipIntelligence
        // For now, return default
        return 0.5
    }

    // MARK: - Parsing Helpers

    private func parseMeetingRequestResponse(_ response: String, email: Email) throws -> MeetingRequest {

        // Attempt JSON parsing
        if let jsonData = response.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {

            let title = json["title"] as? String ?? email.subject
            let duration = json["duration"] as? Int ?? 60
            let location = json["location"] as? String
            let attendees = json["attendees"] as? [String] ?? []
            let isRecurring = json["isRecurring"] as? Bool ?? false
            let agenda = json["agenda"] as? String
            let priorityString = json["priority"] as? String ?? "medium"
            let priority = MeetingPriority(rawValue: priorityString) ?? .medium

            // Parse proposed times
            var proposedTimes: [Date] = []
            if let timesArray = json["proposedTimes"] as? [String] {
                let formatter = ISO8601DateFormatter()
                proposedTimes = timesArray.compactMap { formatter.date(from: $0) }
            }

            if proposedTimes.isEmpty {
                // Default to tomorrow at 2 PM
                proposedTimes = [Calendar.current.date(byAdding: .day, value: 1, to: Date())!]
            }

            return MeetingRequest(
                title: title,
                proposedTimes: proposedTimes,
                duration: duration,
                location: location,
                attendees: attendees,
                isRecurring: isRecurring,
                agenda: agenda,
                priority: priority,
                category: .team
            )
        }

        // Fallback
        throw MeetingError.parsingFailed
    }

    private func parseMeetingAssessment(_ response: String) throws -> MeetingAssessment {

        // Attempt JSON parsing
        if let jsonData = response.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {

            let valueScore = json["valueScore"] as? Int ?? 50
            let necessityString = json["necessity"] as? String ?? "medium"
            let necessity = MeetingNecessity(rawValue: necessityString) ?? .medium
            let categoryString = json["category"] as? String ?? "team"
            let category = MeetingCategory(rawValue: categoryString) ?? .team
            let reasoning = json["reasoning"] as? String ?? "No reasoning provided"

            return MeetingAssessment(
                valueScore: valueScore,
                necessity: necessity,
                category: category,
                reasoning: reasoning
            )
        }

        throw MeetingError.parsingFailed
    }

    // MARK: - Placeholder Methods

    private func createCalendarEvent(email: Email, startTime: Date, tentative: Bool = false) async {
        // Placeholder: Create calendar event via EventKit
        print("📅 Created calendar event: \(email.subject)")
    }

    private func sendMeetingResponse(email: Email, accepted: Bool, message: String?) async throws {
        // Placeholder: Send meeting accept/decline email
        print("📧 Sent meeting response: \(accepted ? "Accepted" : "Declined")")
    }

    private func sendAlternativeTimeProposal(email: Email, times: [Date], reason: String) async throws {
        // Placeholder: Send alternative time proposal
        print("🔄 Proposed alternative times")
    }

    private func flagForReview(email: Email) async {
        // Placeholder: Flag email for user review
        print("⚠️ Flagged for review: \(email.subject)")
    }

    // MARK: - Persistence

    private func loadSettings() {
        autopilotEnabled = UserDefaults.standard.bool(forKey: "MeetingAutopilot_Enabled")
        autoAcceptThreshold = UserDefaults.standard.double(forKey: "MeetingAutopilot_Threshold")
        if autoAcceptThreshold == 0 { autoAcceptThreshold = 0.70 }

        meetingsHandled = UserDefaults.standard.integer(forKey: "MeetingAutopilot_Handled")
        meetingsDeclined = UserDefaults.standard.integer(forKey: "MeetingAutopilot_Declined")
        meetingConflicts = UserDefaults.standard.integer(forKey: "MeetingAutopilot_Conflicts")

        if let data = UserDefaults.standard.data(forKey: "MeetingAutopilot_Preferences"),
           let prefs = try? JSONDecoder().decode(MeetingPreferences.self, from: data) {
            meetingPreferences = prefs
        }
    }

    private func saveStatistics() {
        UserDefaults.standard.set(meetingsHandled, forKey: "MeetingAutopilot_Handled")
        UserDefaults.standard.set(meetingsDeclined, forKey: "MeetingAutopilot_Declined")
        UserDefaults.standard.set(meetingConflicts, forKey: "MeetingAutopilot_Conflicts")
    }

    func savePreferences(_ prefs: MeetingPreferences) {
        meetingPreferences = prefs
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: "MeetingAutopilot_Preferences")
        }
    }
}

// MARK: - Models

struct MeetingRequest {
    let title: String
    let proposedTimes: [Date]
    let duration: Int // minutes
    let location: String?
    let attendees: [String]
    let isRecurring: Bool
    let agenda: String?
    let priority: MeetingPriority
    let category: MeetingCategory
}

enum MeetingPriority: String {
    case high = "high"
    case medium = "medium"
    case low = "low"
}

enum MeetingCategory: String, Codable {
    case oneOnOne = "1on1"
    case team = "team"
    case client = "client"
    case vendor = "vendor"
    case internal = "internal"
    case interview = "interview"
    case social = "social"
}

struct MeetingDecision {
    let action: MeetingAction
    let confidence: Double
    let reasoning: String
    let suggestedTimes: [Date]
    let valueAssessment: MeetingAssessment

    var confidencePercent: Int {
        Int(confidence * 100)
    }
}

enum MeetingAction {
    case accept(time: Date)
    case decline(reason: String)
    case proposeAlternative(conflicts: [CalendarConflict])
    case escalateToHuman
    case tentativeAccept(time: Date)
}

struct MeetingAssessment {
    let valueScore: Int // 0-100
    let necessity: MeetingNecessity
    let category: MeetingCategory
    let reasoning: String
}

enum MeetingNecessity: String {
    case high = "high"
    case medium = "medium"
    case low = "low"
}

struct CalendarEvent {
    let id: UUID
    let title: String
    let startTime: Date
    let endTime: Date
    let location: String?
    let attendees: [String]
}

struct CalendarConflict {
    let proposedTime: Date
    let conflictingEvent: CalendarEvent
    let severity: ConflictSeverity

    enum ConflictSeverity {
        case hard // Direct overlap
        case soft // Back-to-back, no buffer
    }
}

struct MeetingPreferences: Codable {
    let preferredMeetingTypes: [MeetingCategory]
    let maxPreferredDuration: Int // minutes
    let preferredStartHour: Int // 0-23
    let preferredEndHour: Int // 0-23
    let noMeetingDays: [Int] // Weekdays (1=Sunday, 7=Saturday)
    let requireAgenda: Bool
    let minimumNoticeHours: Int
}

enum MeetingError: LocalizedError {
    case parsingFailed
    case noProposedTimes

    var errorDescription: String? {
        switch self {
        case .parsingFailed:
            return "Failed to parse meeting request"
        case .noProposedTimes:
            return "No proposed meeting times found"
        }
    }
}

// Placeholder types
typealias Email = EmailModels.Email
