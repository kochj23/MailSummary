//
//  AnalyticsModels.swift
//  Mail Summary
//
//  Email Analytics - Data Models
//  Created by Jordan Koch on 2026-01-26
//
//  Tracks email statistics, trends, and user behavior patterns.
//

import Foundation

// MARK: - Email Analytics

struct EmailAnalytics: Codable {
    var dailyStats: [String: DayStats]  // Date string (YYYY-MM-DD) -> stats
    var senderStats: [String: SenderStats]  // Sender email -> stats
    var categoryTrends: [String: [String: Int]]  // Category -> Date -> Count
    var responseTimeAvg: TimeInterval
    var inboxZeroStreak: Int
    var lastUpdated: Date

    init() {
        self.dailyStats = [:]
        self.senderStats = [:]
        self.categoryTrends = [:]
        self.responseTimeAvg = 0
        self.inboxZeroStreak = 0
        self.lastUpdated = Date()
    }

    // Get total emails received in date range
    func totalEmailsReceived(from startDate: Date, to endDate: Date) -> Int {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var total = 0
        var currentDate = startDate

        while currentDate <= endDate {
            let key = dateFormatter.string(from: currentDate)
            total += dailyStats[key]?.received ?? 0
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return total
    }

    // Get stats for specific date
    func statsForDate(_ date: Date) -> DayStats? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let key = dateFormatter.string(from: date)
        return dailyStats[key]
    }

    // Get top senders by volume
    func topSenders(limit: Int = 10) -> [(email: String, stats: SenderStats)] {
        senderStats.sorted { $0.value.totalEmails > $1.value.totalEmails }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }
}

// MARK: - Day Statistics

struct DayStats: Codable {
    let date: Date
    var received: Int
    var read: Int
    var replied: Int
    var deleted: Int
    var archived: Int
    var snoozed: Int
    var highPriority: Int

    init(date: Date) {
        self.date = date
        self.received = 0
        self.read = 0
        self.replied = 0
        self.deleted = 0
        self.archived = 0
        self.snoozed = 0
        self.highPriority = 0
    }

    var totalActions: Int {
        read + replied + deleted + archived + snoozed
    }

    var actionRate: Double {
        guard received > 0 else { return 0.0 }
        return Double(totalActions) / Double(received)
    }
}

// MARK: - Sender Statistics

struct SenderStats: Codable {
    let senderEmail: String
    var totalEmails: Int
    var avgResponseTime: TimeInterval?
    var openRate: Double
    var replyRate: Double
    var deleteRate: Double
    var lastEmailDate: Date?
    var categories: [String: Int]  // Category name -> Count

    init(senderEmail: String) {
        self.senderEmail = senderEmail
        self.totalEmails = 0
        self.avgResponseTime = nil
        self.openRate = 0.0
        self.replyRate = 0.0
        self.deleteRate = 0.0
        self.lastEmailDate = nil
        self.categories = [:]
    }

    var primaryCategory: String? {
        categories.max(by: { $0.value < $1.value })?.key
    }

    var isFrequentSender: Bool {
        totalEmails >= 10
    }

    var isImportant: Bool {
        replyRate > 0.5 || openRate > 0.8
    }
}

// MARK: - Category Trend

struct CategoryTrend: Codable, Identifiable {
    var id: String { category }
    let category: String
    var dataPoints: [DateValuePair]
    var totalCount: Int
    var avgPerDay: Double
    var trend: TrendDirection

    enum TrendDirection: String, Codable {
        case increasing
        case decreasing
        case stable
    }

    init(category: String, dataPoints: [DateValuePair]) {
        self.category = category
        self.dataPoints = dataPoints.sorted { $0.date < $1.date }
        self.totalCount = dataPoints.reduce(0) { $0 + $1.value }
        self.avgPerDay = dataPoints.isEmpty ? 0 : Double(totalCount) / Double(dataPoints.count)

        // Calculate trend (simple: compare first half to second half)
        if dataPoints.count >= 4 {
            let midpoint = dataPoints.count / 2
            let firstHalfAvg = Double(dataPoints.prefix(midpoint).reduce(0) { $0 + $1.value }) / Double(midpoint)
            let secondHalfAvg = Double(dataPoints.suffix(dataPoints.count - midpoint).reduce(0) { $0 + $1.value }) / Double(dataPoints.count - midpoint)

            if secondHalfAvg > firstHalfAvg * 1.2 {
                self.trend = .increasing
            } else if secondHalfAvg < firstHalfAvg * 0.8 {
                self.trend = .decreasing
            } else {
                self.trend = .stable
            }
        } else {
            self.trend = .stable
        }
    }
}

struct DateValuePair: Codable {
    let date: Date
    let value: Int
}

// MARK: - Email Action Record

struct EmailActionRecord: Codable {
    let id: UUID
    let emailId: Int
    let action: ActionType
    let timestamp: Date
    let category: String?
    let sender: String?

    enum ActionType: String, Codable {
        case received
        case read
        case replied
        case deleted
        case archived
        case snoozed
        case moved
        case categorized
    }

    init(id: UUID = UUID(), emailId: Int, action: ActionType, category: String? = nil, sender: String? = nil) {
        self.id = id
        self.emailId = emailId
        self.action = action
        self.timestamp = Date()
        self.category = category
        self.sender = sender
    }
}

// MARK: - Analytics Summary

struct AnalyticsSummary: Codable {
    let period: TimePeriod
    let totalEmails: Int
    let totalRead: Int
    let totalReplied: Int
    let totalDeleted: Int
    let totalArchived: Int
    let avgEmailsPerDay: Double
    let avgResponseTime: TimeInterval?
    let mostActiveDay: String?
    let topCategory: String?
    let topSender: String?

    enum TimePeriod: String, Codable {
        case today
        case week
        case month
        case quarter
        case year
        case allTime

        var displayName: String {
            switch self {
            case .today: return "Today"
            case .week: return "This Week"
            case .month: return "This Month"
            case .quarter: return "This Quarter"
            case .year: return "This Year"
            case .allTime: return "All Time"
            }
        }

        var days: Int {
            switch self {
            case .today: return 1
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            case .allTime: return 3650  // ~10 years
            }
        }
    }

    var readRate: Double {
        guard totalEmails > 0 else { return 0.0 }
        return Double(totalRead) / Double(totalEmails)
    }

    var replyRate: Double {
        guard totalEmails > 0 else { return 0.0 }
        return Double(totalReplied) / Double(totalEmails)
    }

    var deleteRate: Double {
        guard totalEmails > 0 else { return 0.0 }
        return Double(totalDeleted) / Double(totalEmails)
    }
}

// MARK: - Productivity Metrics

struct ProductivityMetrics: Codable {
    var inboxZeroAchieved: Int  // Days with inbox zero
    var avgTimeToRead: TimeInterval
    var avgTimeToReply: TimeInterval
    var emailsProcessedPerDay: Double
    var mostProductiveHour: Int?  // Hour of day (0-23)
    var leastProductiveHour: Int?

    init() {
        self.inboxZeroAchieved = 0
        self.avgTimeToRead = 0
        self.avgTimeToReply = 0
        self.emailsProcessedPerDay = 0
        self.mostProductiveHour = nil
        self.leastProductiveHour = nil
    }
}

// MARK: - Email Insights (Feature 12)

struct EmailInsights: Codable {
    var dailyDigest: String
    var trends: [Trend]
    var recommendations: [Recommendation]
    var predictions: [Prediction]
    var generatedAt: Date

    init(dailyDigest: String = "", trends: [Trend] = [], recommendations: [Recommendation] = [], predictions: [Prediction] = []) {
        self.dailyDigest = dailyDigest
        self.trends = trends
        self.recommendations = recommendations
        self.predictions = predictions
        self.generatedAt = Date()
    }
}

struct Trend: Codable, Identifiable {
    var id: UUID
    var type: TrendType
    var category: String?
    var description: String
    var percentageChange: Double
    var isPositive: Bool

    enum TrendType: String, Codable {
        case increasing = "Increasing"
        case decreasing = "Decreasing"
        case stable = "Stable"
        case spike = "Spike"
        case drop = "Drop"

        var icon: String {
            switch self {
            case .increasing: return "arrow.up.right"
            case .decreasing: return "arrow.down.right"
            case .stable: return "arrow.right"
            case .spike: return "arrow.up"
            case .drop: return "arrow.down"
            }
        }
    }

    init(id: UUID = UUID(), type: TrendType, category: String?, description: String, percentageChange: Double, isPositive: Bool = true) {
        self.id = id
        self.type = type
        self.category = category
        self.description = description
        self.percentageChange = percentageChange
        self.isPositive = isPositive
    }
}

struct Recommendation: Codable, Identifiable {
    var id: UUID
    var priority: Int  // 1-10
    var title: String
    var description: String
    var actionable: Bool
    var suggestedAction: String?
    var category: String?

    init(id: UUID = UUID(), priority: Int, title: String, description: String, actionable: Bool = true, suggestedAction: String? = nil, category: String? = nil) {
        self.id = id
        self.priority = priority
        self.title = title
        self.description = description
        self.actionable = actionable
        self.suggestedAction = suggestedAction
        self.category = category
    }

    var priorityColor: String {
        if priority >= 8 { return "red" }
        if priority >= 5 { return "orange" }
        return "blue"
    }
}

struct Prediction: Codable, Identifiable {
    var id: UUID
    var prediction: String
    var confidence: Double  // 0-1
    var basis: String
    var category: String?

    init(id: UUID = UUID(), prediction: String, confidence: Double, basis: String, category: String? = nil) {
        self.id = id
        self.prediction = prediction
        self.confidence = confidence
        self.basis = basis
        self.category = category
    }

    var confidenceLevel: String {
        if confidence >= 0.8 { return "High" }
        if confidence >= 0.5 { return "Medium" }
        return "Low"
    }
}
