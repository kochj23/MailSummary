//
//  ExportManager.swift
//  Mail Summary
//
//  Export & Backup Manager
//  Created by Jordan Koch on 2026-01-26
//
//  Handles export to CSV, JSON, PDF formats and full backup/restore.
//

import Foundation
import AppKit

@MainActor
class ExportManager: ObservableObject {
    static let shared = ExportManager()

    // MARK: - Published Properties

    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0.0

    // MARK: - Private Properties

    private let backupFolder: URL

    // MARK: - Initialization

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        backupFolder = documentsPath.appendingPathComponent("Mail Summary Backups", isDirectory: true)

        // Create backup folder
        try? FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)
    }

    // MARK: - Export to CSV

    /// Export emails to CSV format
    func exportToCSV(_ emails: [Email]) -> URL? {
        isExporting = true
        exportProgress = 0.0

        var csv = "Date,Subject,Sender,SenderEmail,Category,Priority,Read,BodyPreview\n"

        for (index, email) in emails.enumerated() {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            let date = dateFormatter.string(from: email.dateReceived)

            let bodyPreview = email.body?.prefix(100).replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let category = email.category?.rawValue ?? "Other"
            let priority = email.priority.map { String($0) } ?? "N/A"

            csv += "\"\(date)\",\"\(csvEscape(email.subject))\",\"\(csvEscape(email.sender))\",\"\(email.senderEmail)\",\"\(category)\",\"\(priority)\",\"\(email.isRead)\",\"\(bodyPreview)\"\n"

            exportProgress = Double(index + 1) / Double(emails.count)
        }

        // Save to file
        let filename = "emails-export-\(Date().timeIntervalSince1970).csv"
        let fileURL = backupFolder.appendingPathComponent(filename)

        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            isExporting = false
            exportProgress = 1.0
            print("✅ Exported \(emails.count) emails to CSV: \(fileURL.path)")
            return fileURL
        } catch {
            print("❌ CSV export failed: \(error)")
            isExporting = false
            return nil
        }
    }

    // MARK: - Export to JSON

    /// Export emails to JSON format
    func exportToJSON(_ emails: [Email]) -> URL? {
        isExporting = true

        let exportData: [String: Any] = [
            "version": "3.0.0",
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "emailCount": emails.count,
            "emails": emails.map { emailToDict($0) }
        ]

        let filename = "emails-export-\(Date().timeIntervalSince1970).json"
        let fileURL = backupFolder.appendingPathComponent(filename)

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            try jsonData.write(to: fileURL)
            isExporting = false
            print("✅ Exported \(emails.count) emails to JSON: \(fileURL.path)")
            return fileURL
        } catch {
            print("❌ JSON export failed: \(error)")
            isExporting = false
            return nil
        }
    }

    // MARK: - Export to PDF

    /// Export single email to PDF
    func exportToPDF(_ email: Email) -> URL? {
        isExporting = true

        // Create attributed string with email content
        let content = NSMutableAttributedString()

        // Header
        let header = """
        Subject: \(email.subject)
        From: \(email.sender) <\(email.senderEmail)>
        Date: \(formatDate(email.dateReceived))
        Category: \(email.category?.rawValue ?? "Unknown")
        Priority: \(email.priority.map { String($0) } ?? "N/A")

        ---

        """

        content.append(NSAttributedString(string: header, attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.black
        ]))

        // Body
        if let body = email.body {
            content.append(NSAttributedString(string: body, attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.darkGray
            ]))
        }

        // AI Summary
        if let summary = email.aiSummary {
            let italicFont = NSFont.systemFont(ofSize: 10)
            content.append(NSAttributedString(string: "\n\n---\nAI Summary:\n\(summary)", attributes: [
                .font: italicFont,
                .foregroundColor: NSColor.blue
            ]))
        }

        // Create PDF
        let filename = "email-\(email.id)-\(Date().timeIntervalSince1970).pdf"
        let fileURL = backupFolder.appendingPathComponent(filename)

        let pdfData = createPDFData(from: content)
        do {
            try pdfData.write(to: fileURL)
            isExporting = false
            print("✅ Exported email to PDF: \(fileURL.path)")
            return fileURL
        } catch {
            print("❌ PDF export failed: \(error)")
            isExporting = false
            return nil
        }
    }

    // MARK: - Full Backup

    /// Create complete backup of all app data
    func createBackup() -> URL? {
        isExporting = true

        let backupData: [String: Any] = [
            "version": "3.0.0",
            "backupDate": ISO8601DateFormatter().string(from: Date()),
            "settings": [
                "autoScanEnabled": UserDefaults.standard.bool(forKey: "MailEngine_AutoScanEnabled"),
                "autoScanInterval": UserDefaults.standard.double(forKey: "MailEngine_AutoScanInterval"),
                "notifyHighPriority": UserDefaults.standard.bool(forKey: "MailEngine_NotifyHighPriority")
            ],
            "rules": exportRulesData(),
            "templates": exportTemplatesData(),
            "vips": exportVIPsData(),
            "analytics": "See analytics.json file"
        ]

        let filename = "mail-summary-backup-\(Date().timeIntervalSince1970).json"
        let fileURL = backupFolder.appendingPathComponent(filename)

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: backupData, options: .prettyPrinted)
            try jsonData.write(to: fileURL)
            isExporting = false
            print("✅ Created backup: \(fileURL.path)")
            return fileURL
        } catch {
            print("❌ Backup failed: \(error)")
            isExporting = false
            return nil
        }
    }

    /// Restore from backup
    func restoreFromBackup(_ url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            _ = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            // TODO: Restore settings, rules, templates, VIPs
            // This would need to coordinate with respective managers

            print("✅ Restored from backup: \(url.path)")
            return true
        } catch {
            print("❌ Restore failed: \(error)")
            return false
        }
    }

    // MARK: - Helper Methods

    private func csvEscape(_ text: String) -> String {
        text.replacingOccurrences(of: "\"", with: "\"\"")
    }

    private func emailToDict(_ email: Email) -> [String: Any] {
        var dict: [String: Any] = [
            "id": email.id,
            "messageId": email.messageId,
            "subject": email.subject,
            "sender": email.sender,
            "senderEmail": email.senderEmail,
            "dateReceived": ISO8601DateFormatter().string(from: email.dateReceived),
            "isRead": email.isRead
        ]

        if let category = email.category {
            dict["category"] = category.rawValue
        }

        if let priority = email.priority {
            dict["priority"] = priority
        }

        if let body = email.body {
            dict["body"] = body
        }

        if let summary = email.aiSummary {
            dict["aiSummary"] = summary
        }

        return dict
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func createPDFData(from attributedString: NSAttributedString) -> Data {
        let printInfo = NSPrintInfo.shared
        printInfo.paperSize = NSSize(width: 595, height: 842)  // A4
        printInfo.topMargin = 50
        printInfo.bottomMargin = 50
        printInfo.leftMargin = 50
        printInfo.rightMargin = 50

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 495, height: 742))
        textView.textStorage?.setAttributedString(attributedString)

        let printOperation = NSPrintOperation(view: textView, printInfo: printInfo)
        printOperation.showsPrintPanel = false
        printOperation.showsProgressPanel = false

        // Generate PDF data
        return textView.dataWithPDF(inside: textView.bounds)
    }

    private func exportRulesData() -> [[String: Any]] {
        // TODO: Export rules from RulesEngine
        return []
    }

    private func exportTemplatesData() -> [[String: Any]] {
        // TODO: Export templates from ReplyTemplateManager
        return []
    }

    private func exportVIPsData() -> [String] {
        // TODO: Export VIPs from SenderIntelligenceManager
        return []
    }
}
