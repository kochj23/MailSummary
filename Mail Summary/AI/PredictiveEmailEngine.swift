import Foundation

//
//  PredictiveEmailEngine.swift
//  Mail Summary
//
//  THE LEGENDARY FEATURE: Predictive Email Intelligence
//  Predicts incoming emails and prepares proactive responses
//
//  Author: Jordan Koch
//  Date: 2026-01-26
//

@MainActor
class PredictiveEmailEngine: ObservableObject {

    static let shared = PredictiveEmailEngine()

    @Published var isAnalyzing = false
    @Published var predictions: [EmailPrediction] = []
    @Published var accuracyRate = 0.0 // Track prediction accuracy

    private var emailHistory: [Email] = []
    private var historicalPatterns: [EmailPattern] = []
    private var predictionHistory: [PredictionResult] = []

    private init() {
        loadPredictionHistory()
    }

    // MARK: - Predict Incoming Emails

    func predictIncomingEmails(lookAheadDays: Int = 7) async throws -> [EmailPrediction] {

        isAnalyzing = true
        defer { isAnalyzing = false }

        // Step 1: Analyze historical email patterns
        let patterns = analyzeHistoricalPatterns(emailHistory)

        // Step 2: Predict based on patterns
        var predictions: [EmailPrediction] = []

        // Predict recurring emails (weekly reports, newsletters)
        predictions.append(contentsOf: predictRecurringEmails(patterns, days: lookAheadDays))

        // Predict follow-ups (expected replies)
        predictions.append(contentsOf: await predictFollowUps(emailHistory, days: lookAheadDays))

        // Predict deadline-related emails
        predictions.append(contentsOf: predictDeadlineEmails(emailHistory, days: lookAheadDays))

        // Predict relationship-based emails
        predictions.append(contentsOf: await predictRelationshipEmails(days: lookAheadDays))

        // Score predictions by confidence
        let scoredPredictions = predictions.sorted { $0.confidence > $1.confidence }

        self.predictions = scoredPredictions

        return scoredPredictions
    }

    // MARK: - Predict Recurring Emails

    private func predictRecurringEmails(_ patterns: [EmailPattern], days: Int) -> [EmailPrediction] {

        var predictions: [EmailPrediction] = []

        for pattern in patterns where pattern.isRecurring {

            guard let lastOccurrence = pattern.lastOccurrence else { continue }

            // Calculate next occurrence
            let daysSinceLastOccurrence = Calendar.current.dateComponents([.day], from: lastOccurrence, to: Date()).day ?? 0

            if daysSinceLastOccurrence >= pattern.recurrenceInterval - 2 { // Within 2 days of expected

                let nextExpectedDate = Calendar.current.date(
                    byAdding: .day,
                    value: pattern.recurrenceInterval,
                    to: lastOccurrence
                )!

                if nextExpectedDate <= Calendar.current.date(byAdding: .day, value: days, to: Date())! {

                    predictions.append(EmailPrediction(
                        predictedSender: pattern.sender,
                        predictedSubject: pattern.subjectPattern,
                        predictedDate: nextExpectedDate,
                        confidence: 0.85,
                        type: .recurring,
                        reasoning: "Receives email from \(pattern.sender) every \(pattern.recurrenceInterval) days",
                        suggestedProactiveAction: "Prepare response in advance",
                        preparedResponse: nil
                    ))
                }
            }
        }

        return predictions
    }

    // MARK: - Predict Follow-Ups

    private func predictFollowUps(_ emails: [Email], days: Int) async -> [EmailPrediction] {

        var predictions: [EmailPrediction] = []

        // Find emails you sent that are awaiting replies
        let sentEmails = emails.filter { email in
            // Placeholder: filter sent emails
            false // Replace with actual logic
        }

        for sentEmail in sentEmails {

            // Calculate expected reply time based on sender's typical response time
            let averageResponseTime = await getAverageResponseTime(for: sentEmail.senderEmail)

            let expectedReplyDate = sentEmail.dateReceived.addingTimeInterval(averageResponseTime)

            if expectedReplyDate <= Calendar.current.date(byAdding: .day, value: days, to: Date())! {

                predictions.append(EmailPrediction(
                    predictedSender: sentEmail.senderEmail,
                    predictedSubject: "Re: \(sentEmail.subject)",
                    predictedDate: expectedReplyDate,
                    confidence: 0.70,
                    type: .followUp,
                    reasoning: "\(sentEmail.sender) typically replies within \(formatTimeInterval(averageResponseTime))",
                    suggestedProactiveAction: "Prepare follow-up if no reply by \(expectedReplyDate.formatted())",
                    preparedResponse: nil
                ))
            }
        }

        return predictions
    }

    // MARK: - Predict Deadline Emails

    private func predictDeadlineEmails(_ emails: [Email], days: Int) -> [EmailPrediction] {

        var predictions: [EmailPrediction] = []

        // Find emails with upcoming deadlines
        for email in emails {

            // Extract deadline from email (if any)
            if let deadline = extractDeadline(from: email) {

                let daysUntilDeadline = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0

                if daysUntilDeadline <= days && daysUntilDeadline > 0 {

                    // Predict reminder email 1-2 days before deadline
                    let reminderDate = Calendar.current.date(byAdding: .day, value: -2, to: deadline)!

                    predictions.append(EmailPrediction(
                        predictedSender: email.senderEmail,
                        predictedSubject: "Reminder: \(email.subject)",
                        predictedDate: reminderDate,
                        confidence: 0.65,
                        type: .deadlineReminder,
                        reasoning: "Deadline approaching on \(deadline.formatted())",
                        suggestedProactiveAction: "Complete task before reminder arrives",
                        preparedResponse: nil
                    ))
                }
            }
        }

        return predictions
    }

    // MARK: - Predict Relationship-Based Emails

    private func predictRelationshipEmails(days: Int) async -> [EmailPrediction] {

        var predictions: [EmailPrediction] = []

        // Get relationship intelligence
        let relationships = RelationshipIntelligenceEngine.shared.relationships

        for (senderEmail, profile) in relationships {

            // Predict check-in from important contacts
            if profile.type == .client || profile.type == .boss || profile.type == .vip {

                if let lastInteraction = profile.lastInteraction {
                    let daysSinceLastInteraction = Calendar.current.dateComponents([.day], from: lastInteraction, to: Date()).day ?? 0

                    // Predict check-in if long time since last contact
                    if daysSinceLastInteraction > 30 {

                        let predictedDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!

                        predictions.append(EmailPrediction(
                            predictedSender: senderEmail,
                            predictedSubject: "Check-in from \(profile.name)",
                            predictedDate: predictedDate,
                            confidence: 0.55,
                            type: .checkIn,
                            reasoning: "Haven't heard from \(profile.name) in \(daysSinceLastInteraction) days",
                            suggestedProactiveAction: "Proactively reach out first",
                            preparedResponse: nil
                        ))
                    }
                }
            }
        }

        return predictions
    }

    // MARK: - Prepare Proactive Response

    func prepareProactiveResponse(for prediction: EmailPrediction) async throws -> String {

        let prompt = """
        Prepare a proactive response for this predicted email.

        Predicted Email:
        From: \(prediction.predictedSender)
        Subject: \(prediction.predictedSubject)
        Type: \(prediction.type.rawValue)
        Expected: \(prediction.predictedDate.formatted())

        Reasoning: \(prediction.reasoning)

        Write a professional, proactive response that:
        1. Anticipates their needs
        2. Provides relevant information
        3. Demonstrates preparedness
        4. Is concise (100-150 words)

        Response:
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You write proactive email responses that anticipate needs.",
            temperature: 0.5,
            maxTokens: 250
        )

        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Pattern Analysis

    private func analyzeHistoricalPatterns(_ emails: [Email]) -> [EmailPattern] {

        var patterns: [EmailPattern] = []

        // Group emails by sender
        let emailsBySender = Dictionary(grouping: emails, by: { $0.senderEmail })

        for (sender, senderEmails) in emailsBySender {

            guard senderEmails.count >= 3 else { continue }

            // Sort by date
            let sortedEmails = senderEmails.sorted { $0.dateReceived < $1.dateReceived }

            // Detect recurrence
            if let recurrenceInterval = detectRecurrenceInterval(sortedEmails) {

                // Extract subject pattern
                let subjectPattern = extractSubjectPattern(sortedEmails)

                patterns.append(EmailPattern(
                    sender: sender,
                    subjectPattern: subjectPattern,
                    isRecurring: true,
                    recurrenceInterval: recurrenceInterval,
                    lastOccurrence: sortedEmails.last?.dateReceived,
                    averageResponseTime: calculateAverageResponseTime(sortedEmails)
                ))
            }
        }

        historicalPatterns = patterns

        return patterns
    }

    private func detectRecurrenceInterval(_ emails: [Email]) -> Int? {

        guard emails.count >= 3 else { return nil }

        // Calculate intervals between consecutive emails
        var intervals: [Int] = []

        for i in 1..<emails.count {
            let interval = Calendar.current.dateComponents(
                [.day],
                from: emails[i-1].dateReceived,
                to: emails[i].dateReceived
            ).day ?? 0

            intervals.append(interval)
        }

        // Check if intervals are consistent (within 2 days tolerance)
        let averageInterval = intervals.reduce(0, +) / intervals.count
        let isConsistent = intervals.allSatisfy { abs($0 - averageInterval) <= 2 }

        return isConsistent ? averageInterval : nil
    }

    private func extractSubjectPattern(_ emails: [Email]) -> String {

        // Find common words in subjects
        let subjects = emails.map { $0.subject.lowercased() }

        // Simple heuristic: use most common subject
        let subjectCounts = Dictionary(grouping: subjects, by: { $0 }).mapValues { $0.count }
        let mostCommon = subjectCounts.max { $0.value < $1.value }?.key ?? "Email from sender"

        return mostCommon.capitalized
    }

    private func calculateAverageResponseTime(_ emails: [Email]) -> TimeInterval {

        // Placeholder: calculate average response time
        return 24 * 3600 // 24 hours
    }

    // MARK: - Prediction Accuracy Tracking

    func recordPredictionResult(prediction: EmailPrediction, wasAccurate: Bool) {

        let result = PredictionResult(
            prediction: prediction,
            wasAccurate: wasAccurate,
            timestamp: Date()
        )

        predictionHistory.append(result)

        // Calculate accuracy rate
        let recentResults = predictionHistory.suffix(100)
        let accurateCount = recentResults.filter { $0.wasAccurate }.count
        accuracyRate = Double(accurateCount) / Double(recentResults.count)

        savePredictionHistory()

        print("📊 Prediction accuracy: \(Int(accuracyRate * 100))%")
    }

    // MARK: - Helpers

    private func getAverageResponseTime(for senderEmail: String) async -> TimeInterval {

        // Get from RelationshipIntelligence
        if let profile = RelationshipIntelligenceEngine.shared.relationships[senderEmail],
           let responseTime = profile.averageResponseTime {
            return responseTime
        }

        // Default: 24 hours
        return 24 * 3600
    }

    private func extractDeadline(from email: Email) -> Date? {

        // Placeholder: extract deadline from email body
        // Could use AI to detect dates
        return nil
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {

        let hours = Int(interval / 3600)

        if hours < 24 {
            return "\(hours) hours"
        } else {
            let days = hours / 24
            return "\(days) day\(days == 1 ? "" : "s")"
        }
    }

    // MARK: - Persistence

    private func loadPredictionHistory() {
        if let data = UserDefaults.standard.data(forKey: "PredictiveEmail_History"),
           let history = try? JSONDecoder().decode([PredictionResult].self, from: data) {
            predictionHistory = history

            // Calculate accuracy
            let recentResults = history.suffix(100)
            if !recentResults.isEmpty {
                let accurateCount = recentResults.filter { $0.wasAccurate }.count
                accuracyRate = Double(accurateCount) / Double(recentResults.count)
            }
        }
    }

    private func savePredictionHistory() {
        // Keep only last 500 results
        let recentHistory = Array(predictionHistory.suffix(500))

        if let data = try? JSONEncoder().encode(recentHistory) {
            UserDefaults.standard.set(data, forKey: "PredictiveEmail_History")
        }
    }

    func updateEmailHistory(_ emails: [Email]) {
        emailHistory = emails
    }
}

// MARK: - Models

struct EmailPrediction: Identifiable {
    let id = UUID()
    let predictedSender: String
    let predictedSubject: String
    let predictedDate: Date
    let confidence: Double // 0.0-1.0
    let type: PredictionType
    let reasoning: String
    let suggestedProactiveAction: String
    var preparedResponse: String?

    var confidencePercent: Int {
        Int(confidence * 100)
    }

    var daysUntil: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: predictedDate).day ?? 0
    }
}

enum PredictionType: String, Codable {
    case recurring = "Recurring"
    case followUp = "Follow-up"
    case deadlineReminder = "Deadline Reminder"
    case checkIn = "Check-in"
    case statusUpdate = "Status Update"
    case meetingRequest = "Meeting Request"
}

struct EmailPattern {
    let sender: String
    let subjectPattern: String
    let isRecurring: Bool
    let recurrenceInterval: Int // days
    let lastOccurrence: Date?
    let averageResponseTime: TimeInterval
}

struct PredictionResult: Codable {
    let predictionId: UUID
    let wasAccurate: Bool
    let timestamp: Date

    init(prediction: EmailPrediction, wasAccurate: Bool, timestamp: Date) {
        self.predictionId = prediction.id
        self.wasAccurate = wasAccurate
        self.timestamp = timestamp
    }
}

// Placeholder types
typealias Email = EmailModels.Email
