//
//  IntegrationManager.swift
//  Mail Summary
//
//  Integration Manager - Calendar, Reminders, Notes, Webhooks
//  Created by Jordan Koch on 2026-01-26
//
//  Integrates with system apps and external services.
//

import Foundation
import EventKit
import UserNotifications

@MainActor
class IntegrationManager: ObservableObject {
    static let shared = IntegrationManager()

    // MARK: - Published Properties

    @Published var isCalendarEnabled: Bool = true
    @Published var isRemindersEnabled: Bool = true
    @Published var isNotesEnabled: Bool = true
    @Published var isWebhooksEnabled: Bool = false
    @Published var webhookURL: String = ""
    @Published var lastIntegrationResult: String? = nil

    // MARK: - Private Properties

    private let eventStore = EKEventStore()
    private let userDefaults = UserDefaults.standard

    // MARK: - Initialization

    private init() {
        loadSettings()
        requestCalendarAccess()
    }

    // MARK: - Calendar Integration

    /// Request calendar access
    private func requestCalendarAccess() {
        eventStore.requestAccess(to: .event) { granted, error in
            if granted {
                print("✅ Calendar access granted")
            } else {
                print("❌ Calendar access denied: \(error?.localizedDescription ?? "unknown")")
            }
        }
    }

    /// Create calendar event from meeting email
    func sendToCalendar(email: Email, meeting: EmailAction) async -> Bool {
        guard isCalendarEnabled else {
            lastIntegrationResult = "Calendar integration disabled"
            return false
        }

        guard let meetingDate = meeting.date else {
            lastIntegrationResult = "No meeting date found"
            return false
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = meeting.text
        event.notes = """
        From: \(email.sender) <\(email.senderEmail)>
        Subject: \(email.subject)

        \(email.body?.prefix(500).description ?? "")
        """
        event.startDate = meetingDate
        event.endDate = meetingDate.addingTimeInterval(3600)  // 1 hour default
        event.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(event, span: .thisEvent)
            lastIntegrationResult = "✅ Added to Calendar"
            print("✅ Created calendar event: \(meeting.text)")
            return true
        } catch {
            lastIntegrationResult = "❌ Calendar error: \(error.localizedDescription)"
            print("❌ Failed to create calendar event: \(error)")
            return false
        }
    }

    // MARK: - Reminders Integration

    /// Request reminders access
    private func requestRemindersAccess() {
        eventStore.requestAccess(to: .reminder) { granted, error in
            if granted {
                print("✅ Reminders access granted")
            } else {
                print("❌ Reminders access denied: \(error?.localizedDescription ?? "unknown")")
            }
        }
    }

    /// Create reminder from email
    func sendToReminders(email: Email, dueDate: Date) async -> Bool {
        guard isRemindersEnabled else {
            lastIntegrationResult = "Reminders integration disabled"
            return false
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = email.subject
        reminder.notes = """
        From: \(email.sender) <\(email.senderEmail)>

        \(email.body?.prefix(300).description ?? "")
        """
        reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        do {
            try eventStore.save(reminder, commit: true)
            lastIntegrationResult = "✅ Added to Reminders"
            print("✅ Created reminder: \(email.subject)")
            return true
        } catch {
            lastIntegrationResult = "❌ Reminders error: \(error.localizedDescription)"
            print("❌ Failed to create reminder: \(error)")
            return false
        }
    }

    // MARK: - Notes Integration

    /// Send email to Notes.app
    func sendToNotes(email: Email) async -> Bool {
        guard isNotesEnabled else {
            lastIntegrationResult = "Notes integration disabled"
            return false
        }

        let noteContent = """
        Subject: \(email.subject)
        From: \(email.sender) <\(email.senderEmail)>
        Date: \(formatDate(email.dateReceived))

        \(email.body ?? "")

        ---
        Imported from Mail Summary
        """

        let appleScript = """
        tell application "Notes"
            tell account "iCloud"
                make new note at folder "Notes" with properties {name:"\(escapeForAppleScript(email.subject))", body:"\(escapeForAppleScript(noteContent))"}
            end tell
        end tell
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", appleScript]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                lastIntegrationResult = "✅ Added to Notes"
                print("✅ Created note: \(email.subject)")
                return true
            } else {
                lastIntegrationResult = "❌ Notes error"
                return false
            }
        } catch {
            lastIntegrationResult = "❌ Notes error: \(error.localizedDescription)"
            print("❌ Failed to create note: \(error)")
            return false
        }
    }

    // MARK: - Webhook Integration

    /// Trigger webhook with event data
    func triggerWebhook(event: WebhookEvent, data: [String: Any]) async -> Bool {
        guard isWebhooksEnabled, !webhookURL.isEmpty else {
            return false
        }

        guard let url = URL(string: webhookURL) else {
            lastIntegrationResult = "❌ Invalid webhook URL"
            return false
        }

        var payload: [String: Any] = [
            "event": event.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "data": data
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("✅ Webhook triggered: \(event.rawValue)")
                return true
            } else {
                print("❌ Webhook failed: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return false
            }
        } catch {
            print("❌ Webhook error: \(error)")
            return false
        }
    }

    enum WebhookEvent: String {
        case emailReceived
        case emailCategorized
        case highPriorityDetected
        case ruleTriggered
        case bulkActionPerformed
    }

    // MARK: - Helpers

    private func escapeForAppleScript(_ text: String) -> String {
        text.replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Settings Persistence

    private func loadSettings() {
        isCalendarEnabled = userDefaults.bool(forKey: "Integration_CalendarEnabled")
        isRemindersEnabled = userDefaults.bool(forKey: "Integration_RemindersEnabled")
        isNotesEnabled = userDefaults.bool(forKey: "Integration_NotesEnabled")
        isWebhooksEnabled = userDefaults.bool(forKey: "Integration_WebhooksEnabled")
        webhookURL = userDefaults.string(forKey: "Integration_WebhookURL") ?? ""
    }

    func saveSettings() {
        userDefaults.set(isCalendarEnabled, forKey: "Integration_CalendarEnabled")
        userDefaults.set(isRemindersEnabled, forKey: "Integration_RemindersEnabled")
        userDefaults.set(isNotesEnabled, forKey: "Integration_NotesEnabled")
        userDefaults.set(isWebhooksEnabled, forKey: "Integration_WebhooksEnabled")
        userDefaults.set(webhookURL, forKey: "Integration_WebhookURL")
    }
}
