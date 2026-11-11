//
//  ReplyTemplateManager.swift
//  Mail Summary
//
//  Quick Reply Templates - Business Logic
//  Created by Jordan Koch on 2026-01-26
//
//  Manages reply templates with variable substitution and AI enhancement.
//

import Foundation
import NovaAIKit

@MainActor
class ReplyTemplateManager: ObservableObject {
    static let shared = ReplyTemplateManager()

    // MARK: - Published Properties

    @Published var templates: [ReplyTemplate] = []

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private let templatesKey = "MailSummary_ReplyTemplates"
    private var ai: NovaAI { AppAI.shared }

    // MARK: - Initialization

    private init() {
        loadTemplates()
    }

    // MARK: - Template Management

    func addTemplate(_ template: ReplyTemplate) {
        templates.append(template)
        saveTemplates()
    }

    func updateTemplate(_ template: ReplyTemplate) {
        guard let index = templates.firstIndex(where: { $0.id == template.id }) else { return }
        templates[index] = template
        saveTemplates()
    }

    func deleteTemplate(_ templateId: UUID) {
        templates.removeAll { $0.id == templateId }
        saveTemplates()
    }

    /// Record template usage
    func recordTemplateUsed(_ templateId: UUID) {
        guard let index = templates.firstIndex(where: { $0.id == templateId }) else { return }
        templates[index].useCount += 1
        templates[index].lastUsed = Date()
        saveTemplates()
    }

    // MARK: - Template Suggestion

    /// Suggest templates for a specific email
    func suggestTemplates(for email: Email) -> [ReplyTemplate] {
        var suggested: [ReplyTemplate] = []

        // Match by category
        if let category = email.category {
            let categoryTemplates = templates.filter { $0.category?.lowercased() == category.rawValue.lowercased() }
            suggested.append(contentsOf: categoryTemplates)
        }

        // Add general templates
        let generalTemplates = templates.filter { $0.category == nil }
        suggested.append(contentsOf: generalTemplates)

        // Sort by usage count
        suggested.sort { ($0.useCount, $0.lastUsed ?? Date.distantPast) > ($1.useCount, $1.lastUsed ?? Date.distantPast) }

        return Array(suggested.prefix(5))  // Top 5
    }

    // MARK: - Template Application

    /// Apply template to email with variable substitution
    func applyTemplate(_ template: ReplyTemplate, to email: Email) async -> (subject: String, body: String) {
        var subject = template.subject ?? "Re: \(email.subject)"
        var body = template.body

        // Substitute variables
        subject = substituteVariables(in: subject, for: email)
        body = substituteVariables(in: body, for: email)

        // AI enhancement if enabled
        if template.useAI, ai.isEnabled {
            body = await enhanceTemplateWithAI(body: body, email: email)
        }

        // Record usage
        recordTemplateUsed(template.id)

        return (subject, body)
    }

    /// Substitute template variables
    private func substituteVariables(in text: String, for email: Email) -> String {
        var result = text

        // Extract first name from sender
        let firstName = email.sender.components(separatedBy: " ").first ?? email.sender

        // Current date/time
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let dateStr = dateFormatter.string(from: Date())

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeStr = timeFormatter.string(from: Date())

        // Perform substitutions
        let substitutions: [String: String] = [
            "{{name}}": firstName,
            "{{fullName}}": email.sender,
            "{{email}}": email.senderEmail,
            "{{subject}}": email.subject,
            "{{date}}": dateStr,
            "{{time}}": timeStr,
            "{{myName}}": "Jordan Koch"
        ]

        for (variable, value) in substitutions {
            result = result.replacingOccurrences(of: variable, with: value)
        }

        return result
    }

    /// Enhance template with AI customization
    private func enhanceTemplateWithAI(body: String, email: Email) async -> String {
        let prompt = """
        Customize this email reply template to better match the context of the original email.
        Keep the same tone and structure, but make it more specific and relevant.

        Original Email:
        Subject: \(email.subject)
        From: \(email.sender)
        Body Preview: \(email.body?.prefix(200).description ?? "")

        Template Reply:
        \(body)

        Customized Reply (maintain professional tone, keep it concise):
        """

        let request = NovaAIRequest(
            prompt: prompt,
            system: "You are an email assistant helping customize reply templates. Keep replies professional and concise.",
            temperature: 0.7,
            maxTokens: 400
        )
        // Built-in: the template with its variables filled in.
        return await ai.text(request, validate: { try Self.validateReply($0) }, fallback: { body }).value
    }

    /// Reply text: non-empty, plain, at most 2000 characters, and no unfilled {{variables}}.
    nonisolated static func validateReply(_ text: String) throws -> String {
        let plain = NovaAIText.plain(try NovaAI.nonEmpty(text), max: 2000)
        guard !plain.isEmpty else { throw NovaAIValidationError("empty reply") }
        guard !plain.contains("{{") else { throw NovaAIValidationError("leave no {{placeholders}} in the reply") }
        return plain
    }

    /// Built-in smart reply: a short, polite acknowledgement addressed to the sender's first name.
    nonisolated static func basicSmartReply(sender: String, subject: String) -> String {
        let firstName = sender.split(separator: " ").first.map(String.init) ?? sender
        let greeting = firstName.isEmpty ? "Hi," : "Hi \(firstName),"
        return "\(greeting)\n\nThanks for your email about \"\(subject)\". I've received it and will follow up shortly.\n\nBest regards"
    }

    /// Generate smart reply using AI
    func generateSmartReply(for email: Email) async -> String? {
        guard let body = email.body else {
            return nil
        }
        let fallback = Self.basicSmartReply(sender: email.sender, subject: email.subject)

        let prompt = """
        Generate a professional, concise reply to this email.

        Original Email:
        Subject: \(email.subject)
        From: \(email.sender)
        Body: \(body.prefix(500))

        Generate a reply that:
        1. Acknowledges the email
        2. Addresses key points if any
        3. Is professional and friendly
        4. Is concise (2-4 sentences)

        Reply:
        """

        let request = NovaAIRequest(
            prompt: prompt,
            system: "You are a professional email assistant. Generate concise, professional replies.",
            temperature: 0.7,
            maxTokens: 300
        )
        return await ai.text(request, validate: { try Self.validateReply($0) }, fallback: { fallback }).value
    }

    // MARK: - Persistence

    private func saveTemplates() {
        if let encoded = try? JSONEncoder().encode(templates) {
            userDefaults.set(encoded, forKey: templatesKey)
        }
    }

    private func loadTemplates() {
        if let data = userDefaults.data(forKey: templatesKey),
           let decoded = try? JSONDecoder().decode([ReplyTemplate].self, from: data) {
            templates = decoded
        } else {
            // Load default templates
            templates = ReplyTemplate.defaultTemplates
            saveTemplates()
        }
    }
}
