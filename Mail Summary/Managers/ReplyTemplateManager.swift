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

@MainActor
class ReplyTemplateManager: ObservableObject {
    static let shared = ReplyTemplateManager()

    // MARK: - Published Properties

    @Published var templates: [ReplyTemplate] = []

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private let templatesKey = "MailSummary_ReplyTemplates"
    private let ai = AIBackendManager.shared

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
        if template.useAI, ai.activeBackend != nil {
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

        do {
            let enhanced = try await ai.generate(
                prompt: prompt,
                systemPrompt: "You are an email assistant helping customize reply templates. Keep replies professional and concise.",
                temperature: 0.7,
                maxTokens: 400
            )

            return enhanced.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("❌ AI template enhancement failed: \(error)")
            return body
        }
    }

    /// Generate smart reply using AI
    func generateSmartReply(for email: Email) async -> String? {
        guard ai.activeBackend != nil, let body = email.body else {
            return nil
        }

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

        do {
            let reply = try await ai.generate(
                prompt: prompt,
                systemPrompt: "You are a professional email assistant. Generate concise, professional replies.",
                temperature: 0.7,
                maxTokens: 300
            )

            return reply.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("❌ AI smart reply failed: \(error)")
            return nil
        }
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
