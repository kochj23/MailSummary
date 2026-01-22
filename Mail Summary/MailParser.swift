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
        guard let dbPath = MailParser.findEnvelopeDatabase() else {
            print("Mail database not found")
            return []
        }

        var emails: [Email] = []

        // Open SQLite database
        // TODO: Implement SQLite parsing
        // For now, return sample data for UI development

        return sampleEmails()
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
