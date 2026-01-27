//
//  AnalyticsDashboardView.swift
//  Mail Summary
//
//  Email Analytics - Dashboard UI
//  Created by Jordan Koch on 2026-01-26
//
//  Displays email statistics, trends, and productivity metrics.
//

import SwiftUI
import Charts

struct AnalyticsDashboardView: View {
    @ObservedObject var analyticsManager = AnalyticsManager.shared
    @State private var selectedPeriod: AnalyticsSummary.TimePeriod = .week
    @State private var showingExport = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerView

                // Period Selector
                periodSelectorView

                // Summary Cards
                summaryCardsView

                // Email Volume Chart
                emailVolumeChartView

                // Category Distribution
                categoryDistributionView

                // Top Senders
                topSendersView

                // Export Button
                exportButtonView
            }
            .padding()
        }
        .frame(minWidth: 900, minHeight: 700)
        .background(Color.black)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("📊 Email Analytics")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Last updated: \(formatDate(analyticsManager.analytics.lastUpdated))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button("Reset Analytics") {
                analyticsManager.resetAnalytics()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }

    // MARK: - Period Selector

    private var periodSelectorView: some View {
        Picker("Time Period", selection: $selectedPeriod) {
            Text("Today").tag(AnalyticsSummary.TimePeriod.today)
            Text("Week").tag(AnalyticsSummary.TimePeriod.week)
            Text("Month").tag(AnalyticsSummary.TimePeriod.month)
            Text("Quarter").tag(AnalyticsSummary.TimePeriod.quarter)
            Text("Year").tag(AnalyticsSummary.TimePeriod.year)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Summary Cards

    private var summaryCardsView: some View {
        let summary = analyticsManager.generateSummary(for: selectedPeriod)

        return LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 15) {
            StatCard(title: "Total Emails", value: "\(summary.totalEmails)", icon: "envelope.fill", color: .blue)
            StatCard(title: "Read", value: "\(summary.totalRead)", subtitle: String(format: "%.1f%%", summary.readRate * 100), icon: "envelope.open.fill", color: .green)
            StatCard(title: "Replied", value: "\(summary.totalReplied)", subtitle: String(format: "%.1f%%", summary.replyRate * 100), icon: "arrowshape.turn.up.left.fill", color: .orange)
            StatCard(title: "Deleted", value: "\(summary.totalDeleted)", subtitle: String(format: "%.1f%%", summary.deleteRate * 100), icon: "trash.fill", color: .red)
            StatCard(title: "Avg/Day", value: String(format: "%.1f", summary.avgEmailsPerDay), icon: "chart.line.uptrend.xyaxis", color: .purple)
            StatCard(title: "Top Category", value: summary.topCategory ?? "N/A", icon: "folder.fill", color: .cyan)
            StatCard(title: "Top Sender", value: summary.topSender?.components(separatedBy: "@").first ?? "N/A", icon: "person.fill", color: .indigo)
            StatCard(title: "Archived", value: "\(summary.totalArchived)", icon: "archivebox.fill", color: .teal)
        }
    }

    // MARK: - Email Volume Chart

    private var emailVolumeChartView: some View {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -selectedPeriod.days, to: endDate) ?? endDate
        let dailyStats = analyticsManager.getDailyStats(from: startDate, to: endDate)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Email Volume Over Time")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            if dailyStats.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart(dailyStats, id: \.date) { stat in
                    BarMark(
                        x: .value("Date", stat.date, unit: .day),
                        y: .value("Emails", stat.received)
                    )
                    .foregroundStyle(Color.blue.gradient)
                }
                .frame(height: 250)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(1, selectedPeriod.days / 7))) {
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Category Distribution

    private var categoryDistributionView: some View {
        let trends = analyticsManager.getCategoryTrends(for: selectedPeriod)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Category Distribution")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            if trends.isEmpty {
                emptyChartPlaceholder
            } else {
                if #available(macOS 14.0, *) {
                    Chart(trends) { trend in
                        SectorMark(
                            angle: .value("Count", trend.totalCount),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(by: .value("Category", trend.category))
                        .annotation(position: .overlay) {
                            Text("\(trend.totalCount)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(height: 300)
                    .chartLegend(position: .trailing, alignment: .center)
                } else {
                    Text("Category chart requires macOS 14.0+")
                        .foregroundColor(.gray)
                        .frame(height: 300)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Top Senders

    private var topSendersView: some View {
        let topSenders = analyticsManager.analytics.topSenders(limit: 10)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Top Senders")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            if topSenders.isEmpty {
                Text("No sender data available")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(topSenders.indices, id: \.self) { index in
                        let (email, stats) = topSenders[index]
                        SenderRow(rank: index + 1, email: email, stats: stats)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Export

    private var exportButtonView: some View {
        HStack(spacing: 15) {
            Button(action: exportDailyStats) {
                Label("Export Daily Stats", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)

            Button(action: exportSenderStats) {
                Label("Export Sender Stats", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Helpers

    private var emptyChartPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            Text("No data for selected period")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func exportDailyStats() {
        let csv = analyticsManager.exportToCSV()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "mail-analytics-\(Date().timeIntervalSince1970).csv"
        panel.allowedContentTypes = [.commaSeparatedText]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? csv.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func exportSenderStats() {
        let csv = analyticsManager.exportSenderStatsToCSV()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "sender-stats-\(Date().timeIntervalSince1970).csv"
        panel.allowedContentTypes = [.commaSeparatedText]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? csv.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String?
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)

                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .frame(height: 120)
    }
}

// MARK: - Sender Row

struct SenderRow: View {
    let rank: Int
    let email: String
    let stats: SenderStats

    var body: some View {
        HStack {
            Text("\(rank)")
                .font(.headline)
                .foregroundColor(.gray)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(email.components(separatedBy: "@").first ?? email)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text("@\(email.components(separatedBy: "@").last ?? "")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(stats.totalEmails) emails")
                    .font(.caption)
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    Label(String(format: "%.0f%%", stats.openRate * 100), systemImage: "envelope.open")
                        .font(.caption2)
                        .foregroundColor(.green)

                    Label(String(format: "%.0f%%", stats.replyRate * 100), systemImage: "arrowshape.turn.up.left")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#if DEBUG
struct AnalyticsDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        AnalyticsDashboardView()
    }
}
#endif
