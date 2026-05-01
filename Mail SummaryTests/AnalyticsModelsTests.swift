//
//  AnalyticsModelsTests.swift
//  Mail SummaryTests
//
//  Tests for EmailAnalytics, DayStats, SenderStats, EmailInsights, Trend, Recommendation, Prediction
//  Created by Jordan Koch
//

import XCTest
@testable import Mail_Summary

final class AnalyticsModelsTests: XCTestCase {

    // MARK: - EmailAnalytics

    func testEmailAnalyticsInit() {
        let analytics = EmailAnalytics()

        XCTAssertTrue(analytics.dailyStats.isEmpty)
        XCTAssertTrue(analytics.senderStats.isEmpty)
        XCTAssertTrue(analytics.categoryTrends.isEmpty)
        XCTAssertEqual(analytics.responseTimeAvg, 0)
        XCTAssertEqual(analytics.inboxZeroStreak, 0)
    }

    func testTotalEmailsReceivedInRange() {
        var analytics = EmailAnalytics()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let today = Date()
        let todayKey = dateFormatter.string(from: today)
        var todayStats = DayStats(date: today)
        todayStats.received = 15
        analytics.dailyStats[todayKey] = todayStats

        let total = analytics.totalEmailsReceived(from: today, to: today)
        XCTAssertEqual(total, 15)
    }

    func testTopSendersOrdering() {
        var analytics = EmailAnalytics()

        var sender1Stats = SenderStats(senderEmail: "alice@test.com")
        sender1Stats.totalEmails = 50
        analytics.senderStats["alice@test.com"] = sender1Stats

        var sender2Stats = SenderStats(senderEmail: "bob@test.com")
        sender2Stats.totalEmails = 100
        analytics.senderStats["bob@test.com"] = sender2Stats

        var sender3Stats = SenderStats(senderEmail: "carol@test.com")
        sender3Stats.totalEmails = 25
        analytics.senderStats["carol@test.com"] = sender3Stats

        let top2 = analytics.topSenders(limit: 2)
        XCTAssertEqual(top2.count, 2)
        XCTAssertEqual(top2.first?.email, "bob@test.com")
        XCTAssertEqual(top2.last?.email, "alice@test.com")
    }

    func testStatsForDateReturnsNilForMissingDate() {
        let analytics = EmailAnalytics()
        XCTAssertNil(analytics.statsForDate(Date()))
    }

    // MARK: - DayStats

    func testDayStatsInit() {
        let stats = DayStats(date: Date())

        XCTAssertEqual(stats.received, 0)
        XCTAssertEqual(stats.read, 0)
        XCTAssertEqual(stats.replied, 0)
        XCTAssertEqual(stats.deleted, 0)
        XCTAssertEqual(stats.archived, 0)
        XCTAssertEqual(stats.snoozed, 0)
        XCTAssertEqual(stats.highPriority, 0)
    }

    func testDayStatsTotalActions() {
        var stats = DayStats(date: Date())
        stats.read = 10
        stats.replied = 5
        stats.deleted = 3
        stats.archived = 7
        stats.snoozed = 2

        XCTAssertEqual(stats.totalActions, 27)
    }

    func testDayStatsActionRate() {
        var stats = DayStats(date: Date())
        stats.received = 20
        stats.read = 10
        stats.replied = 5
        stats.deleted = 3
        stats.archived = 2

        XCTAssertEqual(stats.actionRate, 1.0, accuracy: 0.01)
    }

    func testDayStatsActionRateZeroDivision() {
        let stats = DayStats(date: Date())
        XCTAssertEqual(stats.actionRate, 0.0)
    }

    // MARK: - SenderStats

    func testSenderStatsInit() {
        let stats = SenderStats(senderEmail: "user@test.com")

        XCTAssertEqual(stats.senderEmail, "user@test.com")
        XCTAssertEqual(stats.totalEmails, 0)
        XCTAssertNil(stats.avgResponseTime)
        XCTAssertEqual(stats.openRate, 0.0)
        XCTAssertEqual(stats.replyRate, 0.0)
        XCTAssertEqual(stats.deleteRate, 0.0)
    }

    func testSenderStatsIsFrequentSender() {
        var stats = SenderStats(senderEmail: "user@test.com")
        stats.totalEmails = 10
        XCTAssertTrue(stats.isFrequentSender)

        stats.totalEmails = 5
        XCTAssertFalse(stats.isFrequentSender)
    }

    func testSenderStatsIsImportant() {
        var stats = SenderStats(senderEmail: "user@test.com")
        stats.replyRate = 0.6
        XCTAssertTrue(stats.isImportant, "High reply rate should indicate importance")

        stats.replyRate = 0.3
        stats.openRate = 0.9
        XCTAssertTrue(stats.isImportant, "High open rate should indicate importance")

        stats.replyRate = 0.3
        stats.openRate = 0.5
        XCTAssertFalse(stats.isImportant)
    }

    func testSenderStatsPrimaryCategory() {
        var stats = SenderStats(senderEmail: "user@test.com")
        stats.categories = ["Work": 10, "Personal": 3, "Marketing": 1]

        XCTAssertEqual(stats.primaryCategory, "Work")
    }

    // MARK: - EmailInsights

    func testEmailInsightsInit() {
        let insights = EmailInsights()

        XCTAssertTrue(insights.dailyDigest.isEmpty)
        XCTAssertTrue(insights.trends.isEmpty)
        XCTAssertTrue(insights.recommendations.isEmpty)
        XCTAssertTrue(insights.predictions.isEmpty)
        XCTAssertNotNil(insights.generatedAt)
    }

    func testEmailInsightsCodable() throws {
        let insights = EmailInsights(
            dailyDigest: "3 urgent emails",
            trends: [Trend(type: .increasing, category: "Work", description: "Up 20%", percentageChange: 20.0)],
            recommendations: [Recommendation(priority: 9, title: "Check bills", description: "2 bills due")],
            predictions: [Prediction(prediction: "10 emails tomorrow", confidence: 0.8, basis: "Historical")]
        )

        let data = try JSONEncoder().encode(insights)
        let decoded = try JSONDecoder().decode(EmailInsights.self, from: data)

        XCTAssertEqual(decoded.dailyDigest, "3 urgent emails")
        XCTAssertEqual(decoded.trends.count, 1)
        XCTAssertEqual(decoded.recommendations.count, 1)
        XCTAssertEqual(decoded.predictions.count, 1)
    }

    // MARK: - Trend

    func testTrendTypeIcons() {
        XCTAssertFalse(Trend.TrendType.increasing.icon.isEmpty)
        XCTAssertFalse(Trend.TrendType.decreasing.icon.isEmpty)
        XCTAssertFalse(Trend.TrendType.stable.icon.isEmpty)
        XCTAssertFalse(Trend.TrendType.spike.icon.isEmpty)
        XCTAssertFalse(Trend.TrendType.drop.icon.isEmpty)
    }

    // MARK: - Recommendation

    func testRecommendationPriorityColors() {
        let high = Recommendation(priority: 9, title: "T", description: "D")
        XCTAssertEqual(high.priorityColor, "red")

        let medium = Recommendation(priority: 6, title: "T", description: "D")
        XCTAssertEqual(medium.priorityColor, "orange")

        let low = Recommendation(priority: 3, title: "T", description: "D")
        XCTAssertEqual(low.priorityColor, "blue")
    }

    // MARK: - Prediction

    func testPredictionConfidenceLevel() {
        let high = Prediction(prediction: "P", confidence: 0.9, basis: "B")
        XCTAssertEqual(high.confidenceLevel, "High")

        let medium = Prediction(prediction: "P", confidence: 0.6, basis: "B")
        XCTAssertEqual(medium.confidenceLevel, "Medium")

        let low = Prediction(prediction: "P", confidence: 0.3, basis: "B")
        XCTAssertEqual(low.confidenceLevel, "Low")
    }

    // MARK: - CategoryTrend

    func testCategoryTrendCalculation() {
        let dataPoints = [
            DateValuePair(date: Date().addingTimeInterval(-86400 * 3), value: 5),
            DateValuePair(date: Date().addingTimeInterval(-86400 * 2), value: 6),
            DateValuePair(date: Date().addingTimeInterval(-86400), value: 10),
            DateValuePair(date: Date(), value: 12)
        ]

        let trend = CategoryTrend(category: "Work", dataPoints: dataPoints)

        XCTAssertEqual(trend.category, "Work")
        XCTAssertEqual(trend.totalCount, 33)
        XCTAssertEqual(trend.trend, .increasing)
    }

    func testCategoryTrendStable() {
        let dataPoints = [
            DateValuePair(date: Date().addingTimeInterval(-86400 * 3), value: 10),
            DateValuePair(date: Date().addingTimeInterval(-86400 * 2), value: 10),
            DateValuePair(date: Date().addingTimeInterval(-86400), value: 10),
            DateValuePair(date: Date(), value: 10)
        ]

        let trend = CategoryTrend(category: "Work", dataPoints: dataPoints)
        XCTAssertEqual(trend.trend, .stable)
    }

    // MARK: - AnalyticsSummary

    func testAnalyticsSummaryRates() {
        let summary = AnalyticsSummary(
            period: .week,
            totalEmails: 100,
            totalRead: 80,
            totalReplied: 30,
            totalDeleted: 10,
            totalArchived: 20,
            avgEmailsPerDay: 14.3,
            avgResponseTime: 3600,
            mostActiveDay: "Monday",
            topCategory: "Work",
            topSender: "boss@company.com"
        )

        XCTAssertEqual(summary.readRate, 0.8, accuracy: 0.01)
        XCTAssertEqual(summary.replyRate, 0.3, accuracy: 0.01)
        XCTAssertEqual(summary.deleteRate, 0.1, accuracy: 0.01)
    }

    func testAnalyticsSummaryZeroDivision() {
        let summary = AnalyticsSummary(
            period: .today, totalEmails: 0, totalRead: 0, totalReplied: 0,
            totalDeleted: 0, totalArchived: 0, avgEmailsPerDay: 0,
            avgResponseTime: nil, mostActiveDay: nil, topCategory: nil, topSender: nil
        )

        XCTAssertEqual(summary.readRate, 0.0)
        XCTAssertEqual(summary.replyRate, 0.0)
        XCTAssertEqual(summary.deleteRate, 0.0)
    }

    // MARK: - ProductivityMetrics

    func testProductivityMetricsInit() {
        let metrics = ProductivityMetrics()

        XCTAssertEqual(metrics.inboxZeroAchieved, 0)
        XCTAssertEqual(metrics.avgTimeToRead, 0)
        XCTAssertEqual(metrics.avgTimeToReply, 0)
        XCTAssertEqual(metrics.emailsProcessedPerDay, 0)
        XCTAssertNil(metrics.mostProductiveHour)
        XCTAssertNil(metrics.leastProductiveHour)
    }

    // MARK: - EmailActionRecord

    func testEmailActionRecordInit() {
        let record = EmailActionRecord(emailId: 42, action: .read, category: "Work", sender: "boss@test.com")

        XCTAssertEqual(record.emailId, 42)
        XCTAssertEqual(record.action, .read)
        XCTAssertEqual(record.category, "Work")
        XCTAssertEqual(record.sender, "boss@test.com")
        XCTAssertNotNil(record.id)
    }
}
