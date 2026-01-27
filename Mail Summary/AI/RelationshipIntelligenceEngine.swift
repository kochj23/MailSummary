import Foundation

//
//  RelationshipIntelligenceEngine.swift
//  Mail Summary
//
//  THE LEGENDARY FEATURE: Email Relationship Intelligence
//  Tracks and analyzes email relationships, detects relationship risks
//
//  Author: Jordan Koch
//  Date: 2026-01-26
//

@MainActor
class RelationshipIntelligenceEngine: ObservableObject {

    static let shared = RelationshipIntelligenceEngine()

    @Published var isAnalyzing = false
    @Published var relationships: [String: ContactProfile] = [:]
    @Published var relationshipAlerts: [RelationshipAlert] = []

    private var interactionHistory: [String: [EmailInteraction]] = [:]

    private init() {
        loadRelationships()
    }

    // MARK: - Relationship Analysis

    func analyzeRelationship(_ senderEmail: String) async throws -> RelationshipAnalysis {

        isAnalyzing = true
        defer { isAnalyzing = false }

        // Get or create contact profile
        var profile = relationships[senderEmail] ?? ContactProfile(
            email: senderEmail,
            name: extractName(from: senderEmail),
            type: .unknown,
            interactions: []
        )

        // Analyze interaction patterns
        let interactions = interactionHistory[senderEmail] ?? []

        // Calculate metrics
        let responseTime = calculateAverageResponseTime(interactions)
        let sentiment = analyzeSentimentTrend(interactions)
        let frequency = calculateInteractionFrequency(interactions)
        let healthScore = calculateRelationshipHealth(
            profile: profile,
            interactions: interactions,
            responseTime: responseTime,
            sentiment: sentiment
        )

        // Detect relationship type
        let detectedType = detectRelationshipType(profile, interactions: interactions)
        profile.type = detectedType

        // Update profile
        profile.lastInteraction = interactions.last?.date
        profile.totalInteractions = interactions.count
        profile.averageResponseTime = responseTime
        profile.sentimentTrend = sentiment
        profile.healthScore = healthScore

        relationships[senderEmail] = profile

        // Check for risks
        let risks = detectRelationshipRisks(profile, interactions: interactions)
        if !risks.isEmpty {
            relationshipAlerts.append(contentsOf: risks)
        }

        saveRelationships()

        return RelationshipAnalysis(
            profile: profile,
            healthScore: healthScore,
            responseTime: responseTime,
            sentimentTrend: sentiment,
            frequency: frequency,
            risks: risks,
            suggestions: generateRelationshipSuggestions(profile, risks: risks)
        )
    }

    // MARK: - Relationship Risk Detection

    func detectRelationshipRisks(
        _ profile: ContactProfile,
        interactions: [EmailInteraction]
    ) -> [RelationshipAlert] {

        var alerts: [RelationshipAlert] = []

        // Risk 1: Ghosting Detection
        if let lastInteraction = profile.lastInteraction {
            let daysSinceLastInteraction = Calendar.current.dateComponents([.day], from: lastInteraction, to: Date()).day ?? 0

            if profile.type == .client && daysSinceLastInteraction > 30 {
                alerts.append(RelationshipAlert(
                    severity: .high,
                    type: .ghosting,
                    contact: profile.email,
                    message: "No interaction with \(profile.name) for \(daysSinceLastInteraction) days",
                    suggestedAction: "Send a check-in email to maintain relationship"
                ))
            } else if profile.type == .colleague && daysSinceLastInteraction > 60 {
                alerts.append(RelationshipAlert(
                    severity: .medium,
                    type: .ghosting,
                    contact: profile.email,
                    message: "Haven't heard from \(profile.name) in 2 months",
                    suggestedAction: "Reach out to reconnect"
                ))
            }
        }

        // Risk 2: Relationship Cooling
        if interactions.count >= 5 {
            let recentSentiment = analyzeSentimentTrend(Array(interactions.suffix(5)))
            if recentSentiment < 0.3 {
                alerts.append(RelationshipAlert(
                    severity: .high,
                    type: .cooling,
                    contact: profile.email,
                    message: "Sentiment declining with \(profile.name) (score: \(Int(recentSentiment * 100))/100)",
                    suggestedAction: "Address concerns proactively"
                ))
            }
        }

        // Risk 3: Response Time Degradation
        if let responseTime = profile.averageResponseTime {
            let recentInteractions = interactions.suffix(5)
            let recentResponseTime = calculateAverageResponseTime(Array(recentInteractions))

            if recentResponseTime > responseTime * 2 {
                alerts.append(RelationshipAlert(
                    severity: .medium,
                    type: .slowResponse,
                    contact: profile.email,
                    message: "\(profile.name) is taking longer to respond (was \(formatResponseTime(responseTime)), now \(formatResponseTime(recentResponseTime)))",
                    suggestedAction: "Check if there are issues affecting communication"
                ))
            }
        }

        // Risk 4: Neglect (Important contact not engaged)
        if profile.type == .boss || profile.type == .vip {
            if let lastInteraction = profile.lastInteraction {
                let daysSinceLastInteraction = Calendar.current.dateComponents([.day], from: lastInteraction, to: Date()).day ?? 0

                if daysSinceLastInteraction > 14 {
                    alerts.append(RelationshipAlert(
                        severity: .critical,
                        type: .neglect,
                        contact: profile.email,
                        message: "Haven't interacted with important contact \(profile.name) for \(daysSinceLastInteraction) days",
                        suggestedAction: "Send update or check-in immediately"
                    ))
                }
            }
        }

        // Risk 5: One-sided Communication
        let sentByUser = interactions.filter { $0.direction == .outgoing }.count
        let receivedFromContact = interactions.filter { $0.direction == .incoming }.count

        if interactions.count >= 10 {
            let ratio = Double(sentByUser) / max(1.0, Double(receivedFromContact))

            if ratio > 3.0 {
                alerts.append(RelationshipAlert(
                    severity: .medium,
                    type: .oneSided,
                    contact: profile.email,
                    message: "One-sided communication with \(profile.name) (you: \(sentByUser), them: \(receivedFromContact))",
                    suggestedAction: "Consider if this relationship needs attention or closure"
                ))
            }
        }

        return alerts
    }

    // MARK: - Relationship Suggestions

    func suggestActions(for profile: ContactProfile) -> [RelationshipAction] {

        var actions: [RelationshipAction] = []

        // Suggest based on health score
        if profile.healthScore < 0.5 {
            actions.append(RelationshipAction(
                type: .reachOut,
                priority: .high,
                title: "Reach out to \(profile.name)",
                description: "Relationship health is declining. Send a friendly check-in.",
                dueDate: Date()
            ))
        }

        // Suggest based on time since last interaction
        if let lastInteraction = profile.lastInteraction {
            let daysSince = Calendar.current.dateComponents([.day], from: lastInteraction, to: Date()).day ?? 0

            if daysSince > 30 && profile.type == .client {
                actions.append(RelationshipAction(
                    type: .followUp,
                    priority: .high,
                    title: "Follow up with \(profile.name)",
                    description: "It's been \(daysSince) days since last contact.",
                    dueDate: Date()
                ))
            }
        }

        // Suggest based on sentiment trend
        if let sentiment = profile.sentimentTrend, sentiment < 0.4 {
            actions.append(RelationshipAction(
                type: .addressConcerns,
                priority: .critical,
                title: "Address concerns with \(profile.name)",
                description: "Sentiment is negative. Proactively address potential issues.",
                dueDate: Date()
            ))
        }

        return actions
    }

    // MARK: - Interaction Tracking

    func recordInteraction(
        email: Email,
        direction: InteractionDirection,
        sentiment: Double? = nil
    ) {

        let interaction = EmailInteraction(
            id: UUID(),
            date: email.dateReceived,
            direction: direction,
            subject: email.subject,
            sentiment: sentiment ?? 0.5,
            responseTime: nil,
            wasRead: email.isRead
        )

        let senderEmail = email.senderEmail
        var history = interactionHistory[senderEmail] ?? []
        history.append(interaction)

        // Calculate response time if this is a reply
        if direction == .outgoing && history.count >= 2 {
            let previousIncoming = history.reversed().first(where: { $0.direction == .incoming })
            if let previous = previousIncoming {
                let responseTime = interaction.date.timeIntervalSince(previous.date)
                var updatedInteraction = interaction
                updatedInteraction.responseTime = responseTime
                history[history.count - 1] = updatedInteraction
            }
        }

        interactionHistory[senderEmail] = history
        saveInteractionHistory()
    }

    // MARK: - Relationship Health Calculation

    private func calculateRelationshipHealth(
        profile: ContactProfile,
        interactions: [EmailInteraction],
        responseTime: TimeInterval?,
        sentiment: Double?
    ) -> Double {

        var score = 0.5 // Base score

        // Factor 1: Recency (30%)
        if let lastInteraction = profile.lastInteraction {
            let daysSince = Calendar.current.dateComponents([.day], from: lastInteraction, to: Date()).day ?? 0

            if daysSince < 7 {
                score += 0.3
            } else if daysSince < 30 {
                score += 0.2
            } else if daysSince < 90 {
                score += 0.1
            } else {
                score -= 0.2
            }
        }

        // Factor 2: Sentiment (30%)
        if let sentiment = sentiment {
            score += (sentiment - 0.5) * 0.6 // -0.3 to +0.3
        }

        // Factor 3: Response Time (20%)
        if let responseTime = responseTime {
            let hours = responseTime / 3600

            if hours < 24 {
                score += 0.2
            } else if hours < 72 {
                score += 0.1
            } else if hours > 168 { // 1 week
                score -= 0.1
            }
        }

        // Factor 4: Interaction Frequency (20%)
        let recentInteractions = interactions.filter { interaction in
            let daysSince = Calendar.current.dateComponents([.day], from: interaction.date, to: Date()).day ?? 0
            return daysSince < 30
        }

        if recentInteractions.count > 5 {
            score += 0.2
        } else if recentInteractions.count > 2 {
            score += 0.1
        }

        return max(0.0, min(1.0, score))
    }

    // MARK: - Analysis Helpers

    private func calculateAverageResponseTime(_ interactions: [EmailInteraction]) -> TimeInterval {
        let responseTimes = interactions.compactMap { $0.responseTime }
        guard !responseTimes.isEmpty else { return 0 }
        return responseTimes.reduce(0, +) / Double(responseTimes.count)
    }

    private func analyzeSentimentTrend(_ interactions: [EmailInteraction]) -> Double {
        guard !interactions.isEmpty else { return 0.5 }
        let totalSentiment = interactions.map { $0.sentiment }.reduce(0, +)
        return totalSentiment / Double(interactions.count)
    }

    private func calculateInteractionFrequency(_ interactions: [EmailInteraction]) -> Double {
        guard interactions.count >= 2 else { return 0 }

        let sortedInteractions = interactions.sorted { $0.date < $1.date }
        let firstDate = sortedInteractions.first!.date
        let lastDate = sortedInteractions.last!.date

        let daysBetween = Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 1
        return Double(interactions.count) / max(1.0, Double(daysBetween))
    }

    private func detectRelationshipType(
        _ profile: ContactProfile,
        interactions: [EmailInteraction]
    ) -> RelationshipType {

        // Simple heuristics - could be enhanced with AI
        if interactions.count > 50 {
            return .colleague
        } else if interactions.count > 20 {
            return .client
        } else if interactions.count > 10 {
            return .contact
        } else {
            return .unknown
        }
    }

    private func generateRelationshipSuggestions(
        _ profile: ContactProfile,
        risks: [RelationshipAlert]
    ) -> [String] {

        var suggestions: [String] = []

        if profile.healthScore < 0.5 {
            suggestions.append("Schedule a call or meeting to strengthen relationship")
        }

        if !risks.isEmpty {
            suggestions.append("Address \(risks.count) relationship risk(s)")
        }

        if profile.totalInteractions < 5 {
            suggestions.append("Build rapport through more frequent communication")
        }

        return suggestions
    }

    private func formatResponseTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval / 3600)
        if hours < 1 {
            return "\(Int(timeInterval / 60)) minutes"
        } else if hours < 24 {
            return "\(hours) hours"
        } else {
            return "\(hours / 24) days"
        }
    }

    private func extractName(from email: String) -> String {
        return email.components(separatedBy: "@").first?.capitalized ?? "Unknown"
    }

    // MARK: - Persistence

    private func loadRelationships() {
        if let data = UserDefaults.standard.data(forKey: "RelationshipIntelligence_Profiles"),
           let profiles = try? JSONDecoder().decode([String: ContactProfile].self, from: data) {
            relationships = profiles
        }

        if let data = UserDefaults.standard.data(forKey: "RelationshipIntelligence_History"),
           let history = try? JSONDecoder().decode([String: [EmailInteraction]].self, from: data) {
            interactionHistory = history
        }
    }

    private func saveRelationships() {
        if let data = try? JSONEncoder().encode(relationships) {
            UserDefaults.standard.set(data, forKey: "RelationshipIntelligence_Profiles")
        }
    }

    private func saveInteractionHistory() {
        if let data = try? JSONEncoder().encode(interactionHistory) {
            UserDefaults.standard.set(data, forKey: "RelationshipIntelligence_History")
        }
    }
}

// MARK: - Models

struct ContactProfile: Codable {
    let email: String
    var name: String
    var type: RelationshipType
    var interactions: [EmailInteraction]
    var lastInteraction: Date?
    var totalInteractions: Int = 0
    var averageResponseTime: TimeInterval?
    var sentimentTrend: Double?
    var healthScore: Double = 0.5 // 0.0-1.0
}

enum RelationshipType: String, Codable, CaseIterable {
    case boss = "Boss"
    case colleague = "Colleague"
    case client = "Client"
    case vendor = "Vendor"
    case friend = "Friend"
    case family = "Family"
    case contact = "Contact"
    case vip = "VIP"
    case unknown = "Unknown"

    var priority: Int {
        switch self {
        case .boss: return 100
        case .vip: return 95
        case .client: return 90
        case .colleague: return 70
        case .vendor: return 60
        case .friend: return 50
        case .family: return 80
        case .contact: return 40
        case .unknown: return 30
        }
    }
}

struct EmailInteraction: Codable {
    let id: UUID
    let date: Date
    let direction: InteractionDirection
    let subject: String
    var sentiment: Double // 0.0-1.0
    var responseTime: TimeInterval?
    let wasRead: Bool
}

enum InteractionDirection: String, Codable {
    case incoming = "Incoming"
    case outgoing = "Outgoing"
}

struct RelationshipAnalysis {
    let profile: ContactProfile
    let healthScore: Double // 0.0-1.0 (0=critical, 1=excellent)
    let responseTime: TimeInterval?
    let sentimentTrend: Double? // 0.0-1.0
    let frequency: Double // Interactions per day
    let risks: [RelationshipAlert]
    let suggestions: [String]

    var healthRating: String {
        if healthScore > 0.8 { return "Excellent" }
        else if healthScore > 0.6 { return "Good" }
        else if healthScore > 0.4 { return "Fair" }
        else if healthScore > 0.2 { return "Poor" }
        else { return "Critical" }
    }

    var healthColor: String {
        if healthScore > 0.8 { return "green" }
        else if healthScore > 0.6 { return "blue" }
        else if healthScore > 0.4 { return "yellow" }
        else if healthScore > 0.2 { return "orange" }
        else { return "red" }
    }
}

struct RelationshipAlert: Identifiable, Codable {
    let id = UUID()
    let severity: AlertSeverity
    let type: AlertType
    let contact: String
    let message: String
    let suggestedAction: String
    let timestamp: Date = Date()

    enum AlertSeverity: String, Codable {
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
        case low = "Low"

        var color: String {
            switch self {
            case .critical: return "red"
            case .high: return "orange"
            case .medium: return "yellow"
            case .low: return "blue"
            }
        }
    }

    enum AlertType: String, Codable {
        case ghosting = "Ghosting"
        case cooling = "Relationship Cooling"
        case slowResponse = "Slow Response"
        case neglect = "Neglect"
        case oneSided = "One-Sided Communication"
    }
}

struct RelationshipAction {
    let type: ActionType
    let priority: Priority
    let title: String
    let description: String
    let dueDate: Date

    enum ActionType {
        case reachOut
        case followUp
        case addressConcerns
        case scheduleMeeting
        case sendUpdate
    }

    enum Priority: String {
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
    }
}

// Placeholder types
typealias Email = EmailModels.Email
