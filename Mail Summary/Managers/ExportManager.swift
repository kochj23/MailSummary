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

    // MARK: - Export to Markdown

    /// Export emails to Markdown format (great for documentation)
    func exportToMarkdown(_ emails: [Email]) -> URL? {
        isExporting = true
        exportProgress = 0.0

        var markdown = "# Email Export\n\n"
        markdown += "**Export Date:** \(formatDate(Date()))\n"
        markdown += "**Total Emails:** \(emails.count)\n\n"
        markdown += "---\n\n"

        for (index, email) in emails.enumerated() {
            markdown += "## \(email.subject)\n\n"
            markdown += "| Field | Value |\n"
            markdown += "|-------|-------|\n"
            markdown += "| **From** | \(email.sender) <\(email.senderEmail)> |\n"
            markdown += "| **Date** | \(formatDate(email.dateReceived)) |\n"
            markdown += "| **Category** | \(email.category?.rawValue ?? "Unknown") |\n"
            markdown += "| **Priority** | \(email.priority.map { String($0) } ?? "N/A") |\n"
            markdown += "| **Read** | \(email.isRead ? "Yes" : "No") |\n\n"

            if let summary = email.aiSummary {
                markdown += "> **AI Summary:** \(summary)\n\n"
            }

            if let body = email.body {
                markdown += "### Body\n\n"
                markdown += "```\n\(body)\n```\n\n"
            }

            markdown += "---\n\n"
            exportProgress = Double(index + 1) / Double(emails.count)
        }

        let filename = "emails-export-\(Date().timeIntervalSince1970).md"
        let fileURL = backupFolder.appendingPathComponent(filename)

        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            isExporting = false
            #if DEBUG
            print("Exported \(emails.count) emails to Markdown: \(fileURL.path)")
            #endif
            return fileURL
        } catch {
            #if DEBUG
            print("Markdown export failed: \(error)")
            #endif
            isExporting = false
            return nil
        }
    }

    // MARK: - Export to vCard

    /// Export unique senders as vCard contacts
    func exportToVCard(_ emails: [Email]) -> URL? {
        isExporting = true

        // Extract unique senders
        var uniqueSenders: [String: (name: String, email: String)] = [:]
        for email in emails {
            if uniqueSenders[email.senderEmail] == nil {
                uniqueSenders[email.senderEmail] = (name: email.sender, email: email.senderEmail)
            }
        }

        var vcard = ""
        for (_, sender) in uniqueSenders {
            vcard += "BEGIN:VCARD\n"
            vcard += "VERSION:3.0\n"
            vcard += "FN:\(sender.name)\n"
            vcard += "EMAIL;TYPE=INTERNET:\(sender.email)\n"
            vcard += "END:VCARD\n"
        }

        let filename = "contacts-export-\(Date().timeIntervalSince1970).vcf"
        let fileURL = backupFolder.appendingPathComponent(filename)

        do {
            try vcard.write(to: fileURL, atomically: true, encoding: .utf8)
            isExporting = false
            #if DEBUG
            print("Exported \(uniqueSenders.count) contacts to vCard: \(fileURL.path)")
            #endif
            return fileURL
        } catch {
            #if DEBUG
            print("vCard export failed: \(error)")
            #endif
            isExporting = false
            return nil
        }
    }

    // MARK: - Export to EML

    /// Export single email to standard EML format
    func exportToEML(_ email: Email) -> URL? {
        isExporting = true

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        let dateString = dateFormatter.string(from: email.dateReceived)

        var eml = """
        From: \(email.sender) <\(email.senderEmail)>
        Subject: \(email.subject)
        Date: \(dateString)
        Message-ID: <\(email.messageId)@local>
        MIME-Version: 1.0
        Content-Type: text/plain; charset=utf-8

        \(email.body ?? "")
        """

        let filename = "email-\(email.id)-\(Date().timeIntervalSince1970).eml"
        let fileURL = backupFolder.appendingPathComponent(filename)

        do {
            try eml.write(to: fileURL, atomically: true, encoding: .utf8)
            isExporting = false
            #if DEBUG
            print("Exported email to EML: \(fileURL.path)")
            #endif
            return fileURL
        } catch {
            #if DEBUG
            print("EML export failed: \(error)")
            #endif
            isExporting = false
            return nil
        }
    }

    /// Export multiple emails to EML files in a folder
    func exportMultipleToEML(_ emails: [Email]) -> URL? {
        isExporting = true
        exportProgress = 0.0

        let folderName = "eml-export-\(Date().timeIntervalSince1970)"
        let folderURL = backupFolder.appendingPathComponent(folderName, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

            for (index, email) in emails.enumerated() {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
                let dateString = dateFormatter.string(from: email.dateReceived)

                let eml = """
                From: \(email.sender) <\(email.senderEmail)>
                Subject: \(email.subject)
                Date: \(dateString)
                Message-ID: <\(email.messageId)@local>
                MIME-Version: 1.0
                Content-Type: text/plain; charset=utf-8

                \(email.body ?? "")
                """

                let filename = "\(index + 1)-\(sanitizeFilename(email.subject)).eml"
                let fileURL = folderURL.appendingPathComponent(filename)
                try eml.write(to: fileURL, atomically: true, encoding: .utf8)

                exportProgress = Double(index + 1) / Double(emails.count)
            }

            isExporting = false
            #if DEBUG
            print("Exported \(emails.count) emails to EML folder: \(folderURL.path)")
            #endif
            return folderURL
        } catch {
            #if DEBUG
            print("EML batch export failed: \(error)")
            #endif
            isExporting = false
            return nil
        }
    }

    // MARK: - Export to RAG-Optimized JSON

    /// Export emails in RAG-optimized format (chunked for embeddings)
    func exportToRAGFormat(_ emails: [Email], chunkSize: Int = 500) -> URL? {
        isExporting = true
        exportProgress = 0.0

        var chunks: [[String: Any]] = []

        for (index, email) in emails.enumerated() {
            // Create document chunks from email content
            let fullText = """
            Subject: \(email.subject)
            From: \(email.sender) <\(email.senderEmail)>
            Date: \(formatDate(email.dateReceived))
            Category: \(email.category?.rawValue ?? "Unknown")

            \(email.body ?? "")
            """

            // Split into chunks of chunkSize characters
            let textChunks = splitIntoChunks(fullText, size: chunkSize)

            for (chunkIndex, chunk) in textChunks.enumerated() {
                let chunkData: [String: Any] = [
                    "id": "\(email.id)-\(chunkIndex)",
                    "source_email_id": email.id,
                    "source_message_id": email.messageId,
                    "chunk_index": chunkIndex,
                    "total_chunks": textChunks.count,
                    "content": chunk,
                    "metadata": [
                        "subject": email.subject,
                        "sender": email.sender,
                        "sender_email": email.senderEmail,
                        "date": ISO8601DateFormatter().string(from: email.dateReceived),
                        "category": email.category?.rawValue ?? "unknown",
                        "priority": email.priority ?? 5
                    ]
                ]
                chunks.append(chunkData)
            }

            exportProgress = Double(index + 1) / Double(emails.count)
        }

        let exportData: [String: Any] = [
            "format": "rag-optimized",
            "version": "1.0",
            "export_date": ISO8601DateFormatter().string(from: Date()),
            "chunk_size": chunkSize,
            "total_emails": emails.count,
            "total_chunks": chunks.count,
            "chunks": chunks
        ]

        let filename = "emails-rag-\(Date().timeIntervalSince1970).json"
        let fileURL = backupFolder.appendingPathComponent(filename)

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            try jsonData.write(to: fileURL)
            isExporting = false
            #if DEBUG
            print("Exported \(emails.count) emails (\(chunks.count) chunks) to RAG format: \(fileURL.path)")
            #endif
            return fileURL
        } catch {
            #if DEBUG
            print("RAG export failed: \(error)")
            #endif
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
            guard let backup = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }

            // Restore settings
            if let settings = backup["settings"] as? [String: Any] {
                for (key, value) in settings {
                    UserDefaults.standard.set(value, forKey: key)
                }
                print("✅ Restored settings")
            }

            // Restore rules
            if let rulesData = backup["rules"] as? [[String: Any]],
               let jsonData = try? JSONSerialization.data(withJSONObject: rulesData, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                _ = RulesEngine.shared.importRules(from: jsonString)
                #if DEBUG
                print("✅ Restored \(rulesData.count) rules")
                #endif
            }

            // Restore templates (manual restore not supported yet)
            // Templates must be recreated manually

            // Restore VIPs
            if let vips = backup["vips"] as? [String] {
                for vip in vips {
                    SenderIntelligenceManager.shared.addVIP(vip)
                }
                #if DEBUG
                print("✅ Restored \(vips.count) VIPs")
                #endif
            }

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
        let rules = RulesEngine.shared.rules
        return rules.map { rule in
            [
                "id": rule.id.uuidString,
                "name": rule.name,
                "isEnabled": rule.isEnabled,
                "conditions": rule.conditions.map { ["type": "\($0)"] },
                "actions": rule.actions.map { ["type": "\($0)"] }
            ]
        }
    }

    private func exportTemplatesData() -> [[String: Any]] {
        let templates = ReplyTemplateManager.shared.templates
        return templates.map { template in
            [
                "id": template.id.uuidString,
                "name": template.name,
                "subject": template.subject,
                "body": template.body,
                "category": template.category
            ]
        }
    }

    private func exportVIPsData() -> [String] {
        return Array(SenderIntelligenceManager.shared.vipSenders)
    }

    /// Sanitize filename for safe file system usage
    private func sanitizeFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        var sanitized = name.components(separatedBy: invalidChars).joined(separator: "_")
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.count > 50 {
            sanitized = String(sanitized.prefix(50))
        }
        return sanitized.isEmpty ? "untitled" : sanitized
    }

    /// Split text into chunks of specified size (for RAG export)
    private func splitIntoChunks(_ text: String, size: Int) -> [String] {
        var chunks: [String] = []
        var currentIndex = text.startIndex

        while currentIndex < text.endIndex {
            let endIndex = text.index(currentIndex, offsetBy: size, limitedBy: text.endIndex) ?? text.endIndex

            // Try to find a sentence or paragraph break near the end
            var actualEndIndex = endIndex
            if endIndex < text.endIndex {
                let searchStart = text.index(currentIndex, offsetBy: max(0, size - 100), limitedBy: text.endIndex) ?? currentIndex
                let searchRange = searchStart..<endIndex

                // Look for paragraph break first
                if let paragraphBreak = text.range(of: "\n\n", options: .backwards, range: searchRange) {
                    actualEndIndex = paragraphBreak.upperBound
                }
                // Then sentence break
                else if let sentenceBreak = text.range(of: ". ", options: .backwards, range: searchRange) {
                    actualEndIndex = sentenceBreak.upperBound
                }
            }

            let chunk = String(text[currentIndex..<actualEndIndex])
            if !chunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                chunks.append(chunk)
            }

            currentIndex = actualEndIndex
        }

        return chunks
    }

    /// Get export folder URL (for UI)
    var exportFolderURL: URL {
        return backupFolder
    }

    /// Open export folder in Finder
    func openExportFolder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: backupFolder.path)
    }
}
