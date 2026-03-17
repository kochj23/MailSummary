//
//  SharedDataManager.swift
//  Mail Summary Widget
//
//  Manages data sharing between main app and widget via App Group
//  Created by Jordan Koch on 2026-02-04
//

import Foundation
import WidgetKit

/// Manages shared data between main app and widget using App Group container
class SharedDataManager {
    static let shared = SharedDataManager()

    /// App Group identifier for data sharing
    private let appGroupIdentifier = "group.com.jkoch.mailsummary"

    /// Key for storing widget data in UserDefaults
    private let widgetDataKey = "MailSummaryWidgetData"

    /// Shared UserDefaults container (falls back to standard if App Group unavailable)
    private var sharedDefaults: UserDefaults? {
        // Try App Group first, fall back to standard UserDefaults
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            return appGroupDefaults
        }
        print("Widget: App Group not available, using standard UserDefaults")
        return UserDefaults.standard
    }

    private init() {}

    // MARK: - Read Widget Data

    /// Load widget data from shared container
    func loadWidgetData() -> MailSummaryWidgetData {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: widgetDataKey) else {
            print("Widget: No shared data found, using empty data")
            return .empty
        }

        do {
            let widgetData = try JSONDecoder().decode(MailSummaryWidgetData.self, from: data)
            print("Widget: Loaded data - \(widgetData.unreadCount) unread, \(widgetData.highPriorityCount) high priority")
            return widgetData
        } catch {
            print("Widget: Failed to decode widget data: \(error)")
            return .empty
        }
    }

    // MARK: - Write Widget Data (Main App Only)

    /// Save widget data to shared container (called from main app)
    func saveWidgetData(_ widgetData: MailSummaryWidgetData) {
        guard let defaults = sharedDefaults else {
            print("Widget: Failed to access shared UserDefaults")
            return
        }

        do {
            let data = try JSONEncoder().encode(widgetData)
            defaults.set(data, forKey: widgetDataKey)
            defaults.synchronize()
            print("Widget: Saved data - \(widgetData.unreadCount) unread, \(widgetData.emailsHandledAutomatically) auto-handled")

            // Request widget refresh
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Widget: Failed to encode widget data: \(error)")
        }
    }

    // MARK: - Helper Methods

    /// Update widget with current email stats (called from main app's MailEngine)
    func updateWidgetStats(
        unreadCount: Int,
        highPriorityCount: Int,
        timeSavedMinutes: Int,
        emailsHandledAutomatically: Int,
        totalEmailsToday: Int,
        topCategories: [(name: String, count: Int, icon: String)],
        aiSummary: String,
        inboxZeroStreak: Int
    ) {
        let categories = topCategories.map {
            CategoryCount(name: $0.name, count: $0.count, icon: $0.icon)
        }

        let widgetData = MailSummaryWidgetData(
            unreadCount: unreadCount,
            highPriorityCount: highPriorityCount,
            timeSavedMinutes: timeSavedMinutes,
            emailsHandledAutomatically: emailsHandledAutomatically,
            totalEmailsToday: totalEmailsToday,
            lastUpdated: Date(),
            topCategories: categories,
            aiSummary: aiSummary,
            inboxZeroStreak: inboxZeroStreak
        )

        saveWidgetData(widgetData)
    }

    /// Force refresh all widgets
    func refreshWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Get the time since last update as a formatted string
    func timeSinceLastUpdate() -> String {
        let data = loadWidgetData()
        let interval = Date().timeIntervalSince(data.lastUpdated)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Main App Integration Extension

extension SharedDataManager {
    /// Create widget data from MailEngine stats
    /// Call this from MailEngine.updateStats() in the main app
    func syncFromMailEngine(
        emails: [Any],  // Email array
        stats: (totalEmails: Int, unreadEmails: Int, todayEmails: Int, highPriorityEmails: Int, actionsCount: Int),
        aiSummary: String,
        categories: [(category: String, count: Int, icon: String)]
    ) {
        // Calculate time saved (estimate: 2 minutes per email handled automatically)
        let emailsHandled = stats.actionsCount
        let timeSaved = emailsHandled * 2  // 2 minutes per auto-handled email

        updateWidgetStats(
            unreadCount: stats.unreadEmails,
            highPriorityCount: stats.highPriorityEmails,
            timeSavedMinutes: timeSaved,
            emailsHandledAutomatically: emailsHandled,
            totalEmailsToday: stats.todayEmails,
            topCategories: categories.prefix(3).map { ($0.category, $0.count, $0.icon) },
            aiSummary: aiSummary,
            inboxZeroStreak: 0  // Calculate from analytics if needed
        )
    }
}
