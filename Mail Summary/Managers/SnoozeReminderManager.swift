//
//  SnoozeReminderManager.swift
//  Mail Summary
//
//  Manages snooze and reminder functionality with UserDefaults persistence and local notifications
//  Created by Jordan Koch on 2026-01-23
//

import Foundation
import UserNotifications

@MainActor
class SnoozeReminderManager: ObservableObject {
    static let shared = SnoozeReminderManager()

    @Published var snoozedEmails: [SnoozedEmail] = []
    @Published var reminders: [EmailReminder] = []

    private let snoozedKey = "MailSummary_SnoozedEmails"
    private let remindersKey = "MailSummary_Reminders"

    private init() {
        loadSnoozedEmails()
        loadReminders()
        cleanupExpired()
        requestNotificationPermission()
    }

    // MARK: - Snooze Operations

    /// Snooze an email until a specific date
    func snoozeEmail(emailId: Int, messageId: String, subject: String, sender: String, until: Date) {
        let snoozed = SnoozedEmail(
            id: UUID(),
            emailId: emailId,
            messageId: messageId,
            emailSubject: subject,
            senderEmail: sender,
            snoozeUntil: until,
            createdAt: Date()
        )

        snoozedEmails.append(snoozed)
        saveSnoozedEmails()

        // Schedule notification
        scheduleSnoozeNotification(for: snoozed)

        print("📧 Snoozed email until \(until): \(subject)")
    }

    /// Unsnooze an email (show it again)
    func unsnooze(emailId: Int) {
        if let snoozed = snoozedEmails.first(where: { $0.emailId == emailId }) {
            // Cancel notification
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: [snoozed.id.uuidString]
            )

            snoozedEmails.removeAll { $0.emailId == emailId }
            saveSnoozedEmails()

            print("📧 Unsnoozed email: \(snoozed.emailSubject)")
        }
    }

    /// Get all snoozed emails that have expired and should be shown
    func getExpiredSnoozed() -> [SnoozedEmail] {
        return snoozedEmails.filter { $0.isExpired }
    }

    /// Check if an email is currently snoozed
    func isSnoozed(emailId: Int) -> Bool {
        return snoozedEmails.contains { $0.emailId == emailId }
    }

    // MARK: - Reminder Operations

    /// Add a reminder for an email
    func addReminder(
        emailId: Int,
        messageId: String,
        subject: String,
        remindAt: Date,
        note: String?,
        type: EmailReminder.ReminderType
    ) {
        let reminder = EmailReminder(
            id: UUID(),
            emailId: emailId,
            messageId: messageId,
            emailSubject: subject,
            remindAt: remindAt,
            note: note,
            reminderType: type,
            createdAt: Date(),
            isCompleted: false
        )

        reminders.append(reminder)
        saveReminders()

        // Schedule notification
        scheduleReminderNotification(for: reminder)

        print("⏰ Set reminder for \(remindAt): \(subject)")
    }

    /// Mark a reminder as completed
    func completeReminder(_ reminderId: UUID) {
        if let index = reminders.firstIndex(where: { $0.id == reminderId }) {
            reminders[index].isCompleted = true
            saveReminders()

            print("✅ Completed reminder: \(reminders[index].emailSubject)")
        }
    }

    /// Delete a reminder
    func deleteReminder(_ reminderId: UUID) {
        if let reminder = reminders.first(where: { $0.id == reminderId }) {
            // Cancel notification
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: [reminderId.uuidString]
            )

            reminders.removeAll { $0.id == reminderId }
            saveReminders()

            print("🗑️ Deleted reminder: \(reminder.emailSubject)")
        }
    }

    /// Get all active (ready to show) reminders
    func getActiveReminders() -> [EmailReminder] {
        return reminders.filter { $0.isReady }.sorted { $0.remindAt < $1.remindAt }
    }

    /// Get upcoming reminders (next 7 days)
    func getUpcomingReminders() -> [EmailReminder] {
        let sevenDaysFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        return reminders.filter {
            $0.remindAt >= Date() &&
            $0.remindAt <= sevenDaysFromNow &&
            !$0.isCompleted
        }.sorted { $0.remindAt < $1.remindAt }
    }

    // MARK: - Notifications

    /// Request notification permission from user
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ Notification permission error: \(error)")
            } else if granted {
                print("✅ Notification permission granted")
            } else {
                print("⚠️ Notification permission denied")
            }
        }
    }

    /// Schedule a notification for a snoozed email
    private func scheduleSnoozeNotification(for snoozed: SnoozedEmail) {
        let content = UNMutableNotificationContent()
        content.title = "Snoozed Email"
        content.body = snoozed.emailSubject
        content.subtitle = "From: \(snoozed.senderEmail)"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: snoozed.snoozeUntil
            ),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: snoozed.id.uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule snooze notification: \(error)")
            }
        }
    }

    /// Schedule a notification for a reminder
    private func scheduleReminderNotification(for reminder: EmailReminder) {
        let content = UNMutableNotificationContent()
        content.title = "Email Reminder"
        content.body = reminder.emailSubject
        content.subtitle = reminder.note ?? reminder.reminderType.rawValue
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminder.remindAt
            ),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule reminder notification: \(error)")
            }
        }
    }

    // MARK: - Cleanup

    /// Clean up expired snoozed emails and completed reminders
    func cleanupExpired() {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!

        // Remove snoozed emails older than 30 days
        let removedSnoozed = snoozedEmails.filter { $0.createdAt < thirtyDaysAgo && $0.isExpired }
        snoozedEmails.removeAll { $0.createdAt < thirtyDaysAgo && $0.isExpired }

        // Remove completed reminders older than 7 days
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let removedReminders = reminders.filter { $0.isCompleted && $0.createdAt < sevenDaysAgo }
        reminders.removeAll { $0.isCompleted && $0.createdAt < sevenDaysAgo }

        if !removedSnoozed.isEmpty || !removedReminders.isEmpty {
            saveSnoozedEmails()
            saveReminders()
            print("🧹 Cleaned up \(removedSnoozed.count) snoozed emails, \(removedReminders.count) reminders")
        }
    }

    // MARK: - Persistence (UserDefaults + JSON)

    private func saveSnoozedEmails() {
        do {
            let encoded = try JSONEncoder().encode(snoozedEmails)
            UserDefaults.standard.set(encoded, forKey: snoozedKey)
            print("💾 Saved \(snoozedEmails.count) snoozed emails")
        } catch {
            print("❌ Failed to save snoozed emails: \(error)")
        }
    }

    private func loadSnoozedEmails() {
        guard let data = UserDefaults.standard.data(forKey: snoozedKey) else {
            print("📭 No snoozed emails found")
            return
        }

        do {
            snoozedEmails = try JSONDecoder().decode([SnoozedEmail].self, from: data)
            print("📬 Loaded \(snoozedEmails.count) snoozed emails")
        } catch {
            print("❌ Failed to load snoozed emails: \(error)")
        }
    }

    private func saveReminders() {
        do {
            let encoded = try JSONEncoder().encode(reminders)
            UserDefaults.standard.set(encoded, forKey: remindersKey)
            print("💾 Saved \(reminders.count) reminders")
        } catch {
            print("❌ Failed to save reminders: \(error)")
        }
    }

    private func loadReminders() {
        guard let data = UserDefaults.standard.data(forKey: remindersKey) else {
            print("⏰ No reminders found")
            return
        }

        do {
            reminders = try JSONDecoder().decode([EmailReminder].self, from: data)
            print("⏰ Loaded \(reminders.count) reminders")
        } catch {
            print("❌ Failed to load reminders: \(error)")
        }
    }
}
