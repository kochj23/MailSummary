//
//  EmailActionManager.swift
//  Mail Summary
//
//  Performs email actions via AppleScript (delete, archive, mark read/unread, reply, forward, move)
//  Created by Jordan Koch on 2026-01-23
//

import Foundation
import AppKit

@MainActor
class EmailActionManager {
    static let shared = EmailActionManager()

    private init() {}

    // MARK: - Public API

    /// Perform an action on an email
    func performAction(_ action: EmailActionType, on email: Email) async -> EmailActionResult {
        guard isMailAppRunning() else {
            return .failure("Mail.app is not running. Please open Mail.app and try again.")
        }

        switch action {
        case .delete:
            return await deleteEmail(messageId: email.messageId)
        case .archive:
            return await archiveEmail(messageId: email.messageId)
        case .markRead:
            return await markAsRead(messageId: email.messageId, read: true)
        case .markUnread:
            return await markAsRead(messageId: email.messageId, read: false)
        case .toggleRead:
            return await markAsRead(messageId: email.messageId, read: !email.isRead)
        case .reply:
            return await createReplyDraft(messageId: email.messageId)
        case .forward:
            return await createForwardDraft(messageId: email.messageId)
        case .move(let mailbox):
            return await moveEmail(messageId: email.messageId, to: mailbox)
        }
    }

    // MARK: - Email Actions

    /// Delete email (moves to Trash) - 100-200ms
    private func deleteEmail(messageId: String) async -> EmailActionResult {
        let script = """
        tell application "Mail"
            try
                set msg to first message whose id is \(messageId)
                delete msg
                return "SUCCESS"
            on error errMsg
                return "ERROR: " & errMsg
            end try
        end tell
        """

        let result = await executeAppleScript(script, timeout: 5.0)

        if result.hasPrefix("ERROR") {
            return .failure("Failed to delete email: \(result.replacingOccurrences(of: "ERROR: ", with: ""))")
        }

        return .success
    }

    /// Archive email (move to Archive mailbox with fallback) - 100-200ms
    private func archiveEmail(messageId: String) async -> EmailActionResult {
        let script = """
        tell application "Mail"
            try
                set msg to first message whose id is \(messageId)

                -- Try Archive mailbox first
                try
                    move msg to mailbox "Archive"
                    return "SUCCESS"
                on error
                    -- Try [Gmail]/All Mail as fallback
                    try
                        move msg to mailbox "[Gmail]/All Mail"
                        return "SUCCESS"
                    on error
                        -- Try All Mail without [Gmail] prefix
                        try
                            move msg to mailbox "All Mail"
                            return "SUCCESS"
                        on error
                            return "ERROR: No Archive mailbox found"
                        end try
                    end try
                end try
            on error errMsg
                return "ERROR: " & errMsg
            end try
        end tell
        """

        let result = await executeAppleScript(script, timeout: 5.0)

        if result.hasPrefix("ERROR") {
            return .failure("Failed to archive email: \(result.replacingOccurrences(of: "ERROR: ", with: ""))")
        }

        return .success
    }

    /// Mark email as read or unread - 100-150ms
    private func markAsRead(messageId: String, read: Bool) async -> EmailActionResult {
        let script = """
        tell application "Mail"
            try
                set msg to first message whose id is \(messageId)
                set read status of msg to \(read)
                return "SUCCESS"
            on error errMsg
                return "ERROR: " & errMsg
            end try
        end tell
        """

        let result = await executeAppleScript(script, timeout: 5.0)

        if result.hasPrefix("ERROR") {
            return .failure("Failed to mark email: \(result.replacingOccurrences(of: "ERROR: ", with: ""))")
        }

        return .success
    }

    /// Create reply draft and open in Mail.app - 500-1500ms
    private func createReplyDraft(messageId: String) async -> EmailActionResult {
        let script = """
        tell application "Mail"
            try
                set msg to first message whose id is \(messageId)
                set replyMsg to reply msg with opening window
                return "SUCCESS"
            on error errMsg
                return "ERROR: " & errMsg
            end try
        end tell
        """

        let result = await executeAppleScript(script, timeout: 10.0)

        if result.hasPrefix("ERROR") {
            return .failure("Failed to create reply: \(result.replacingOccurrences(of: "ERROR: ", with: ""))")
        }

        return .success
    }

    /// Create forward draft and open in Mail.app - 500-1500ms
    private func createForwardDraft(messageId: String) async -> EmailActionResult {
        let script = """
        tell application "Mail"
            try
                set msg to first message whose id is \(messageId)
                set fwdMsg to forward msg with opening window
                return "SUCCESS"
            on error errMsg
                return "ERROR: " & errMsg
            end try
        end tell
        """

        let result = await executeAppleScript(script, timeout: 10.0)

        if result.hasPrefix("ERROR") {
            return .failure("Failed to create forward: \(result.replacingOccurrences(of: "ERROR: ", with: ""))")
        }

        return .success
    }

    /// Move email to specific mailbox - 100-200ms
    private func moveEmail(messageId: String, to mailbox: String) async -> EmailActionResult {
        let script = """
        tell application "Mail"
            try
                set msg to first message whose id is \(messageId)
                move msg to mailbox "\(mailbox)"
                return "SUCCESS"
            on error errMsg
                return "ERROR: " & errMsg
            end try
        end tell
        """

        let result = await executeAppleScript(script, timeout: 5.0)

        if result.hasPrefix("ERROR") {
            return .failure("Failed to move email: \(result.replacingOccurrences(of: "ERROR: ", with: ""))")
        }

        return .success
    }

    // MARK: - AppleScript Execution

    /// Execute AppleScript with timeout protection (same pattern as MailParser)
    private func executeAppleScript(_ script: String, timeout: TimeInterval) async -> String {
        return await withCheckedContinuation { continuation in
            Task.detached {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                var timedOut = false
                var processCompleted = false

                process.terminationHandler = { _ in
                    processCompleted = true
                }

                do {
                    try process.run()

                    // Start timeout timer
                    Task.detached {
                        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                        if !processCompleted {
                            timedOut = true
                            print("⏱️ AppleScript timed out after \(timeout)s - terminating...")
                            process.terminate()
                        }
                    }

                    process.waitUntilExit()

                    if timedOut {
                        continuation.resume(returning: "ERROR: Operation timed out")
                        return
                    }

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    continuation.resume(returning: output)

                } catch {
                    continuation.resume(returning: "ERROR: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Check if Mail.app is running
    private func isMailAppRunning() -> Bool {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        return runningApps.contains { $0.bundleIdentifier == "com.apple.mail" }
    }
}
