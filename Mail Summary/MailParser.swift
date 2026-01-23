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
class MailParser {

    /// Parse emails from Mail.app via AppleScript
    func parseEmails(limit: Int = 500) -> [Email] {
        print("📧 Reading Mail.app via AppleScript...")

        // Check if Mail.app is running
        if !isMailAppRunning() {
            print("⚠️ Mail.app is not running. Using sample data.")
            print("💡 Open Mail.app first, then click 'Scan Now' in Mail Summary")
            return sampleEmails()
        }

        // Simplified AppleScript - get unread messages from inbox
        let script = """
        tell application "Mail"
            set allMessages to {}
            set unreadMsgs to (messages of inbox whose read status is false)
            set msgCount to count of unreadMsgs
            if msgCount > \(limit) then set msgCount to \(limit)

            repeat with i from 1 to msgCount
                set msg to item i of unreadMsgs
                try
                    set subj to subject of msg
                    set sndr to sender of msg
                    set rcvd to (date received of msg) as string
                    set msgBody to content of msg
                    set msgData to subj & "|" & sndr & "|" & rcvd & "|" & msgBody
                    set end of allMessages to msgData
                end try
            end repeat

            set AppleScript's text item delimiters to "|||"
            set output to allMessages as string
            return output
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
                print("❌ AppleScript returned no data")
                return sampleEmails()
            }

            print("AppleScript output: \(output.prefix(200))...")

            // Parse AppleScript output
            let emails = parseAppleScriptOutput(output)

            if !emails.isEmpty {
                print("✅ Loaded \(emails.count) real emails from Mail.app")
                return emails
            } else {
                print("⚠️ No emails parsed. Using sample data.")
                return sampleEmails()
            }

        } catch {
            print("❌ AppleScript error: \(error)")
            return sampleEmails()
        }
    }

    private func isMailAppRunning() -> Bool {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        return runningApps.contains { $0.bundleIdentifier == "com.apple.mail" }
    }

    private func parseAppleScriptOutput(_ output: String) -> [Email] {
        var emails: [Email] = []

        // Split by delimiter (|||)
        let messages = output.components(separatedBy: "|||").filter { !$0.isEmpty }

        print("📧 Parsing \(messages.count) messages from AppleScript...")

        for (index, messageString) in messages.enumerated() {
            // Each message is pipe-delimited: subject|sender|date|body
            let parts = messageString.components(separatedBy: "|")
            guard parts.count >= 4 else {
                print("⚠️ Skipping malformed message: \(parts.count) parts")
                continue
            }

            let subject = parts[0].trimmingCharacters(in: .whitespaces)
            let sender = parts[1].trimmingCharacters(in: .whitespaces)
            let dateString = parts[2].trimmingCharacters(in: .whitespaces)
            let body = parts[3].prefix(500).trimmingCharacters(in: .whitespaces) // First 500 chars

            // Parse date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm:ss a"
            let date = dateFormatter.date(from: dateString) ?? Date()

            // Extract email address from sender (format: "Name <email@domain.com>")
            var senderEmail = sender
            var senderName = sender
            if let emailStart = sender.firstIndex(of: "<"), let emailEnd = sender.firstIndex(of: ">") {
                senderEmail = String(sender[emailStart...emailEnd]).replacingOccurrences(of: "<", with: "").replacingOccurrences(of: ">", with: "")
                senderName = String(sender[..<emailStart]).trimmingCharacters(in: .whitespaces)
            }

            let email = Email(
                id: index,
                subject: subject,
                sender: senderName,
                senderEmail: senderEmail,
                dateReceived: date,
                body: String(body),
                isRead: false, // AppleScript filtered to unread only
                category: nil, // Will be categorized by AI
                priority: nil, // Will be scored by AI
                aiSummary: nil,
                actions: [],
                senderReputation: nil
            )

            emails.append(email)
        }

        print("✅ Successfully parsed \(emails.count) emails from Mail.app")
        return emails
    }

    /// Sample emails for development
    private func sampleEmails() -> [Email] {
        return [
            Email(id: 1, subject: "Your Amazon order has shipped", sender: "Amazon", senderEmail: "shipment@amazon.com", dateReceived: Date(), body: "Your order #123-456 has been shipped and will arrive Friday.", isRead: false, category: .orders, priority: 7, aiSummary: "Amazon order arriving Friday", actions: [], senderReputation: 0.9),
            Email(id: 2, subject: "Electric Bill Due January 25", sender: "PG&E", senderEmail: "billing@pge.com", dateReceived: Date().addingTimeInterval(-3600), body: "Your electric bill of $156.78 is due January 25.", isRead: false, category: .bills, priority: 9, aiSummary: "Electric bill $156.78 due Jan 25", actions: [EmailAction(type: .deadline, text: "Pay bill by Jan 25", date: Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 25)))], senderReputation: 0.95),
            Email(id: 3, subject: "50% OFF SALE - Limited Time!", sender: "Marketing Co", senderEmail: "promo@marketing.com", dateReceived: Date().addingTimeInterval(-7200), body: "Don't miss our biggest sale of the year! Click here now!", isRead: false, category: .marketing, priority: 2, aiSummary: "Generic marketing email - 50% off sale", actions: [], senderReputation: 0.1),
            Email(id: 4, subject: "Team Meeting Tuesday 3pm", sender: "Boss", senderEmail: "boss@company.com", dateReceived: Date().addingTimeInterval(-10800), body: "Team meeting Tuesday at 3pm in conference room A. Please review Q1 projections.", isRead: false, category: .work, priority: 8, aiSummary: "Team meeting Tue 3pm - review Q1 projections", actions: [EmailAction(type: .meeting, text: "Team meeting Tuesday 3pm", date: Calendar.current.date(byAdding: .day, value: 2, to: Date()))], senderReputation: 0.85)
        ]
    }
}

