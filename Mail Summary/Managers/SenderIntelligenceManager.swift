//
//  SenderIntelligenceManager.swift
//  Mail Summary
//
//  Sender Intelligence & VIP Detection
//  Created by Jordan Koch on 2026-01-26
//
//  Tracks sender behavior patterns, auto-detects VIPs, and analyzes sender reputation.
//

import Foundation

@MainActor
class SenderIntelligenceManager: ObservableObject {
    static let shared = SenderIntelligenceManager()

    // MARK: - Published Properties

    @Published var vipSenders: Set<String> = []  // VIP email addresses
    @Published var blockedSenders: Set<String> = []  // Blocked email addresses
    @Published var senderCategories: [String: SenderCategory] = [:]  // Email -> Category
    @Published var senderReputations: [String: Double] = [:]  // Email -> Reputation (0-1)

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private let vipKey = "MailSummary_VIPSenders"
    private let blockedKey = "MailSummary_BlockedSenders"
    private let categoriesKey = "MailSummary_SenderCategories"

    // VIP auto-detection thresholds
    private let vipReplyRateThreshold = 0.8  // 80% reply rate
    private let vipOpenRateThreshold = 0.9   // 90% open rate
    private let minEmailsForVIP = 5           // Need at least 5 emails

    // MARK: - Sender Category

    enum SenderCategory: String, Codable {
        case trusted    // Always important
        case vip        // Boss, family, key contacts
        case regular    // Normal senders
        case lowPriority // Newsletters, marketing
        case suspicious  // Potential spam

        var displayName: String {
            rawValue.capitalized
        }

        var icon: String {
            switch self {
            case .trusted: return "checkmark.seal.fill"
            case .vip: return "star.fill"
            case .regular: return "person.fill"
            case .lowPriority: return "tray.fill"
            case .suspicious: return "exclamationmark.triangle.fill"
            }
        }

        var color: String {
            switch self {
            case .trusted: return "green"
            case .vip: return "yellow"
            case .regular: return "blue"
            case .lowPriority: return "gray"
            case .suspicious: return "red"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        loadVIPs()
        loadBlocked()
        loadCategories()
    }

    // MARK: - VIP Management

    /// Add sender as VIP
    func addVIP(_ senderEmail: String) {
        vipSenders.insert(senderEmail.lowercased())
        senderCategories[senderEmail.lowercased()] = .vip
        saveVIPs()
        print("⭐ Added VIP: \(senderEmail)")
    }

    /// Remove sender from VIP
    func removeVIP(_ senderEmail: String) {
        vipSenders.remove(senderEmail.lowercased())
        senderCategories[senderEmail.lowercased()] = .regular
        saveVIPs()
        print("⭐ Removed VIP: \(senderEmail)")
    }

    /// Check if sender is VIP
    func isVIP(_ senderEmail: String) -> Bool {
        vipSenders.contains(senderEmail.lowercased())
    }

    /// Block sender
    func blockSender(_ senderEmail: String) {
        blockedSenders.insert(senderEmail.lowercased())
        senderCategories[senderEmail.lowercased()] = .suspicious
        saveBlocked()
        print("🚫 Blocked sender: \(senderEmail)")
    }

    /// Unblock sender
    func unblockSender(_ senderEmail: String) {
        blockedSenders.remove(senderEmail.lowercased())
        senderCategories[senderEmail.lowercased()] = .regular
        saveBlocked()
        print("✅ Unblocked sender: \(senderEmail)")
    }

    /// Check if sender is blocked
    func isBlocked(_ senderEmail: String) -> Bool {
        blockedSenders.contains(senderEmail.lowercased())
    }

    // MARK: - Auto-Detection

    /// Auto-detect VIP senders based on user behavior
    func autoDetectVIPs(from emails: [Email]) {
        // Group emails by sender
        let senderEmails = Dictionary(grouping: emails) { $0.senderEmail.lowercased() }

        for (senderEmail, emailList) in senderEmails {
            // Skip if already VIP or not enough emails
            if isVIP(senderEmail) || emailList.count < minEmailsForVIP {
                continue
            }

            // Calculate stats
            let totalEmails = emailList.count
            let openedEmails = emailList.filter { $0.isRead }.count
            let openRate = Double(openedEmails) / Double(totalEmails)

            // TODO: Calculate reply rate when reply tracking is implemented
            let replyRate = 0.0  // Placeholder

            // Check if meets VIP criteria
            if replyRate >= vipReplyRateThreshold || openRate >= vipOpenRateThreshold {
                addVIP(senderEmail)
                print("🌟 Auto-detected VIP: \(senderEmail) (open: \(Int(openRate*100))%, reply: \(Int(replyRate*100))%)")
            }
        }
    }

    /// Auto-categorize sender based on email patterns
    func autoCategorizeSender(_ senderEmail: String, emails: [Email]) -> SenderCategory {
        // If manually set, use that
        if let manualCategory = senderCategories[senderEmail.lowercased()] {
            return manualCategory
        }

        // Auto-detect based on patterns
        let senderEmails = emails.filter { $0.senderEmail.lowercased() == senderEmail.lowercased() }
        guard !senderEmails.isEmpty else { return .regular }

        // Check if mostly marketing/newsletters
        let marketingCount = senderEmails.filter { $0.category == .marketing || $0.category == .newsletters }.count
        if Double(marketingCount) / Double(senderEmails.count) > 0.7 {
            return .lowPriority
        }

        // Check if mostly spam
        let spamCount = senderEmails.filter { $0.category == .spam }.count
        if Double(spamCount) / Double(senderEmails.count) > 0.5 {
            return .suspicious
        }

        // Check if high engagement
        let openCount = senderEmails.filter { $0.isRead }.count
        let openRate = Double(openCount) / Double(senderEmails.count)

        if openRate > 0.8 {
            return .trusted
        }

        return .regular
    }

    /// Calculate sender reputation score (0-1)
    func calculateReputation(for senderEmail: String, emails: [Email]) -> Double {
        let senderEmails = emails.filter { $0.senderEmail.lowercased() == senderEmail.lowercased() }
        guard !senderEmails.isEmpty else { return 0.5 }

        var score = 0.5  // Neutral start

        // Factor 1: Open rate (+0.3 max)
        let openCount = senderEmails.filter { $0.isRead }.count
        let openRate = Double(openCount) / Double(senderEmails.count)
        score += openRate * 0.3

        // Factor 2: Not spam/marketing (-0.2)
        let lowValueCount = senderEmails.filter { $0.category == .spam || $0.category == .marketing }.count
        let lowValueRate = Double(lowValueCount) / Double(senderEmails.count)
        score -= lowValueRate * 0.2

        // Factor 3: Manual VIP (+0.3)
        if isVIP(senderEmail) {
            score += 0.3
        }

        // Factor 4: Blocked (-0.8, essentially 0)
        if isBlocked(senderEmail) {
            score -= 0.8
        }

        return min(max(score, 0.0), 1.0)  // Clamp to 0-1
    }

    /// Get sender category (auto-detect if not set)
    func getSenderCategory(_ senderEmail: String, emails: [Email]) -> SenderCategory {
        // Check if VIP
        if isVIP(senderEmail) {
            return .vip
        }

        // Check if blocked
        if isBlocked(senderEmail) {
            return .suspicious
        }

        // Check if manually categorized
        if let category = senderCategories[senderEmail.lowercased()] {
            return category
        }

        // Auto-detect
        return autoCategorizeSender(senderEmail, emails: emails)
    }

    // MARK: - Persistence

    private func saveVIPs() {
        let array = Array(vipSenders)
        userDefaults.set(array, forKey: vipKey)
    }

    private func loadVIPs() {
        if let array = userDefaults.array(forKey: vipKey) as? [String] {
            vipSenders = Set(array)
        }
    }

    private func saveBlocked() {
        let array = Array(blockedSenders)
        userDefaults.set(array, forKey: blockedKey)
    }

    private func loadBlocked() {
        if let array = userDefaults.array(forKey: blockedKey) as? [String] {
            blockedSenders = Set(array)
        }
    }

    private func saveCategories() {
        let dict = senderCategories.mapValues { $0.rawValue }
        userDefaults.set(dict, forKey: categoriesKey)
    }

    private func loadCategories() {
        if let dict = userDefaults.dictionary(forKey: categoriesKey) as? [String: String] {
            senderCategories = dict.compactMapValues { SenderCategory(rawValue: $0) }
        }
    }
}
