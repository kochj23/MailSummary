//
//  SenderIntelligenceView.swift
//  Mail Summary
//
//  Sender Intelligence & VIP Management UI
//  Created by Jordan Koch on 2026-01-26
//
//  Displays sender statistics, VIP management, and reputation tracking.
//

import SwiftUI

struct SenderIntelligenceView: View {
    @ObservedObject var senderIntel = SenderIntelligenceManager.shared
    @ObservedObject var analyticsManager = AnalyticsManager.shared
    @ObservedObject var mailEngine: MailEngine

    @State private var sortBy: SortOption = .volume
    @State private var filterBy: FilterOption = .all
    @State private var searchQuery: String = ""
    @State private var selectedSender: String?

    @Environment(\.dismiss) var dismiss

    enum SortOption: String, CaseIterable {
        case volume = "Volume"
        case openRate = "Open Rate"
        case replyRate = "Reply Rate"
        case recent = "Most Recent"

        var icon: String {
            switch self {
            case .volume: return "envelope.fill"
            case .openRate: return "envelope.open.fill"
            case .replyRate: return "arrowshape.turn.up.left.fill"
            case .recent: return "clock.fill"
            }
        }
    }

    enum FilterOption: String, CaseIterable {
        case all = "All Senders"
        case vips = "VIPs Only"
        case trusted = "Trusted"
        case suspicious = "Suspicious"

        var icon: String {
            switch self {
            case .all: return "person.3.fill"
            case .vips: return "star.fill"
            case .trusted: return "checkmark.seal.fill"
            case .suspicious: return "exclamationmark.triangle.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Controls
            controlsView

            Divider()

            // Sender List
            senderListView
        }
        .frame(width: 900, height: 700)
        .background(Color.black)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("👤 Sender Intelligence")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("\(analyticsManager.analytics.senderStats.count) unique senders")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button("Auto-Detect VIPs") {
                senderIntel.autoDetectVIPs(from: mailEngine.emails)
            }
            .buttonStyle(.bordered)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundColor(.gray)
            .keyboardShortcut(.escape)
        }
        .padding()
    }

    // MARK: - Controls

    private var controlsView: some View {
        HStack(spacing: 15) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search senders...", text: $searchQuery)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .frame(width: 250)

            // Sort
            Picker("Sort by", selection: $sortBy) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    HStack {
                        Image(systemName: option.icon)
                        Text(option.rawValue)
                    }
                    .tag(option)
                }
            }
            .pickerStyle(.menu)

            // Filter
            Picker("Filter", selection: $filterBy) {
                ForEach(FilterOption.allCases, id: \.self) { option in
                    HStack {
                        Image(systemName: option.icon)
                        Text(option.rawValue)
                    }
                    .tag(option)
                }
            }
            .pickerStyle(.segmented)

            Spacer()
        }
        .padding()
    }

    // MARK: - Sender List

    private var senderListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredAndSortedSenders(), id: \.email) { sender in
                    SenderCard(
                        email: sender.email,
                        stats: sender.stats,
                        category: senderIntel.getSenderCategory(sender.email, emails: mailEngine.emails),
                        reputation: senderIntel.calculateReputation(for: sender.email, emails: mailEngine.emails),
                        isVIP: senderIntel.isVIP(sender.email),
                        isBlocked: senderIntel.isBlocked(sender.email),
                        onToggleVIP: {
                            if senderIntel.isVIP(sender.email) {
                                senderIntel.removeVIP(sender.email)
                            } else {
                                senderIntel.addVIP(sender.email)
                            }
                        },
                        onToggleBlock: {
                            if senderIntel.isBlocked(sender.email) {
                                senderIntel.unblockSender(sender.email)
                            } else {
                                senderIntel.blockSender(sender.email)
                            }
                        },
                        onViewHistory: {
                            selectedSender = sender.email
                        }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Filtering & Sorting

    private func filteredAndSortedSenders() -> [(email: String, stats: SenderStats)] {
        var senders = analyticsManager.analytics.senderStats.map { (email: $0.key, stats: $0.value) }

        // Filter by search query
        if !searchQuery.isEmpty {
            senders = senders.filter { $0.email.localizedCaseInsensitiveContains(searchQuery) }
        }

        // Filter by category
        switch filterBy {
        case .all:
            break
        case .vips:
            senders = senders.filter { senderIntel.isVIP($0.email) }
        case .trusted:
            senders = senders.filter {
                let category = senderIntel.getSenderCategory($0.email, emails: mailEngine.emails)
                return category == .trusted || category == .vip
            }
        case .suspicious:
            senders = senders.filter { senderIntel.isBlocked($0.email) }
        }

        // Sort
        switch sortBy {
        case .volume:
            senders.sort(by: { $0.stats.totalEmails > $1.stats.totalEmails })
        case .openRate:
            senders.sort(by: { $0.stats.openRate > $1.stats.openRate })
        case .replyRate:
            senders.sort(by: { $0.stats.replyRate > $1.stats.replyRate })
        case .recent:
            senders.sort { ($0.stats.lastEmailDate ?? Date.distantPast) > ($1.stats.lastEmailDate ?? Date.distantPast) }
        }

        return senders
    }
}

// MARK: - Sender Card

struct SenderCard: View {
    let email: String
    let stats: SenderStats
    let category: SenderIntelligenceManager.SenderCategory
    let reputation: Double
    let isVIP: Bool
    let isBlocked: Bool
    let onToggleVIP: () -> Void
    let onToggleBlock: () -> Void
    let onViewHistory: () -> Void

    var body: some View {
        HStack(spacing: 15) {
            // Category Icon
            Image(systemName: category.icon)
                .font(.title2)
                .foregroundColor(categoryColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 6) {
                // Email address
                Text(email.components(separatedBy: "@").first ?? email)
                    .font(.headline)
                    .foregroundColor(.white)

                Text("@\(email.components(separatedBy: "@").last ?? "")")
                    .font(.caption)
                    .foregroundColor(.gray)

                // Stats
                HStack(spacing: 15) {
                    Label("\(stats.totalEmails)", systemImage: "envelope.fill")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Label(String(format: "%.0f%%", stats.openRate * 100), systemImage: "envelope.open")
                        .font(.caption)
                        .foregroundColor(.green)

                    Label(String(format: "%.0f%%", stats.replyRate * 100), systemImage: "arrowshape.turn.up.left")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                // Reputation bar
                HStack(spacing: 8) {
                    Text("Reputation:")
                        .font(.caption2)
                        .foregroundColor(.gray)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(reputationColor.gradient)
                                .frame(width: geometry.size.width * reputation, height: 8)
                        }
                    }
                    .frame(height: 8)

                    Text(String(format: "%.0f%%", reputation * 100))
                        .font(.caption2)
                        .foregroundColor(reputationColor)
                        .frame(width: 40, alignment: .trailing)
                }
            }

            Spacer()

            // Actions
            VStack(spacing: 8) {
                Button(action: onToggleVIP) {
                    Image(systemName: isVIP ? "star.fill" : "star")
                        .foregroundColor(isVIP ? .yellow : .gray)
                }
                .buttonStyle(.plain)
                .help(isVIP ? "Remove from VIPs" : "Add to VIPs")

                Button(action: onToggleBlock) {
                    Image(systemName: isBlocked ? "checkmark.circle" : "xmark.circle")
                        .foregroundColor(isBlocked ? .green : .red)
                }
                .buttonStyle(.plain)
                .help(isBlocked ? "Unblock" : "Block sender")

                Button(action: onViewHistory) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
                .help("View history")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isVIP ? Color.yellow : (isBlocked ? Color.red : Color.clear), lineWidth: 2)
        )
    }

    private var categoryColor: Color {
        switch category {
        case .trusted: return .green
        case .vip: return .yellow
        case .regular: return .blue
        case .lowPriority: return .gray
        case .suspicious: return .red
        }
    }

    private var reputationColor: Color {
        if reputation >= 0.8 { return .green }
        if reputation >= 0.5 { return .yellow }
        return .red
    }
}

// MARK: - Preview

#if DEBUG
struct SenderIntelligenceView_Previews: PreviewProvider {
    static var previews: some View {
        SenderIntelligenceView(mailEngine: MailEngine())
    }
}
#endif
