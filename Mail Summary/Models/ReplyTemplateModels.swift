//
//  ReplyTemplateModels.swift
//  Mail Summary
//
//  Quick Reply Templates - Data Models
//  Created by Jordan Koch on 2026-01-26
//
//  Defines structures for quick reply templates with variable substitution.
//

import Foundation

// MARK: - Reply Template

struct ReplyTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var subject: String?  // Optional subject override
    var body: String
    var category: String?  // Suggest for specific category
    var useAI: Bool  // Use AI to customize template
    var createdAt: Date
    var lastUsed: Date?
    var useCount: Int

    init(id: UUID = UUID(), name: String, subject: String? = nil, body: String, category: String? = nil, useAI: Bool = false) {
        self.id = id
        self.name = name
        self.subject = subject
        self.body = body
        self.category = category
        self.useAI = useAI
        self.createdAt = Date()
        self.lastUsed = nil
        self.useCount = 0
    }

    /// Available template variables
    static let variables = [
        "{{name}}": "Sender's first name",
        "{{fullName}}": "Sender's full name",
        "{{email}}": "Sender's email address",
        "{{subject}}": "Original email subject",
        "{{date}}": "Current date",
        "{{time}}": "Current time",
        "{{myName}}": "Your name (Jordan Koch)"
    ]

    /// Check if template contains variables
    var hasVariables: Bool {
        body.contains("{{") && body.contains("}}")
    }
}

// MARK: - Default Templates

extension ReplyTemplate {
    static let defaultTemplates: [ReplyTemplate] = [
        ReplyTemplate(
            name: "Quick Acknowledgment",
            subject: nil,
            body: """
            Hi {{name}},

            Thanks for your email. I've received it and will get back to you shortly.

            Best regards,
            {{myName}}
            """,
            category: nil,
            useAI: false
        ),

        ReplyTemplate(
            name: "Need More Time",
            subject: "Re: {{subject}}",
            body: """
            Hi {{name}},

            Thank you for reaching out regarding {{subject}}. I need a bit more time to review this properly.

            I'll get back to you by {{date}}.

            Best,
            {{myName}}
            """,
            category: nil,
            useAI: true
        ),

        ReplyTemplate(
            name: "Out of Office",
            subject: "Out of Office: {{subject}}",
            body: """
            Hi {{name}},

            I'm currently out of the office and will have limited access to email.

            I'll respond to your message when I return.

            Thanks,
            {{myName}}
            """,
            category: nil,
            useAI: false
        ),

        ReplyTemplate(
            name: "Meeting Confirmation",
            subject: "Re: {{subject}}",
            body: """
            Hi {{name}},

            I can confirm the meeting. Looking forward to it.

            See you then!

            {{myName}}
            """,
            category: "Work",
            useAI: false
        ),

        ReplyTemplate(
            name: "Bill Payment Confirmation",
            subject: "Payment Confirmation",
            body: """
            Hello,

            I've processed the payment as requested.

            Please confirm receipt.

            Thank you,
            {{myName}}
            """,
            category: "Bills",
            useAI: false
        )
    ]
}
