//
//  IntegrationsSettingsView.swift
//  Mail Summary
//
//  Integrations Settings UI
//  Created by Jordan Koch on 2026-01-26
//
//  Configuration for Calendar, Reminders, Notes, and webhook integrations.
//

import SwiftUI

struct IntegrationsSettingsView: View {
    @ObservedObject var integrationManager = IntegrationManager.shared
    @State private var testResult: String?
    @State private var isTesting: Bool = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Settings Form
            Form {
                // Calendar Integration
                Section("Calendar Integration") {
                    Toggle("Enable Calendar Integration", isOn: $integrationManager.isCalendarEnabled)
                        .onChange(of: integrationManager.isCalendarEnabled) { _ in
                            integrationManager.saveSettings()
                        }

                    Text("Create calendar events from meeting emails")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Button("Test Calendar Access") {
                        testCalendarAccess()
                    }
                    .disabled(!integrationManager.isCalendarEnabled)
                }

                // Reminders Integration
                Section("Reminders Integration") {
                    Toggle("Enable Reminders Integration", isOn: $integrationManager.isRemindersEnabled)
                        .onChange(of: integrationManager.isRemindersEnabled) { _ in
                            integrationManager.saveSettings()
                        }

                    Text("Create reminders from deadline emails")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Button("Test Reminders Access") {
                        testRemindersAccess()
                    }
                    .disabled(!integrationManager.isRemindersEnabled)
                }

                // Notes Integration
                Section("Notes Integration") {
                    Toggle("Enable Notes Integration", isOn: $integrationManager.isNotesEnabled)
                        .onChange(of: integrationManager.isNotesEnabled) { _ in
                            integrationManager.saveSettings()
                        }

                    Text("Send emails to Notes.app")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Button("Test Notes Access") {
                        testNotesAccess()
                    }
                    .disabled(!integrationManager.isNotesEnabled)
                }

                // Webhook Integration
                Section("Webhook Integration") {
                    Toggle("Enable Webhooks", isOn: $integrationManager.isWebhooksEnabled)
                        .onChange(of: integrationManager.isWebhooksEnabled) { _ in
                            integrationManager.saveSettings()
                        }

                    TextField("Webhook URL", text: $integrationManager.webhookURL)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!integrationManager.isWebhooksEnabled)
                        .onChange(of: integrationManager.webhookURL) { _ in
                            integrationManager.saveSettings()
                        }

                    Text("POST JSON payloads for email events")
                        .font(.caption)
                        .foregroundColor(.gray)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Events triggered:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("• emailReceived\n• emailCategorized\n• highPriorityDetected\n• ruleTriggered\n• bulkActionPerformed")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.gray)
                    }

                    Button("Test Webhook") {
                        testWebhook()
                    }
                    .disabled(!integrationManager.isWebhooksEnabled || integrationManager.webhookURL.isEmpty)
                }

                // Test Results
                if let result = testResult {
                    Section("Test Result") {
                        HStack {
                            if result.contains("✅") {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }

                            Text(result)
                                .foregroundColor(result.contains("✅") ? .green : .red)

                            Spacer()
                        }
                    }
                }

                // Integration History
                if let lastResult = integrationManager.lastIntegrationResult {
                    Section("Last Integration") {
                        Text(lastResult)
                            .foregroundColor(lastResult.contains("✅") ? .green : .red)
                    }
                }
            }
            .padding()

            Divider()

            // Actions
            HStack {
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 650, height: 700)
        .background(Color.black)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("🔗 Integrations")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Connect with Calendar, Reminders, Notes, and webhooks")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundColor(.gray)
        }
        .padding()
    }

    // MARK: - Test Functions

    private func testCalendarAccess() {
        isTesting = true
        testResult = nil

        Task {
            // Create a test event for tomorrow
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let testEmail = Email(
                id: 0,
                messageId: "test",
                subject: "Test Calendar Integration",
                sender: "Mail Summary Test",
                senderEmail: "test@mailsummary.app",
                dateReceived: Date(),
                isRead: true,
                actions: []
            )
            let testMeeting = EmailAction(type: .meeting, text: "Test Meeting", date: tomorrow)

            let success = await integrationManager.sendToCalendar(email: testEmail, meeting: testMeeting)

            testResult = success ? "✅ Calendar integration working" : "❌ Calendar integration failed"
            isTesting = false
        }
    }

    private func testRemindersAccess() {
        isTesting = true
        testResult = nil

        Task {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let testEmail = Email(
                id: 0,
                messageId: "test",
                subject: "Test Reminder",
                sender: "Mail Summary Test",
                senderEmail: "test@mailsummary.app",
                dateReceived: Date(),
                isRead: true,
                actions: []
            )

            let success = await integrationManager.sendToReminders(email: testEmail, dueDate: tomorrow)

            testResult = success ? "✅ Reminders integration working" : "❌ Reminders integration failed"
            isTesting = false
        }
    }

    private func testNotesAccess() {
        isTesting = true
        testResult = nil

        Task {
            let testEmail = Email(
                id: 0,
                messageId: "test",
                subject: "Test Note",
                sender: "Mail Summary Test",
                senderEmail: "test@mailsummary.app",
                dateReceived: Date(),
                body: "This is a test note created by Mail Summary integration.",
                isRead: true,
                actions: []
            )

            let success = await integrationManager.sendToNotes(email: testEmail)

            testResult = success ? "✅ Notes integration working" : "❌ Notes integration failed"
            isTesting = false
        }
    }

    private func testWebhook() {
        isTesting = true
        testResult = nil

        Task {
            let testData: [String: Any] = [
                "test": true,
                "message": "Test webhook from Mail Summary",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]

            let success = await integrationManager.triggerWebhook(event: .emailReceived, data: testData)

            testResult = success ? "✅ Webhook delivered successfully" : "❌ Webhook delivery failed"
            isTesting = false
        }
    }

    // MARK: - Filtered Emails
    // TODO: Implement filteredEmails when needed
    // This function needs access to mailEngine and filter state that aren't currently in this view
    /*
    private func filteredEmails() -> [Email] {
        var filtered = mailEngine.emails

        // Date range filter
        if dateRange == .custom {
            filtered = filtered.filter {
                $0.dateReceived >= customStartDate && $0.dateReceived <= customEndDate
            }
        } else if let range = dateRange.dateRange() {
            filtered = filtered.filter {
                $0.dateReceived >= range.0 && $0.dateReceived <= range.1
            }
        }

        // Category filter
        if !includeCategories.isEmpty {
            filtered = filtered.filter {
                if let category = $0.category {
                    return includeCategories.contains(category)
                }
                return false
            }
        }

        return filtered
    }
    */
}

// MARK: - Preview

#if DEBUG
struct IntegrationsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        IntegrationsSettingsView()
    }
}
#endif
