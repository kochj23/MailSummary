//
//  WidgetData.swift
//  Mail Summary Widget
//
//  Data models for widget display
//  Created by Jordan Koch on 2026-02-04
//

import Foundation
import WidgetKit

/// Data structure shared between main app and widget via App Group
struct MailSummaryWidgetData: Codable {
    var unreadCount: Int
    var highPriorityCount: Int
    var timeSavedMinutes: Int
    var emailsHandledAutomatically: Int
    var totalEmailsToday: Int
    var lastUpdated: Date
    var topCategories: [CategoryCount]
    var aiSummary: String
    var inboxZeroStreak: Int

    /// Default empty data
    static var empty: MailSummaryWidgetData {
        MailSummaryWidgetData(
            unreadCount: 0,
            highPriorityCount: 0,
            timeSavedMinutes: 0,
            emailsHandledAutomatically: 0,
            totalEmailsToday: 0,
            lastUpdated: Date(),
            topCategories: [],
            aiSummary: "Open Mail Summary to get started",
            inboxZeroStreak: 0
        )
    }

    /// Sample data for widget previews
    static var preview: MailSummaryWidgetData {
        MailSummaryWidgetData(
            unreadCount: 12,
            highPriorityCount: 3,
            timeSavedMinutes: 108,
            emailsHandledAutomatically: 47,
            totalEmailsToday: 62,
            lastUpdated: Date(),
            topCategories: [
                CategoryCount(name: "Work", count: 23, icon: "briefcase.fill"),
                CategoryCount(name: "Marketing", count: 15, icon: "megaphone.fill"),
                CategoryCount(name: "Personal", count: 8, icon: "person.fill")
            ],
            aiSummary: "3 emails need your attention. 47 handled automatically.",
            inboxZeroStreak: 5
        )
    }
}

/// Category count for top categories display
struct CategoryCount: Codable, Identifiable {
    var id: String { name }
    let name: String
    let count: Int
    let icon: String
}

/// Widget timeline entry
struct MailSummaryEntry: TimelineEntry {
    let date: Date
    let data: MailSummaryWidgetData
    let configuration: ConfigurationIntent?

    init(date: Date, data: MailSummaryWidgetData, configuration: ConfigurationIntent? = nil) {
        self.date = date
        self.data = data
        self.configuration = configuration
    }
}

/// Simple configuration intent (no user configuration needed)
struct ConfigurationIntent {
    // No configurable options for now
}

/// Widget refresh policy
enum WidgetRefreshPolicy {
    case everyFiveMinutes
    case everyFifteenMinutes
    case everyHour

    var timeInterval: TimeInterval {
        switch self {
        case .everyFiveMinutes: return 5 * 60
        case .everyFifteenMinutes: return 15 * 60
        case .everyHour: return 60 * 60
        }
    }
}
