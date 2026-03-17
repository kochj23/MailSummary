//
//  MailEngine.swift
//  Mail Summary
//
//  Core email management and AI orchestration
//  Created by Jordan Koch on 2026-01-22
//

import Foundation
import Combine
import AppKit
import UserNotifications

@MainActor
class MailEngine: ObservableObject {
    @Published var emails: [Email] = [] {
        didSet {
            rebuildEmailCache()
        }
    }
    @Published var categories: [CategorySummary] = []
    @Published var stats: MailboxStats = MailboxStats(totalEmails: 0, unreadEmails: 0, todayEmails: 0, highPriorityEmails: 0, actionsCount: 0)
    @Published var aiSummary: String = ""
    @Published var isScanning: Bool = false
    @Published var isCategorizingWithAI: Bool = false
    @Published var aiProgress: String = ""

    // NEW: Search & Filter
    @Published var searchManager = SearchFilterManager()
    @Published var isSearching = false

    // NEW: Snooze & Reminders
    @Published var snoozedEmails: [Email] = []
    @Published var activeReminders: [EmailReminder] = []

    // NEW: Action feedback
    @Published var lastActionResult: (String, Bool)? = nil  // (message, isSuccess)

    // FEATURE 5: Background Auto-Scan
    @Published var autoScanEnabled: Bool = false
    @Published var autoScanInterval: TimeInterval = 300  // 5 minutes default
    @Published var notifyHighPriority: Bool = true
    @Published var lastScanTime: Date?

    // PERFORMANCE: Email lookup cache - O(1) instead of O(n) for ID lookups
    private var emailsByID: [Int: Email] = [:]
    private var emailIndexByID: [Int: Int] = [:]

    // PERFORMANCE: Parallel processing configuration (reduced from 20 to 8 to avoid overwhelming AI backend)
    private let aiParallelBatchSize = 8  // Process 8 emails concurrently
    private let aiBatchDelayMs: UInt64 = 50_000_000  // 50ms delay between batches

    private let parser = MailParser()
    private let categorizer = AICategorizationEngine()
    private let actionManager = EmailActionManager.shared
    private let snoozeManager = SnoozeReminderManager.shared
    private let rulesEngine = RulesEngine.shared
    private var cancellables = Set<AnyCancellable>()
    private var snoozeCheckTimer: Timer?
    private var autoScanTimer: Timer?

    init() {
        loadSettings()
        loadEmails()

        // Check for expired snoozes every minute
        snoozeCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkExpiredSnoozes()
            }
        }

        // Start auto-scan if enabled
        if autoScanEnabled {
            startAutoScan()
        }
    }

    // MARK: - Email Cache Management (PERFORMANCE OPTIMIZATION)

    /// Rebuild email lookup cache - called automatically when emails array changes
    private func rebuildEmailCache() {
        emailsByID.removeAll(keepingCapacity: true)
        emailIndexByID.removeAll(keepingCapacity: true)

        for (index, email) in emails.enumerated() {
            emailsByID[email.id] = email
            emailIndexByID[email.id] = index
        }
    }

    /// O(1) email lookup by ID
    func email(byID id: Int) -> Email? {
        return emailsByID[id]
    }

    /// O(1) email index lookup by ID
    func emailIndex(byID id: Int) -> Int? {
        return emailIndexByID[id]
    }

    /// O(1) check if email exists
    func emailExists(_ id: Int) -> Bool {
        return emailsByID[id] != nil
    }

    deinit {
        // Cleanup timers (async calls not allowed in deinit)
        autoScanTimer?.invalidate()
        snoozeCheckTimer?.invalidate()
    }

    func loadEmails() {
        isScanning = true

        Task {
            var parsed = await parser.parseEmails(limit: 500)  // Now async with timeout

            await MainActor.run {
                self.isCategorizingWithAI = true
                self.aiProgress = "Categorizing \(parsed.count) emails with AI (parallel)..."
            }

            // Categorize emails with AI in PARALLEL BATCHES (10x-20x faster)
            let totalBatches = (parsed.count + aiParallelBatchSize - 1) / aiParallelBatchSize

            for batchIndex in 0..<totalBatches {
                let start = batchIndex * aiParallelBatchSize
                let end = min(start + aiParallelBatchSize, parsed.count)
                let batchIndices = Array(start..<end)

                // Process this batch in parallel
                await withTaskGroup(of: (Int, Email.EmailCategory, Int).self) { group in
                    for index in batchIndices {
                        group.addTask {
                            let category = await self.categorizer.categorizeEmail(parsed[index])
                            let priority = await self.categorizer.scoreEmailPriority(parsed[index])
                            return (index, category, priority)
                        }
                    }

                    // Collect results
                    for await (index, category, priority) in group {
                        parsed[index].category = category
                        parsed[index].priority = priority
                    }
                }

                // Update progress after each batch
                await MainActor.run {
                    self.aiProgress = "Categorized \(end)/\(parsed.count) emails... (\(aiParallelBatchSize) at a time)"
                }

                // Small delay between batches to avoid overwhelming AI backend
                if batchIndex < totalBatches - 1 {
                    try? await Task.sleep(nanoseconds: aiBatchDelayMs)
                }
            }

            // Apply Rules Engine after AI categorization
            await MainActor.run {
                self.aiProgress = "Applying email rules..."
            }
            parsed = await rulesEngine.applyRules(to: parsed)

            await MainActor.run {
                self.emails = parsed
                self.updateCategories()
                self.updateStats()
                self.isScanning = false
                self.isCategorizingWithAI = false
                self.aiProgress = ""
            }

            // AI summary
            await generateAISummary()
        }
    }

    func scan() {
        loadEmails()
    }

    private func updateCategories() {
        let grouped = Dictionary(grouping: emails) { $0.category ?? .other }

        categories = Email.EmailCategory.allCases.compactMap { category in
            guard let categoryEmails = grouped[category], !categoryEmails.isEmpty else { return nil }

            return CategorySummary(
                category: category,
                count: categoryEmails.count,
                unreadCount: categoryEmails.filter { !$0.isRead }.count,
                highPriorityCount: categoryEmails.filter { ($0.priority ?? 0) >= 7 }.count,
                aiSummary: nil
            )
        }.sorted { $0.count > $1.count }
    }

    private func updateStats() {
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)

        stats = MailboxStats(
            totalEmails: emails.count,
            unreadEmails: emails.filter { !$0.isRead }.count,
            todayEmails: emails.filter { $0.dateReceived >= startOfToday }.count,
            highPriorityEmails: emails.filter { ($0.priority ?? 0) >= 7 }.count,
            actionsCount: emails.reduce(0) { $0 + $1.actions.count }
        )
    }

    private func generateAISummary() async {
        let summary = await categorizer.generateOverallSummary(emails: emails, stats: stats)

        await MainActor.run {
            self.aiSummary = summary
        }
    }

    /// Load email body on-demand - OPTIMIZED with O(1) lookup
    func loadEmailBody(emailID: Int) async {
        guard let index = emailIndexByID[emailID] else { return }

        // Already loaded or loading
        if emails[index].body != nil || emails[index].isLoadingBody {
            return
        }

        // Mark as loading
        await MainActor.run {
            self.emails[index].isLoadingBody = true
        }

        // Load body
        let messageId = emails[index].messageId
        if let body = await parser.loadEmailBody(messageId: messageId) {
            await MainActor.run {
                // Re-check index in case array changed
                if let idx = self.emailIndexByID[emailID] {
                    self.emails[idx].body = body
                    self.emails[idx].isLoadingBody = false
                }
            }
        } else {
            await MainActor.run {
                if let idx = self.emailIndexByID[emailID] {
                    self.emails[idx].body = "[Unable to load email body]"
                    self.emails[idx].isLoadingBody = false
                }
            }
        }
    }

    // MARK: - Email Actions

    /// Perform an action on an email (delete, archive, reply, etc.)
    func performEmailAction(_ action: EmailActionType, on email: Email) async {
        let result = await actionManager.performAction(action, on: email)

        await MainActor.run {
            switch result {
            case .success:
                lastActionResult = ("✅ \(action.displayName) completed", true)

                // Update UI state based on action - OPTIMIZED with O(1) lookup
                switch action {
                case .delete, .archive:
                    deleteEmail(emailID: email.id)

                case .markRead:
                    if let index = emailIndexByID[email.id] {
                        emails[index].isRead = true
                    }
                    updateStats()

                case .markUnread:
                    if let index = emailIndexByID[email.id] {
                        emails[index].isRead = false
                    }
                    updateStats()

                case .toggleRead:
                    if let index = emailIndexByID[email.id] {
                        emails[index].isRead.toggle()
                    }
                    updateStats()

                case .reply, .forward:
                    // Mail.app draft window opened, no UI update needed
                    break

                case .move:
                    // Email moved, remove from list
                    deleteEmail(emailID: email.id)
                }

            case .failure(let error):
                lastActionResult = ("❌ \(error)", false)

            case .notSupported:
                lastActionResult = ("⚠️ Action not supported", false)
            }

            // Clear toast after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    self.lastActionResult = nil
                }
            }
        }
    }

    // MARK: - Snooze & Reminders

    /// Mark email as snoozed - OPTIMIZED with O(1) lookup
    func markEmailAsSnoozed(emailId: Int, until: Date) {
        if let index = emailIndexByID[emailId] {
            emails[index].isSnoozed = true
            emails[index].snoozeUntil = until
        }
        updateSnoozedList()
    }

    /// Unsnooze an email - OPTIMIZED with O(1) lookup
    func unsnoozeEmail(emailId: Int) {
        if let index = emailIndexByID[emailId] {
            emails[index].isSnoozed = false
            emails[index].snoozeUntil = nil
        }
        updateSnoozedList()
    }

    /// Mark email as having a reminder - OPTIMIZED with O(1) lookup
    func markEmailAsHasReminder(emailId: Int, remindAt: Date) {
        if let index = emailIndexByID[emailId] {
            emails[index].hasReminder = true
            emails[index].reminderDate = remindAt
        }
        updateActiveReminders()
    }

    /// Check for expired snoozes - uses messageId lookup (still O(n) but rare)
    private func checkExpiredSnoozes() {
        let expired = snoozeManager.getExpiredSnoozed()

        for snoozed in expired {
            // Find email by messageId and unsnooze (can't use cache as we need messageId lookup)
            if let index = emails.firstIndex(where: { $0.messageId == snoozed.messageId }) {
                emails[index].isSnoozed = false
                emails[index].snoozeUntil = nil
            }

            snoozeManager.unsnooze(emailId: snoozed.emailId)
        }

        if !expired.isEmpty {
            updateSnoozedList()
            lastActionResult = ("📧 \(expired.count) snoozed email\(expired.count == 1 ? "" : "s") ready", true)

            // Clear message after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    self.lastActionResult = nil
                }
            }
        }

        updateActiveReminders()
    }

    /// Update snoozed emails list
    private func updateSnoozedList() {
        snoozedEmails = emails.filter { $0.isSnoozed }
    }

    /// Update active reminders list
    private func updateActiveReminders() {
        activeReminders = snoozeManager.getActiveReminders()
    }

    func markAsRead(emailID: Int) {
        if let index = emailIndexByID[emailID] {
            emails[index].isRead = true
            updateStats()
        }
    }

    func deleteEmail(emailID: Int) {
        emails.removeAll { $0.id == emailID }
        updateCategories()
        updateStats()
    }

    func bulkDelete(category: Email.EmailCategory) {
        emails.removeAll { $0.category == category }
        updateCategories()
        updateStats()
    }

    // MARK: - Bulk Operations

    /// Bulk delete multiple emails - OPTIMIZED with O(1) lookups
    func bulkDelete(emailIDs: [Int]) async -> (success: Int, failed: Int) {
        var successCount = 0
        var failedCount = 0

        // Pre-fetch emails using O(1) dictionary lookup
        let emailIDSet = Set(emailIDs)
        let emailsToProcess = emailIDs.compactMap { emailsByID[$0] }

        // Process in batches of 20 for better performance
        let batchSize = 20
        let batches = stride(from: 0, to: emailsToProcess.count, by: batchSize).map {
            Array(emailsToProcess[$0..<min($0 + batchSize, emailsToProcess.count)])
        }

        for batch in batches {
            await withTaskGroup(of: Bool.self) { group in
                for email in batch {
                    group.addTask {
                        let result = await self.actionManager.performAction(.delete, on: email)
                        return result.isSuccess
                    }
                }

                for await success in group {
                    if success {
                        successCount += 1
                    } else {
                        failedCount += 1
                    }
                }
            }
        }

        // Remove from local list using Set for O(1) contains check
        await MainActor.run {
            emails.removeAll { emailIDSet.contains($0.id) }
            updateCategories()
            updateStats()
            lastActionResult = ("🗑 Deleted \(successCount) emails", true)
        }

        return (successCount, failedCount)
    }

    /// Bulk archive multiple emails - OPTIMIZED with O(1) lookups
    func bulkArchive(emailIDs: [Int]) async -> (success: Int, failed: Int) {
        var successCount = 0
        var failedCount = 0

        // Pre-fetch emails using O(1) dictionary lookup
        let emailIDSet = Set(emailIDs)
        let emailsToProcess = emailIDs.compactMap { emailsByID[$0] }

        let batchSize = 20
        let batches = stride(from: 0, to: emailsToProcess.count, by: batchSize).map {
            Array(emailsToProcess[$0..<min($0 + batchSize, emailsToProcess.count)])
        }

        for batch in batches {
            await withTaskGroup(of: Bool.self) { group in
                for email in batch {
                    group.addTask {
                        let result = await self.actionManager.performAction(.archive, on: email)
                        return result.isSuccess
                    }
                }

                for await success in group {
                    if success {
                        successCount += 1
                    } else {
                        failedCount += 1
                    }
                }
            }
        }

        // Remove from local list using Set for O(1) contains check
        await MainActor.run {
            emails.removeAll { emailIDSet.contains($0.id) }
            updateCategories()
            updateStats()
            lastActionResult = ("📦 Archived \(successCount) emails", true)
        }

        return (successCount, failedCount)
    }

    /// Bulk mark emails as read - OPTIMIZED with O(1) lookups
    func bulkMarkRead(emailIDs: [Int]) async -> (success: Int, failed: Int) {
        var successCount = 0
        var failedCount = 0

        // Pre-fetch emails using O(1) dictionary lookup
        let emailsToProcess = emailIDs.compactMap { emailsByID[$0] }

        let batchSize = 20
        let batches = stride(from: 0, to: emailsToProcess.count, by: batchSize).map {
            Array(emailsToProcess[$0..<min($0 + batchSize, emailsToProcess.count)])
        }

        for batch in batches {
            await withTaskGroup(of: Bool.self) { group in
                for email in batch {
                    group.addTask {
                        let result = await self.actionManager.performAction(.markRead, on: email)
                        return result.isSuccess
                    }
                }

                for await success in group {
                    if success {
                        successCount += 1
                    } else {
                        failedCount += 1
                    }
                }
            }
        }

        // Update local state using O(1) index lookup
        await MainActor.run {
            for emailID in emailIDs {
                if let index = emailIndexByID[emailID] {
                    emails[index].isRead = true
                }
            }
            updateStats()
            lastActionResult = ("✅ Marked \(successCount) emails as read", true)
        }

        return (successCount, failedCount)
    }

    /// Bulk mark emails as unread - OPTIMIZED with O(1) lookups
    func bulkMarkUnread(emailIDs: [Int]) async -> (success: Int, failed: Int) {
        var successCount = 0
        var failedCount = 0

        // Pre-fetch emails using O(1) dictionary lookup
        let emailsToProcess = emailIDs.compactMap { emailsByID[$0] }

        let batchSize = 20
        let batches = stride(from: 0, to: emailsToProcess.count, by: batchSize).map {
            Array(emailsToProcess[$0..<min($0 + batchSize, emailsToProcess.count)])
        }

        for batch in batches {
            await withTaskGroup(of: Bool.self) { group in
                for email in batch {
                    group.addTask {
                        let result = await self.actionManager.performAction(.markUnread, on: email)
                        return result.isSuccess
                    }
                }

                for await success in group {
                    if success {
                        successCount += 1
                    } else {
                        failedCount += 1
                    }
                }
            }
        }

        // Update local state using O(1) index lookup
        await MainActor.run {
            for emailID in emailIDs {
                if let index = emailIndexByID[emailID] {
                    emails[index].isRead = false
                }
            }
            updateStats()
            lastActionResult = ("📭 Marked \(successCount) emails as unread", true)
        }

        return (successCount, failedCount)
    }

    /// Bulk move emails to a mailbox - OPTIMIZED with O(1) lookups
    func bulkMove(emailIDs: [Int], to mailbox: String) async -> (success: Int, failed: Int) {
        var successCount = 0
        var failedCount = 0

        // Pre-fetch emails using O(1) dictionary lookup
        let emailIDSet = Set(emailIDs)
        let emailsToProcess = emailIDs.compactMap { emailsByID[$0] }

        let batchSize = 20
        let batches = stride(from: 0, to: emailsToProcess.count, by: batchSize).map {
            Array(emailsToProcess[$0..<min($0 + batchSize, emailsToProcess.count)])
        }

        for batch in batches {
            await withTaskGroup(of: Bool.self) { group in
                for email in batch {
                    group.addTask {
                        let result = await self.actionManager.performAction(.move(mailbox: mailbox), on: email)
                        return result.isSuccess
                    }
                }

                for await success in group {
                    if success {
                        successCount += 1
                    } else {
                        failedCount += 1
                    }
                }
            }
        }

        // Remove from local list using Set for O(1) contains check
        await MainActor.run {
            emails.removeAll { emailIDSet.contains($0.id) }
            updateCategories()
            updateStats()
            lastActionResult = ("📁 Moved \(successCount) emails to \(mailbox)", true)
        }

        return (successCount, failedCount)
    }

    // MARK: - Background Auto-Scan (Feature 5)

    /// Start automatic background scanning
    func startAutoScan() {
        stopAutoScan()  // Clear any existing timer

        guard autoScanEnabled else { return }

        autoScanTimer = Timer.scheduledTimer(withTimeInterval: autoScanInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.autoScanIfNeeded()
            }
        }

        #if DEBUG
        print("✅ Auto-scan started: every \(Int(autoScanInterval/60)) minutes")
        #endif
    }

    /// Stop automatic scanning
    func stopAutoScan() {
        autoScanTimer?.invalidate()
        autoScanTimer = nil
        #if DEBUG
        print("🛑 Auto-scan stopped")
        #endif
    }

    /// Perform auto-scan if conditions are met
    private func autoScanIfNeeded() async {
        // Rate limiting: Don't scan more than once per minute
        if let lastScan = lastScanTime,
           Date().timeIntervalSince(lastScan) < 60 {
            #if DEBUG
            print("⏱️ Auto-scan skipped: Too soon since last scan")
            #endif
            return
        }

        // Check if Mail.app is running
        let isMailRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.apple.mail"
        }

        guard isMailRunning else {
            #if DEBUG
            print("⚠️ Auto-scan skipped: Mail.app not running")
            #endif
            return
        }

        #if DEBUG
        print("🔄 Auto-scan triggered")
        #endif
        lastScanTime = Date()
        saveSettings()

        // Perform scan
        let previousHighPriorityCount = stats.highPriorityEmails
        loadEmails()

        // Check for new high-priority emails after scan completes
        if notifyHighPriority {
            // Wait for scan to complete
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

            let newHighPriorityCount = stats.highPriorityEmails
            if newHighPriorityCount > previousHighPriorityCount {
                let newCount = newHighPriorityCount - previousHighPriorityCount
                await showHighPriorityNotification(count: newCount)
            }
        }
    }

    /// Show notification for new high-priority emails
    private func showHighPriorityNotification(count: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "📧 High Priority Emails"
        content.body = "You have \(count) new high-priority email\(count == 1 ? "" : "s")"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Immediate delivery
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Toggle auto-scan on/off
    func toggleAutoScan() {
        autoScanEnabled.toggle()
        saveSettings()

        if autoScanEnabled {
            startAutoScan()
        } else {
            stopAutoScan()
        }
    }

    /// Update auto-scan interval
    func setAutoScanInterval(_ interval: TimeInterval) {
        autoScanInterval = interval
        saveSettings()

        if autoScanEnabled {
            startAutoScan()  // Restart with new interval
        }
    }

    // MARK: - Settings Persistence

    private func loadSettings() {
        let defaults = UserDefaults.standard
        autoScanEnabled = defaults.bool(forKey: "MailEngine_AutoScanEnabled")
        autoScanInterval = defaults.double(forKey: "MailEngine_AutoScanInterval")
        if autoScanInterval == 0 {
            autoScanInterval = 300  // Default to 5 minutes
        }
        notifyHighPriority = defaults.bool(forKey: "MailEngine_NotifyHighPriority")
        if let lastScan = defaults.object(forKey: "MailEngine_LastScanTime") as? Date {
            lastScanTime = lastScan
        }
    }

    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(autoScanEnabled, forKey: "MailEngine_AutoScanEnabled")
        defaults.set(autoScanInterval, forKey: "MailEngine_AutoScanInterval")
        defaults.set(notifyHighPriority, forKey: "MailEngine_NotifyHighPriority")
        if let lastScan = lastScanTime {
            defaults.set(lastScan, forKey: "MailEngine_LastScanTime")
        }
    }
}
