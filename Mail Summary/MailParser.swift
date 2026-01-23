//
//  MailParser.swift
//  Mail Summary
//
//  Uses AppleScript to read Mail.app directly (better than SQLite parsing)
//  Created by Jordan Koch on 2026-01-22
//

import Foundation
import AppKit

/// Reads Mail.app using AppleScript (official API)
/// Hybrid approach: Fast metadata loading + on-demand body fetching
class MailParser {

    /// Load email metadata in batches (fast, no bodies)
    /// This loads subject, sender, date, messageId for up to 500 emails in ~5 seconds
    func parseEmails(limit: Int = 500, batchSize: Int = 50) async -> [Email] {
        print("📧 Loading email metadata from Mail.app (batched)...")

        // Check if Mail.app is running
        if !isMailAppRunning() {
            print("⚠️ Mail.app is not running. Using sample data.")
            print("💡 Open Mail.app first, then click 'Scan Now' in Mail Summary")
            return sampleEmails()
        }

        var allEmails: [Email] = []
        let totalBatches = (limit + batchSize - 1) / batchSize

        for batchIndex in 0..<totalBatches {
            let offset = batchIndex * batchSize
            let batchLimit = min(batchSize, limit - offset)

            print("📦 Loading batch \(batchIndex + 1)/\(totalBatches) (emails \(offset + 1)-\(offset + batchLimit))...")

            let batchEmails = await loadMetadataBatch(offset: offset, limit: batchLimit, startId: offset)
            allEmails.append(contentsOf: batchEmails)

            // Stop if we got fewer emails than requested (no more emails)
            if batchEmails.count < batchLimit {
                print("✅ Loaded all available emails (\(allEmails.count) total)")
                break
            }
        }

        if allEmails.isEmpty {
            print("⚠️ No emails found. Using sample data.")
            return sampleEmails()
        }

        print("✅ Loaded \(allEmails.count) email metadata records from Mail.app")
        return allEmails
    }

    /// Load a single batch of email metadata (no bodies)
    private func loadMetadataBatch(offset: Int, limit: Int, startId: Int) async -> [Email] {
        // AppleScript to get metadata only - very fast, no body content
        let script = """
        tell application "Mail"
            set allMessages to {}
            set unreadMsgs to (messages of inbox whose read status is false)
            set msgCount to count of unreadMsgs
            set startIndex to \(offset + 1)
            set endIndex to startIndex + \(limit) - 1
            if endIndex > msgCount then set endIndex to msgCount

            repeat with i from startIndex to endIndex
                set msg to item i of unreadMsgs
                try
                    set msgId to id of msg as string
                    set subj to subject of msg
                    set sndr to sender of msg
                    set rcvd to (date received of msg) as string
                    set isReadStatus to read status of msg
                    -- No body content = very fast
                    set msgData to msgId & "|" & subj & "|" & sndr & "|" & rcvd & "|" & isReadStatus
                    set end of allMessages to msgData
                end try
            end repeat

            set AppleScript's text item delimiters to "|||"
            set output to allMessages as string
            return output
        end tell
        """

        return await withCheckedContinuation { continuation in
            Task.detached {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                // Timeout after 10 seconds per batch (metadata is fast)
                let timeoutSeconds: TimeInterval = 10
                var timedOut = false
                var processCompleted = false

                process.terminationHandler = { _ in
                    processCompleted = true
                }

                do {
                    try process.run()

                    // Start timeout timer
                    Task.detached {
                        try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                        if !processCompleted {
                            timedOut = true
                            print("⏱️ Batch timed out after \(timeoutSeconds)s - terminating...")
                            process.terminate()
                        }
                    }

                    process.waitUntilExit()

                    if timedOut {
                        print("❌ Batch timed out.")
                        continuation.resume(returning: [])
                        return
                    }

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
                        print("❌ Batch returned no data")
                        continuation.resume(returning: [])
                        return
                    }

                    // Parse batch output
                    let emails = self.parseMetadataOutput(output, startId: startId)
                    continuation.resume(returning: emails)

                } catch {
                    print("❌ Batch error: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /// Load email body on-demand for a specific message
    func loadEmailBody(messageId: String) async -> String? {
        print("📄 Loading body for message ID: \(messageId)...")

        if !isMailAppRunning() {
            return nil
        }

        let script = """
        tell application "Mail"
            try
                set msg to first message whose id is \(messageId)
                set msgBody to content of msg as string
                return msgBody
            on error errMsg
                return "ERROR: " & errMsg
            end try
        end tell
        """

        return await withCheckedContinuation { continuation in
            Task.detached {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                // Timeout after 5 seconds for single email body
                let timeoutSeconds: TimeInterval = 5
                var timedOut = false
                var processCompleted = false

                process.terminationHandler = { _ in
                    processCompleted = true
                }

                do {
                    try process.run()

                    Task.detached {
                        try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                        if !processCompleted {
                            timedOut = true
                            process.terminate()
                        }
                    }

                    process.waitUntilExit()

                    if timedOut {
                        print("⏱️ Body load timed out")
                        continuation.resume(returning: nil)
                        return
                    }

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
                        continuation.resume(returning: nil)
                        return
                    }

                    // Check for AppleScript errors
                    if output.hasPrefix("ERROR:") {
                        print("❌ AppleScript error: \(output)")
                        continuation.resume(returning: nil)
                        return
                    }

                    print("✅ Loaded body (\(output.count) chars)")
                    continuation.resume(returning: output)

                } catch {
                    print("❌ Body load error: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func isMailAppRunning() -> Bool {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        return runningApps.contains { $0.bundleIdentifier == "com.apple.mail" }
    }

    /// Parse metadata output from AppleScript
    /// Format: messageId|subject|sender|date|isRead
    private func parseMetadataOutput(_ output: String, startId: Int) -> [Email] {
        var emails: [Email] = []

        // Split by delimiter (|||)
        let messages = output.components(separatedBy: "|||").filter { !$0.isEmpty }

        for (index, messageString) in messages.enumerated() {
            // Each message is pipe-delimited: messageId|subject|sender|date|isRead
            let parts = messageString.components(separatedBy: "|")
            guard parts.count >= 5 else {
                print("⚠️ Skipping malformed message: \(parts.count) parts")
                continue
            }

            let messageId = parts[0].trimmingCharacters(in: .whitespaces)
            let subject = parts[1].trimmingCharacters(in: .whitespaces)
            let sender = parts[2].trimmingCharacters(in: .whitespaces)
            let dateString = parts[3].trimmingCharacters(in: .whitespaces)
            let isReadString = parts[4].trimmingCharacters(in: .whitespaces)

            // Parse date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm:ss a"
            let date = dateFormatter.date(from: dateString) ?? Date()

            // Parse read status
            let isRead = isReadString.lowercased() == "true"

            // Extract email address from sender (format: "Name <email@domain.com>")
            var senderEmail = sender
            var senderName = sender
            if let emailStart = sender.firstIndex(of: "<"), let emailEnd = sender.firstIndex(of: ">") {
                senderEmail = String(sender[emailStart...emailEnd]).replacingOccurrences(of: "<", with: "").replacingOccurrences(of: ">", with: "")
                senderName = String(sender[..<emailStart]).trimmingCharacters(in: .whitespaces)
            }

            let email = Email(
                id: startId + index,
                messageId: messageId,
                subject: subject,
                sender: senderName,
                senderEmail: senderEmail,
                dateReceived: date,
                body: nil,  // Body loaded on-demand
                isRead: isRead,
                category: nil, // Will be categorized by AI
                priority: nil, // Will be scored by AI
                aiSummary: nil,
                actions: [],
                senderReputation: nil
            )

            emails.append(email)
        }

        return emails
    }

    /// Sample emails for development
    private func sampleEmails() -> [Email] {
        return [
            Email(id: 1, messageId: "sample-1", subject: "Your Amazon order has shipped", sender: "Amazon", senderEmail: "shipment@amazon.com", dateReceived: Date(), body: "Your order #123-456 has been shipped and will arrive Friday.", isRead: false, category: .orders, priority: 7, aiSummary: "Amazon order arriving Friday", actions: [], senderReputation: 0.9),
            Email(id: 2, messageId: "sample-2", subject: "Electric Bill Due January 25", sender: "PG&E", senderEmail: "billing@pge.com", dateReceived: Date().addingTimeInterval(-3600), body: "Your electric bill of $156.78 is due January 25.", isRead: false, category: .bills, priority: 9, aiSummary: "Electric bill $156.78 due Jan 25", actions: [EmailAction(type: .deadline, text: "Pay bill by Jan 25", date: Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 25)))], senderReputation: 0.95),
            Email(id: 3, messageId: "sample-3", subject: "50% OFF SALE - Limited Time!", sender: "Marketing Co", senderEmail: "promo@marketing.com", dateReceived: Date().addingTimeInterval(-7200), body: "Don't miss our biggest sale of the year! Click here now!", isRead: false, category: .marketing, priority: 2, aiSummary: "Generic marketing email - 50% off sale", actions: [], senderReputation: 0.1),
            Email(id: 4, messageId: "sample-4", subject: "Team Meeting Tuesday 3pm", sender: "Boss", senderEmail: "boss@company.com", dateReceived: Date().addingTimeInterval(-10800), body: "Team meeting Tuesday at 3pm in conference room A. Please review Q1 projections.", isRead: false, category: .work, priority: 8, aiSummary: "Team meeting Tue 3pm - review Q1 projections", actions: [EmailAction(type: .meeting, text: "Team meeting Tuesday 3pm", date: Calendar.current.date(byAdding: .day, value: 2, to: Date()))], senderReputation: 0.85)
        ]
    }
}

