//
//  RulesEngine.swift
//  Mail Summary
//
//  Smart Rules Engine - Business Logic
//  Created by Jordan Koch on 2026-01-26
//
//  Evaluates rules against emails and executes actions automatically.
//  Runs after AI categorization to allow users to customize email handling.
//

import Foundation
import UserNotifications

@MainActor
class RulesEngine: ObservableObject {
    static let shared = RulesEngine()

    // MARK: - Published Properties

    @Published var rules: [EmailRule] = []
    @Published var statistics: RuleStatistics = RuleStatistics(
        totalRules: 0,
        enabledRules: 0,
        totalExecutions: 0,
        successfulExecutions: 0,
        failedExecutions: 0,
        lastExecutionDate: nil,
        avgExecutionTime: 0.0
    )
    @Published var isProcessing: Bool = false
    @Published var lastExecutionResults: [RuleExecutionResult] = []

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private let rulesKey = "MailSummary_Rules"
    private let statsKey = "MailSummary_RuleStatistics"
    private var executionTimes: [TimeInterval] = []

    // MARK: - Initialization

    private init() {
        loadRules()
        loadStatistics()
    }

    // MARK: - Rule Management

    func addRule(_ rule: EmailRule) {
        var newRule = rule
        newRule.lastModified = Date()
        rules.append(newRule)
        sortRulesByPriority()
        saveRules()
        updateStatistics()
    }

    func updateRule(_ rule: EmailRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        var updatedRule = rule
        updatedRule.lastModified = Date()
        rules[index] = updatedRule
        sortRulesByPriority()
        saveRules()
    }

    func deleteRule(_ ruleId: UUID) {
        rules.removeAll { $0.id == ruleId }
        saveRules()
        updateStatistics()
    }

    func toggleRule(_ ruleId: UUID) {
        guard let index = rules.firstIndex(where: { $0.id == ruleId }) else { return }
        rules[index].isEnabled.toggle()
        rules[index].lastModified = Date()
        saveRules()
        updateStatistics()
    }

    func moveRule(from source: IndexSet, to destination: Int) {
        rules.move(fromOffsets: source, toOffset: destination)
        // Update priorities based on new order
        for (index, _) in rules.enumerated() {
            rules[index].priority = 100 - index
        }
        saveRules()
    }

    // MARK: - Rule Execution

    /// Apply all enabled rules to an array of emails
    func applyRules(to emails: [Email]) async -> [Email] {
        guard !rules.isEmpty else { return emails }

        let enabledRules = rules.filter { $0.isEnabled }
        guard !enabledRules.isEmpty else { return emails }

        isProcessing = true
        lastExecutionResults = []
        var modifiedEmails = emails

        let startTime = Date()

        for rule in enabledRules {
            let ruleStartTime = Date()
            var matchedCount = 0
            var actionsExecuted = 0
            var errors: [String] = []

            for (index, email) in modifiedEmails.enumerated() {
                if evaluateRule(rule, for: email) {
                    matchedCount += 1

                    // Execute actions
                    var modifiedEmail = email
                    var shouldStopProcessing = false

                    for action in rule.actions {
                        do {
                            (modifiedEmail, shouldStopProcessing) = try await executeAction(action, on: modifiedEmail)
                            actionsExecuted += 1
                        } catch {
                            errors.append("Action failed: \(error.localizedDescription)")
                        }

                        if shouldStopProcessing {
                            break
                        }
                    }

                    modifiedEmails[index] = modifiedEmail

                    // Increment execution count for this rule
                    if let ruleIndex = rules.firstIndex(where: { $0.id == rule.id }) {
                        rules[ruleIndex].executionCount += 1
                    }
                }
            }

            let ruleExecutionTime = Date().timeIntervalSince(ruleStartTime)
            executionTimes.append(ruleExecutionTime)

            // Record execution result
            let result = RuleExecutionResult(
                ruleId: rule.id,
                ruleName: rule.name,
                matched: matchedCount > 0,
                actionsExecuted: actionsExecuted,
                errors: errors,
                executionTime: ruleExecutionTime
            )
            lastExecutionResults.append(result)

            // Update statistics
            statistics.totalExecutions += 1
            if result.isSuccess {
                statistics.successfulExecutions += 1
            } else {
                statistics.failedExecutions += 1
            }
        }

        let totalExecutionTime = Date().timeIntervalSince(startTime)
        statistics.lastExecutionDate = Date()
        statistics.avgExecutionTime = executionTimes.reduce(0, +) / Double(executionTimes.count)

        saveRules()
        saveStatistics()
        isProcessing = false

        print("✅ Rules Engine: Applied \(enabledRules.count) rules to \(emails.count) emails in \(String(format: "%.2f", totalExecutionTime))s")

        return modifiedEmails
    }

    /// Evaluate a single rule against an email
    func evaluateRule(_ rule: EmailRule, for email: Email) -> Bool {
        guard rule.isEnabled else { return false }
        guard !rule.conditions.isEmpty else { return false }

        switch rule.matchType {
        case .all:
            // AND logic - all conditions must match
            return rule.conditions.allSatisfy { evaluateCondition($0, for: email) }
        case .any:
            // OR logic - any condition can match
            return rule.conditions.contains { evaluateCondition($0, for: email) }
        }
    }

    /// Evaluate a single condition against an email
    private func evaluateCondition(_ condition: RuleCondition, for email: Email) -> Bool {
        switch condition.type {
        case .senderContains(let text):
            return email.sender.localizedCaseInsensitiveContains(text) ||
                   email.senderEmail.localizedCaseInsensitiveContains(text)

        case .senderIs(let emailAddress):
            return email.senderEmail.localizedCaseInsensitiveCompare(emailAddress) == .orderedSame

        case .senderDomain(let domain):
            return email.senderEmail.lowercased().hasSuffix("@\(domain.lowercased())")

        case .subjectContains(let text):
            return email.subject.localizedCaseInsensitiveContains(text)

        case .bodyContains(let text):
            guard let body = email.body else { return false }
            return body.localizedCaseInsensitiveContains(text)

        case .categoryIs(let category):
            return email.category == category

        case .priorityGreaterThan(let value):
            guard let priority = email.priority else { return false }
            return priority > value

        case .priorityLessThan(let value):
            guard let priority = email.priority else { return false }
            return priority < value

        case .ageGreaterThan(let days):
            let ageInDays = Calendar.current.dateComponents([.day], from: email.dateReceived, to: Date()).day ?? 0
            return ageInDays > days

        case .ageLessThan(let days):
            let ageInDays = Calendar.current.dateComponents([.day], from: email.dateReceived, to: Date()).day ?? 0
            return ageInDays < days

        case .hasAttachment:
            // AppleScript doesn't expose attachments, so always return false for now
            // TODO: Implement if Mail.app API provides attachment data
            return false

        case .isUnread:
            return !email.isRead

        case .isRead:
            return email.isRead

        case .hasActionItems:
            return !email.actions.isEmpty

        case .senderIsVIP:
            // Check if sender is VIP (will be implemented in Sender Intelligence feature)
            // For now, always return false
            return false
        }
    }

    /// Execute a single action on an email
    private func executeAction(_ action: RuleAction, on email: Email) async throws -> (Email, Bool) {
        var modifiedEmail = email
        var shouldStopProcessing = false

        switch action.type {
        case .categorize(let category):
            modifiedEmail.category = category

        case .setPriority(let value):
            modifiedEmail.priority = min(max(value, 1), 10)  // Clamp to 1-10

        case .delete:
            // Mark for deletion (actual deletion handled by MailEngine)
            // For now, just set a flag or track in separate array
            // TODO: Integrate with EmailActionManager for actual deletion
            break

        case .archive:
            // Mark for archiving (handled by MailEngine)
            // TODO: Integrate with EmailActionManager for actual archiving
            break

        case .markRead:
            modifiedEmail.isRead = true
            // TODO: Sync with Mail.app via EmailActionManager

        case .markUnread:
            modifiedEmail.isRead = false
            // TODO: Sync with Mail.app via EmailActionManager

        case .move(let mailbox):
            // TODO: Integrate with EmailActionManager for moving
            break

        case .snooze(let date):
            modifiedEmail.isSnoozed = true
            modifiedEmail.snoozeUntil = date
            // TODO: Integrate with SnoozeReminderManager

        case .addTag(let tag):
            // TODO: Implement tagging system (not yet in Email model)
            break

        case .notify(let message):
            await showNotification(title: "Rule: \(email.subject)", body: message)

        case .stopProcessing:
            shouldStopProcessing = true
        }

        return (modifiedEmail, shouldStopProcessing)
    }

    // MARK: - Notification

    private func showNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Immediate delivery
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Testing

    /// Test a rule against current emails to see how many would match
    func testRule(_ rule: EmailRule, against emails: [Email]) -> (matches: Int, total: Int) {
        let matches = emails.filter { evaluateRule(rule, for: $0) }.count
        return (matches: matches, total: emails.count)
    }

    // MARK: - Persistence

    private func saveRules() {
        if let encoded = try? JSONEncoder().encode(rules) {
            userDefaults.set(encoded, forKey: rulesKey)
        }
    }

    private func loadRules() {
        guard let data = userDefaults.data(forKey: rulesKey),
              let decoded = try? JSONDecoder().decode([EmailRule].self, from: data) else {
            // Create default rules if none exist
            createDefaultRules()
            return
        }
        rules = decoded
        sortRulesByPriority()
    }

    private func saveStatistics() {
        if let encoded = try? JSONEncoder().encode(statistics) {
            userDefaults.set(encoded, forKey: statsKey)
        }
    }

    private func loadStatistics() {
        guard let data = userDefaults.data(forKey: statsKey),
              let decoded = try? JSONDecoder().decode(RuleStatistics.self, from: data) else {
            return
        }
        statistics = decoded
    }

    private func sortRulesByPriority() {
        rules.sort { $0.priority > $1.priority }
    }

    private func updateStatistics() {
        statistics.totalRules = rules.count
        statistics.enabledRules = rules.filter { $0.isEnabled }.count
        saveStatistics()
    }

    // MARK: - Default Rules

    private func createDefaultRules() {
        // Rule 1: Auto-delete old marketing emails
        let rule1 = EmailRule(
            name: "Auto-delete old marketing",
            conditions: [
                RuleCondition(type: .categoryIs(.marketing)),
                RuleCondition(type: .ageGreaterThan(days: 7))
            ],
            actions: [
                RuleAction(type: .delete)
            ],
            priority: 90,
            matchType: .all
        )

        // Rule 2: Mark newsletters as read
        let rule2 = EmailRule(
            name: "Mark newsletters as read",
            conditions: [
                RuleCondition(type: .categoryIs(.newsletters)),
                RuleCondition(type: .ageGreaterThan(days: 3))
            ],
            actions: [
                RuleAction(type: .markRead)
            ],
            priority: 80,
            matchType: .all
        )

        // Rule 3: Prioritize bills
        let rule3 = EmailRule(
            name: "Prioritize bills",
            conditions: [
                RuleCondition(type: .categoryIs(.bills))
            ],
            actions: [
                RuleAction(type: .setPriority(9))
            ],
            priority: 95,
            matchType: .all
        )

        rules = [rule1, rule2, rule3]
        saveRules()
        updateStatistics()
    }

    // MARK: - Import/Export

    func exportRules() -> String? {
        guard let data = try? JSONEncoder().encode(rules),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }

    func importRules(from jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8),
              let importedRules = try? JSONDecoder().decode([EmailRule].self, from: data) else {
            return false
        }

        rules = importedRules
        sortRulesByPriority()
        saveRules()
        updateStatistics()
        return true
    }
}
