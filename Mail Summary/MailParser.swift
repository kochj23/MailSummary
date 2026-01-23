//
//  MailParser.swift
//  Mail Summary
//
//  Parses Mail.app's Envelope Index database and .emlx files
//  Created by Jordan Koch on 2026-01-22
//

import Foundation

/// Parses macOS Mail.app mailboxes
class MailParser {
    
    /// Get Mail.app data directory
    static var mailDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mail")
    }

    /// Find Envelope Index database (V10 for recent macOS)
    static func findEnvelopeDatabase() -> URL? {
        let possiblePaths = [
            mailDirectory.appendingPathComponent("V10/MailData/Envelope Index"),
            mailDirectory.appendingPathComponent("V9/MailData/Envelope Index"),
            mailDirectory.appendingPathComponent("V8/MailData/Envelope Index")
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }

        return nil
    }

    /// Parse emails from Mail.app database
    func parseEmails(limit: Int = 100) -> [Email] {
        // First, try to read real Mail.app database
        if let realEmails = parseRealMailDatabase(limit: limit), !realEmails.isEmpty {
            print("✅ Loaded \(realEmails.count) real emails from Mail.app")
            return realEmails
        }

        // Fallback to sample data if can't access Mail.app
        print("⚠️ Using sample data - grant Full Disk Access to read real emails")
        return sampleEmails()
    }

    /// Parse real Mail.app database (new implementation)
    private func parseRealMailDatabase(limit: Int) -> [Email]? {
        guard let dbPath = MailParser.findEnvelopeDatabase() else {
            print("Envelope Index not found")
            return nil
        }

        print("📧 Reading Mail.app database: \(dbPath.path)")

        // Try to read with shell command (simpler than SQLite.swift dependency)
        let query = """
        SELECT
            m.ROWID,
            m.subject,
            m.date_received,
            a.address,
            a.comment
        FROM messages m
        LEFT JOIN addresses a ON m.sender = a.ROWID
        WHERE m.date_received > \(Int(Date().addingTimeInterval(-30*24*3600).timeIntervalSince1970))
        ORDER BY m.date_received DESC
        LIMIT \(limit);
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [dbPath.path, query]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
                return nil
            }

            // Parse SQLite output
            var emails: [Email] = []
            let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }

            for (index, line) in lines.enumerated() {
                let parts = line.components(separatedBy: "|")
                guard parts.count >= 5 else { continue }

                let id = Int(parts[0]) ?? index
                let subject = parts[1]
                let timestampStr = parts[2]
                let senderEmail = parts[3]
                let senderName = parts[4].isEmpty ? parts[3] : parts[4]

                let timestamp = TimeInterval(timestampStr) ?? Date().timeIntervalSince1970
                let date = Date(timeIntervalSince1970: timestamp)

                let email = Email(
                    id: id,
                    subject: subject,
                    sender: senderName,
                    senderEmail: senderEmail,
                    dateReceived: date,
                    body: subject, // Preview for now
                    isRead: false, // Assume unread for now
                    category: nil,
                    priority: nil,
                    aiSummary: nil,
                    actions: [],
                    senderReputation: nil
                )

                emails.append(email)
            }

            return emails.isEmpty ? nil : emails

        } catch {
            print("Error reading Mail database: \(error)")
            return nil
        }
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
