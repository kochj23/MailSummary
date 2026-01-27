//
//  AnalyticsManager.swift
//  Mail Summary
//
//  Email Analytics - Business Logic
//  Created by Jordan Koch on 2026-01-26
//
//  Tracks email statistics and generates insights for productivity analysis.
//

import Foundation

@MainActor
class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()

    // MARK: - Published Properties

    @Published var analytics: EmailAnalytics = EmailAnalytics()
    @Published var isProcessing: Bool = false

    // MARK: - Private Properties

    private let analyticsFileURL: URL
    private let actionsFileURL: URL
    private let maxActionsToStore = 10000  // Keep last 10K actions
    private var recentActions: [EmailActionRecord] = []

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: - Initialization

    private init() {
        // Store analytics in Documents folder
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let analyticsFolder = documentsPath.appendingPathComponent("MailSummaryAnalytics", isDirectory: true)

        // Create folder if it doesn't exist
        try? FileManager.default.createDirectory(at: analyticsFolder, withIntermediateDirectories: true)

        analyticsFileURL = analyticsFolder.appendingPathComponent("analytics.json")
        actionsFileURL = analyticsFolder.appendingPathComponent("actions.json")

        loadAnalytics()
        loadActions()
        cleanupOldData()
    }

    // MARK: - Action Recording

    /// Record that an email was received
    func recordEmailReceived(_ email: Email) {
        let dateKey = dateFormatter.string(from: email.dateReceived)

        // Update daily stats
        if analytics.dailyStats[dateKey] == nil {
            analytics.dailyStats[dateKey] = DayStats(date: email.dateReceived)
        }
        analytics.dailyStats[dateKey]?.received += 1

        if (email.priority ?? 0) >= 7 {
            analytics.dailyStats[dateKey]?.highPriority += 1
        }

        // Update sender stats
        if analytics.senderStats[email.senderEmail] == nil {
            analytics.senderStats[email.senderEmail] = SenderStats(senderEmail: email.senderEmail)
        }
        analytics.senderStats[email.senderEmail]?.totalEmails += 1
        analytics.senderStats[email.senderEmail]?.lastEmailDate = email.dateReceived

        // Update category trends
        if let category = email.category {
            let categoryKey = category.rawValue
            if analytics.categoryTrends[categoryKey] == nil {
                analytics.categoryTrends[categoryKey] = [:]
            }
            analytics.categoryTrends[categoryKey]?[dateKey, default: 0] += 1

            // Update sender's category distribution
            analytics.senderStats[email.senderEmail]?.categories[categoryKey, default: 0] += 1
        }

        // Record action
        let action = EmailActionRecord(emailId: email.id, action: .received, category: email.category?.rawValue, sender: email.senderEmail)
        recentActions.append(action)

        analytics.lastUpdated = Date()
        saveAnalytics()
    }

    /// Record that an email was read
    func recordEmailRead(_ email: Email) {
        let dateKey = dateFormatter.string(from: Date())

        if analytics.dailyStats[dateKey] == nil {
            analytics.dailyStats[dateKey] = DayStats(date: Date())
        }
        analytics.dailyStats[dateKey]?.read += 1

        // Update sender stats
        if var senderStat = analytics.senderStats[email.senderEmail] {
            let openCount = Int(senderStat.openRate * Double(senderStat.totalEmails)) + 1
            senderStat.openRate = Double(openCount) / Double(senderStat.totalEmails)
            analytics.senderStats[email.senderEmail] = senderStat
        }

        let action = EmailActionRecord(emailId: email.id, action: .read, category: email.category?.rawValue, sender: email.senderEmail)
        recentActions.append(action)

        analytics.lastUpdated = Date()
        saveAnalytics()
    }

    /// Record that an email was replied to
    func recordEmailReplied(_ email: Email) {
        let dateKey = dateFormatter.string(from: Date())

        if analytics.dailyStats[dateKey] == nil {
            analytics.dailyStats[dateKey] = DayStats(date: Date())
        }
        analytics.dailyStats[dateKey]?.replied += 1

        // Update sender stats
        if var senderStat = analytics.senderStats[email.senderEmail] {
            let replyCount = Int(senderStat.replyRate * Double(senderStat.totalEmails)) + 1
            senderStat.replyRate = Double(replyCount) / Double(senderStat.totalEmails)

            // Calculate response time
            let responseTime = Date().timeIntervalSince(email.dateReceived)
            if let avgTime = senderStat.avgResponseTime {
                senderStat.avgResponseTime = (avgTime + responseTime) / 2
            } else {
                senderStat.avgResponseTime = responseTime
            }

            analytics.senderStats[email.senderEmail] = senderStat
        }

        let action = EmailActionRecord(emailId: email.id, action: .replied, category: email.category?.rawValue, sender: email.senderEmail)
        recentActions.append(action)

        analytics.lastUpdated = Date()
        saveAnalytics()
    }

    /// Record that an email was deleted
    func recordEmailDeleted(_ email: Email) {
        let dateKey = dateFormatter.string(from: Date())

        if analytics.dailyStats[dateKey] == nil {
            analytics.dailyStats[dateKey] = DayStats(date: Date())
        }
        analytics.dailyStats[dateKey]?.deleted += 1

        // Update sender stats
        if var senderStat = analytics.senderStats[email.senderEmail] {
            let deleteCount = Int(senderStat.deleteRate * Double(senderStat.totalEmails)) + 1
            senderStat.deleteRate = Double(deleteCount) / Double(senderStat.totalEmails)
            analytics.senderStats[email.senderEmail] = senderStat
        }

        let action = EmailActionRecord(emailId: email.id, action: .deleted, category: email.category?.rawValue, sender: email.senderEmail)
        recentActions.append(action)

        analytics.lastUpdated = Date()
        saveAnalytics()
    }

    /// Record that an email was archived
    func recordEmailArchived(_ email: Email) {
        let dateKey = dateFormatter.string(from: Date())

        if analytics.dailyStats[dateKey] == nil {
            analytics.dailyStats[dateKey] = DayStats(date: Date())
        }
        analytics.dailyStats[dateKey]?.archived += 1

        let action = EmailActionRecord(emailId: email.id, action: .archived, category: email.category?.rawValue, sender: email.senderEmail)
        recentActions.append(action)

        analytics.lastUpdated = Date()
        saveAnalytics()
    }

    /// Record that an email was snoozed
    func recordEmailSnoozed(_ email: Email) {
        let dateKey = dateFormatter.string(from: Date())

        if analytics.dailyStats[dateKey] == nil {
            analytics.dailyStats[dateKey] = DayStats(date: Date())
        }
        analytics.dailyStats[dateKey]?.snoozed += 1

        let action = EmailActionRecord(emailId: email.id, action: .snoozed, category: email.category?.rawValue, sender: email.senderEmail)
        recentActions.append(action)

        analytics.lastUpdated = Date()
        saveAnalytics()
    }

    // MARK: - Summary Generation

    /// Generate summary for a specific time period
    func generateSummary(for period: AnalyticsSummary.TimePeriod) -> AnalyticsSummary {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -period.days, to: endDate) ?? endDate

        var totalEmails = 0
        var totalRead = 0
        var totalReplied = 0
        var totalDeleted = 0
        var totalArchived = 0
        var dayCounts: [String: Int] = [:]
        var categoryCounts: [String: Int] = [:]

        // Iterate through date range
        var currentDate = startDate
        while currentDate <= endDate {
            let dateKey = dateFormatter.string(from: currentDate)

            if let dayStats = analytics.dailyStats[dateKey] {
                totalEmails += dayStats.received
                totalRead += dayStats.read
                totalReplied += dayStats.replied
                totalDeleted += dayStats.deleted
                totalArchived += dayStats.archived
                dayCounts[dateKey] = dayStats.received
            }

            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        // Calculate category counts for period
        for (category, dateValues) in analytics.categoryTrends {
            var count = 0
            var checkDate = startDate
            while checkDate <= endDate {
                let dateKey = dateFormatter.string(from: checkDate)
                count += dateValues[dateKey] ?? 0
                checkDate = Calendar.current.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate
            }
            if count > 0 {
                categoryCounts[category] = count
            }
        }

        let mostActiveDay = dayCounts.max(by: { $0.value < $1.value })?.key
        let topCategory = categoryCounts.max(by: { $0.value < $1.value })?.key
        let topSender = analytics.topSenders(limit: 1).first?.email

        let avgEmailsPerDay = period.days > 0 ? Double(totalEmails) / Double(period.days) : 0

        return AnalyticsSummary(
            period: period,
            totalEmails: totalEmails,
            totalRead: totalRead,
            totalReplied: totalReplied,
            totalDeleted: totalDeleted,
            totalArchived: totalArchived,
            avgEmailsPerDay: avgEmailsPerDay,
            avgResponseTime: analytics.responseTimeAvg,
            mostActiveDay: mostActiveDay,
            topCategory: topCategory,
            topSender: topSender
        )
    }

    /// Get category trends for a time period
    func getCategoryTrends(for period: AnalyticsSummary.TimePeriod) -> [CategoryTrend] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -period.days, to: endDate) ?? endDate

        var trends: [CategoryTrend] = []

        for (category, dateValues) in analytics.categoryTrends {
            var dataPoints: [DateValuePair] = []

            var currentDate = startDate
            while currentDate <= endDate {
                let dateKey = dateFormatter.string(from: currentDate)
                if let count = dateValues[dateKey], count > 0 {
                    dataPoints.append(DateValuePair(date: currentDate, value: count))
                }
                currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }

            if !dataPoints.isEmpty {
                trends.append(CategoryTrend(category: category, dataPoints: dataPoints))
            }
        }

        return trends.sorted { $0.totalCount > $1.totalCount }
    }

    /// Get daily stats for a specific date range
    func getDailyStats(from startDate: Date, to endDate: Date) -> [DayStats] {
        var stats: [DayStats] = []

        var currentDate = startDate
        while currentDate <= endDate {
            let dateKey = dateFormatter.string(from: currentDate)
            if let dayStats = analytics.dailyStats[dateKey] {
                stats.append(dayStats)
            } else {
                stats.append(DayStats(date: currentDate))
            }
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return stats
    }

    // MARK: - Export

    /// Export analytics to CSV format
    func exportToCSV() -> String {
        var csv = "Date,Received,Read,Replied,Deleted,Archived,Snoozed,HighPriority\n"

        let sortedDates = analytics.dailyStats.keys.sorted()
        for dateKey in sortedDates {
            if let stats = analytics.dailyStats[dateKey] {
                csv += "\(dateKey),\(stats.received),\(stats.read),\(stats.replied),\(stats.deleted),\(stats.archived),\(stats.snoozed),\(stats.highPriority)\n"
            }
        }

        return csv
    }

    /// Export sender stats to CSV
    func exportSenderStatsToCSV() -> String {
        var csv = "Sender,TotalEmails,OpenRate,ReplyRate,DeleteRate,AvgResponseTime,PrimaryCategory\n"

        let sortedSenders = analytics.senderStats.values.sorted { $0.totalEmails > $1.totalEmails }
        for sender in sortedSenders {
            let avgResponse = sender.avgResponseTime.map { String(format: "%.0f", $0) } ?? "N/A"
            let category = sender.primaryCategory ?? "Unknown"
            csv += "\(sender.senderEmail),\(sender.totalEmails),\(String(format: "%.2f", sender.openRate)),\(String(format: "%.2f", sender.replyRate)),\(String(format: "%.2f", sender.deleteRate)),\(avgResponse),\(category)\n"
        }

        return csv
    }

    // MARK: - Persistence

    private func saveAnalytics() {
        do {
            let data = try JSONEncoder().encode(analytics)
            try data.write(to: analyticsFileURL)

            // Also save recent actions (keep last 10K)
            if recentActions.count > maxActionsToStore {
                recentActions = Array(recentActions.suffix(maxActionsToStore))
            }
            let actionsData = try JSONEncoder().encode(recentActions)
            try actionsData.write(to: actionsFileURL)
        } catch {
            print("❌ Failed to save analytics: \(error)")
        }
    }

    private func loadAnalytics() {
        do {
            let data = try Data(contentsOf: analyticsFileURL)
            analytics = try JSONDecoder().decode(EmailAnalytics.self, from: data)
            print("✅ Loaded analytics: \(analytics.dailyStats.count) days, \(analytics.senderStats.count) senders")
        } catch {
            print("⚠️ No existing analytics found, starting fresh")
        }
    }

    private func loadActions() {
        do {
            let data = try Data(contentsOf: actionsFileURL)
            recentActions = try JSONDecoder().decode([EmailActionRecord].self, from: data)
            print("✅ Loaded \(recentActions.count) action records")
        } catch {
            print("⚠️ No existing action records found")
        }
    }

    /// Clean up data older than 90 days
    private func cleanupOldData() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let cutoffKey = dateFormatter.string(from: cutoffDate)

        // Remove old daily stats
        analytics.dailyStats = analytics.dailyStats.filter { $0.key >= cutoffKey }

        // Remove old actions
        recentActions = recentActions.filter { $0.timestamp >= cutoffDate }

        saveAnalytics()
    }

    /// Reset all analytics (for testing)
    func resetAnalytics() {
        analytics = EmailAnalytics()
        recentActions = []
        try? FileManager.default.removeItem(at: analyticsFileURL)
        try? FileManager.default.removeItem(at: actionsFileURL)
        saveAnalytics()
    }
}
