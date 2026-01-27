//
//  InsightsDashboardView.swift
//  Mail Summary
//
//  Email Insights Dashboard UI
//  Created by Jordan Koch on 2026-01-26
//
//  Displays AI-powered insights, trends, recommendations, and predictions.
//

import SwiftUI

struct InsightsDashboardView: View {
    let insights: EmailInsights
    let onApplyRecommendation: (Recommendation) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Daily Digest
                    dailyDigestView

                    // Trends
                    if !insights.trends.isEmpty {
                        trendsView
                    }

                    // Recommendations
                    if !insights.recommendations.isEmpty {
                        recommendationsView
                    }

                    // Predictions
                    if !insights.predictions.isEmpty {
                        predictionsView
                    }
                }
                .padding()
            }
        }
        .frame(width: 800, height: 700)
        .background(Color.black)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("💡 Email Insights")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Generated: \(formatDate(insights.generatedAt))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundColor(.gray)
            .keyboardShortcut(.escape)
        }
        .padding()
    }

    // MARK: - Daily Digest

    private var dailyDigestView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.quote")
                    .foregroundColor(.cyan)
                Text("Daily Digest")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Text(insights.dailyDigest)
                .font(.body)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.cyan.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan, lineWidth: 1)
                )
        }
    }

    // MARK: - Trends

    private var trendsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.purple)
                Text("Trends")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            ForEach(insights.trends) { trend in
                TrendCard(trend: trend)
            }
        }
    }

    // MARK: - Recommendations

    private var recommendationsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Recommendations")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            ForEach(insights.recommendations.sorted { $0.priority > $1.priority }) { recommendation in
                RecommendationCard(
                    recommendation: recommendation,
                    onApply: {
                        onApplyRecommendation(recommendation)
                    }
                )
            }
        }
    }

    // MARK: - Predictions

    private var predictionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "crystal.ball")
                    .foregroundColor(.indigo)
                Text("Predictions")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            ForEach(insights.predictions) { prediction in
                PredictionCard(prediction: prediction)
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Trend Card

struct TrendCard: View {
    let trend: Trend

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: trend.type.icon)
                .font(.title2)
                .foregroundColor(trend.isPositive ? .green : .red)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trend.type.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    if let category = trend.category {
                        Text(category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }

                Text(trend.description)
                    .font(.caption)
                    .foregroundColor(.gray)

                Text("\(String(format: "%.0f", abs(trend.percentageChange)))% \(trend.percentageChange > 0 ? "increase" : "decrease")")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(trend.isPositive ? .green : .orange)
            }

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Recommendation Card

struct RecommendationCard: View {
    let recommendation: Recommendation
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // Priority badge
                Text("\(recommendation.priority)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(priorityColor)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(recommendation.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        if let category = recommendation.category {
                            Text(category)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }

                    Text(recommendation.description)
                        .font(.caption)
                        .foregroundColor(.gray)

                    if let action = recommendation.suggestedAction {
                        HStack {
                            Image(systemName: "arrow.right.circle")
                                .font(.caption)
                            Text(action)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.cyan)
                    }
                }

                Spacer()

                if recommendation.actionable {
                    Button(action: onApply) {
                        Text("Apply")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(priorityColor.opacity(0.5), lineWidth: 2)
        )
    }

    private var priorityColor: Color {
        if recommendation.priority >= 8 { return .red }
        if recommendation.priority >= 5 { return .orange }
        return .blue
    }
}

// MARK: - Prediction Card

struct PredictionCard: View {
    let prediction: Prediction

    var body: some View {
        HStack(spacing: 12) {
            // Confidence indicator
            VStack(spacing: 4) {
                Text(String(format: "%.0f%%", prediction.confidence * 100))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(confidenceColor)

                Text(prediction.confidenceLevel)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(width: 60)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(prediction.prediction)
                        .font(.subheadline)
                        .foregroundColor(.white)

                    if let category = prediction.category {
                        Text(category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }

                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text(prediction.basis)
                        .font(.caption)
                }
                .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private var confidenceColor: Color {
        if prediction.confidence >= 0.8 { return .green }
        if prediction.confidence >= 0.5 { return .yellow }
        return .orange
    }
}

// MARK: - Preview

#if DEBUG
struct InsightsDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleInsights = EmailInsights(
            dailyDigest: "You have 15 unread emails, including 3 high priority. 5 bills need attention this week.",
            trends: [
                Trend(type: .increasing, category: "Work", description: "Work email volume up 40% this week", percentageChange: 40, isPositive: false),
                Trend(type: .decreasing, category: "Marketing", description: "Marketing emails down 25% (good!)", percentageChange: 25, isPositive: true)
            ],
            recommendations: [
                Recommendation(priority: 9, title: "Pay overdue bills", description: "3 bills are overdue totaling $450", actionable: true, suggestedAction: "Review bills", category: "Bills"),
                Recommendation(priority: 6, title: "Clear old marketing", description: "25 marketing emails older than 7 days", actionable: true, suggestedAction: "Bulk delete", category: "Marketing")
            ],
            predictions: [
                Prediction(prediction: "You'll receive 15-20 work emails tomorrow", confidence: 0.75, basis: "Historical weekday average", category: "Work")
            ]
        )

        InsightsDashboardView(insights: sampleInsights, onApplyRecommendation: { _ in }, onClose: {})
    }
}
#endif
