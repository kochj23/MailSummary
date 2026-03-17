//
//  MailSummaryWidget.swift
//  Mail Summary Widget
//
//  WidgetKit widget for Mail Summary app
//  Displays email stats at a glance
//  Created by Jordan Koch on 2026-02-04
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct MailSummaryTimelineProvider: TimelineProvider {
    typealias Entry = MailSummaryEntry

    func placeholder(in context: Context) -> MailSummaryEntry {
        MailSummaryEntry(date: Date(), data: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (MailSummaryEntry) -> Void) {
        let data = context.isPreview ? .preview : SharedDataManager.shared.loadWidgetData()
        let entry = MailSummaryEntry(date: Date(), data: data)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MailSummaryEntry>) -> Void) {
        let currentDate = Date()
        let data = SharedDataManager.shared.loadWidgetData()
        let entry = MailSummaryEntry(date: currentDate, data: data)

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let data: MailSummaryWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "envelope.badge.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Spacer()
                if data.highPriorityCount > 0 {
                    Text("\(data.highPriorityCount)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            // Unread Count
            VStack(alignment: .leading, spacing: 2) {
                Text("\(data.unreadCount)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("Unread")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Time Saved
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
                Text("\(formatTimeSaved(data.timeSavedMinutes)) saved")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
        .padding()
    }

    private func formatTimeSaved(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let data: MailSummaryWidgetData

    var body: some View {
        HStack(spacing: 16) {
            // Left Column - Main Stats
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Image(systemName: "envelope.badge.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("Mail Summary")
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                Spacer()

                // Stats Grid
                HStack(spacing: 16) {
                    StatBox(
                        value: "\(data.unreadCount)",
                        label: "Unread",
                        icon: "envelope.fill",
                        color: .blue
                    )

                    StatBox(
                        value: "\(data.highPriorityCount)",
                        label: "Priority",
                        icon: "exclamationmark.triangle.fill",
                        color: .red
                    )
                }

                Spacer()

                // Time Saved
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("\(formatTimeSaved(data.timeSavedMinutes)) saved today")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            Divider()
                .padding(.vertical, 8)

            // Right Column - Auto-handled
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Handled")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                Text("\(data.emailsHandledAutomatically)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.purple)

                Text("emails")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Categories
                if !data.topCategories.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(data.topCategories.prefix(2)) { category in
                            HStack(spacing: 4) {
                                Image(systemName: category.icon)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(category.count)")
                                    .font(.caption2.bold())
                                Text(category.name)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func formatTimeSaved(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
}

// MARK: - Large Widget View

struct LargeWidgetView: View {
    let data: MailSummaryWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "envelope.badge.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Mail Summary")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("Updated \(timeAgo)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Main Stats Row
            HStack(spacing: 16) {
                LargeStatBox(
                    value: "\(data.unreadCount)",
                    label: "Unread",
                    icon: "envelope.fill",
                    color: .blue
                )

                LargeStatBox(
                    value: "\(data.highPriorityCount)",
                    label: "High Priority",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )

                LargeStatBox(
                    value: formatTimeSaved(data.timeSavedMinutes),
                    label: "Time Saved",
                    icon: "clock.fill",
                    color: .green
                )

                LargeStatBox(
                    value: "\(data.emailsHandledAutomatically)",
                    label: "AI Handled",
                    icon: "cpu.fill",
                    color: .purple
                )
            }

            Divider()

            // AI Summary
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.orange)
                    Text("AI Summary")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
                Text(data.aiSummary)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }

            Divider()

            // Categories
            if !data.topCategories.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Categories")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        ForEach(data.topCategories.prefix(3)) { category in
                            CategoryPill(category: category)
                        }
                        Spacer()
                    }
                }
            }

            Spacer()

            // Footer
            HStack {
                if data.inboxZeroStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(data.inboxZeroStreak) day streak")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                Spacer()
                Text("\(data.totalEmailsToday) emails today")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private var timeAgo: String {
        let interval = Date().timeIntervalSince(data.lastUpdated)
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval/60))m ago" }
        return "\(Int(interval/3600))h ago"
    }

    private func formatTimeSaved(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h\(mins)m" : "\(hours)h"
        }
    }
}

// MARK: - Helper Views

struct StatBox: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct LargeStatBox: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CategoryPill: View {
    let category: CategoryCount

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.caption2)
            Text("\(category.count)")
                .font(.caption.bold())
            Text(category.name)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Main Widget View

struct MailSummaryWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: MailSummaryEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: entry.data)
        case .systemMedium:
            MediumWidgetView(data: entry.data)
        case .systemLarge:
            LargeWidgetView(data: entry.data)
        default:
            SmallWidgetView(data: entry.data)
        }
    }
}

// MARK: - Widget Configuration

@main
struct MailSummaryWidget: Widget {
    let kind: String = "MailSummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MailSummaryTimelineProvider()) { entry in
            MailSummaryWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Mail Summary")
        .description("See your email stats at a glance. Track unread emails, high priority items, and time saved.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    MailSummaryWidget()
} timeline: {
    MailSummaryEntry(date: Date(), data: .preview)
}

#Preview("Medium", as: .systemMedium) {
    MailSummaryWidget()
} timeline: {
    MailSummaryEntry(date: Date(), data: .preview)
}

#Preview("Large", as: .systemLarge) {
    MailSummaryWidget()
} timeline: {
    MailSummaryEntry(date: Date(), data: .preview)
}
