//
//  ReplyTemplatePickerView.swift
//  Mail Summary
//
//  Quick Reply Template Picker
//  Created by Jordan Koch on 2026-01-26
//
//  Template selection and preview for quick replies.
//

import SwiftUI

struct ReplyTemplatePickerView: View {
    @ObservedObject var templateManager = ReplyTemplateManager.shared
    let email: Email
    let onSelect: (String, String) -> Void  // (subject, body)
    let onCancel: () -> Void

    @State private var selectedTemplate: ReplyTemplate?
    @State private var previewSubject: String = ""
    @State private var previewBody: String = ""
    @State private var isGenerating: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            HStack(spacing: 0) {
                // Template List (Left)
                templateListView
                    .frame(width: 300)

                Divider()

                // Preview (Right)
                previewView
            }

            Divider()

            // Actions
            actionsView
        }
        .frame(width: 800, height: 600)
        .background(Color.black)
        .onAppear {
            generatePreviews()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("📝 Quick Reply")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Replying to: \(email.sender)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
                .keyboardShortcut(.escape)
        }
        .padding()
    }

    // MARK: - Template List

    private var templateListView: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Suggested templates
                let suggested = templateManager.suggestTemplates(for: email)

                if !suggested.isEmpty {
                    Text("SUGGESTED")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top)
                }

                ForEach(suggested) { template in
                    TemplateCard(
                        template: template,
                        isSelected: selectedTemplate?.id == template.id,
                        onSelect: {
                            selectedTemplate = template
                            generatePreview(for: template)
                        }
                    )
                }

                // All templates
                if suggested.count < templateManager.templates.count {
                    Text("ALL TEMPLATES")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top)

                    ForEach(templateManager.templates) { template in
                        if !suggested.contains(where: { $0.id == template.id }) {
                            TemplateCard(
                                template: template,
                                isSelected: selectedTemplate?.id == template.id,
                                onSelect: {
                                    selectedTemplate = template
                                    generatePreview(for: template)
                                }
                            )
                        }
                    }
                }

                // AI Smart Reply
                Divider()
                    .padding(.vertical, 8)

                SmartReplyCard(isGenerating: isGenerating, onGenerate: generateSmartReply)
            }
            .padding()
        }
        .background(Color.gray.opacity(0.05))
    }

    // MARK: - Preview

    private var previewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if selectedTemplate == nil && previewSubject.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)

                        Text("Select a template to preview")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Subject
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SUBJECT")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)

                        TextField("Subject", text: $previewSubject)
                            .textFieldStyle(.plain)
                            .font(.headline)
                            .foregroundColor(.white)
                    }

                    Divider()

                    // Body
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BODY")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)

                        TextEditor(text: $previewBody)
                            .font(.body)
                            .foregroundColor(.white)
                            .frame(minHeight: 300)
                            .scrollContentBackground(.hidden)
                    }

                    // Variables info
                    if selectedTemplate?.hasVariables == true {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("VARIABLES")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)

                            ForEach(Array(ReplyTemplate.variables.keys.sorted()), id: \.self) { variable in
                                HStack {
                                    Text(variable)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.cyan)

                                    Text(ReplyTemplate.variables[variable] ?? "")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Actions

    private var actionsView: some View {
        HStack {
            if selectedTemplate?.useAI == true {
                Label("AI Enhanced", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundColor(.purple)
            }

            Spacer()

            Button("Cancel", action: onCancel)
                .buttonStyle(.bordered)

            Button("Use Reply") {
                onSelect(previewSubject, previewBody)
            }
            .buttonStyle(.borderedProminent)
            .disabled(previewSubject.isEmpty || previewBody.isEmpty)
        }
        .padding()
    }

    // MARK: - Generate Previews

    private func generatePreviews() {
        // Auto-select first suggested template
        let suggested = templateManager.suggestTemplates(for: email)
        if let first = suggested.first {
            selectedTemplate = first
            generatePreview(for: first)
        }
    }

    private func generatePreview(for template: ReplyTemplate) {
        isGenerating = true

        Task {
            let result = await templateManager.applyTemplate(template, to: email)
            previewSubject = result.subject
            previewBody = result.body
            isGenerating = false
        }
    }

    private func generateSmartReply() {
        isGenerating = true
        selectedTemplate = nil

        Task {
            if let reply = await templateManager.generateSmartReply(for: email) {
                previewSubject = "Re: \(email.subject)"
                previewBody = reply
            }
            isGenerating = false
        }
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: ReplyTemplate
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(template.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Spacer()

                    if template.useAI {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }

                if let category = template.category {
                    Text(category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }

                if template.useCount > 0 {
                    Text("Used \(template.useCount) time\(template.useCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(isSelected ? Color.cyan.opacity(0.2) : Color.gray.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Smart Reply Card

struct SmartReplyCard: View {
    let isGenerating: Bool
    let onGenerate: () -> Void

    var body: some View {
        Button(action: onGenerate) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)

                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Smart Reply")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Text("Generate custom reply with AI")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.purple, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
    }
}

// MARK: - Preview

#if DEBUG
struct ReplyTemplatePickerView_Previews: PreviewProvider {
    static var previews: some View {
        ReplyTemplatePickerView(
            email: Email(
                id: 1,
                messageId: "123",
                subject: "Test Email",
                sender: "John Doe",
                senderEmail: "john@example.com",
                dateReceived: Date(),
                isRead: false,
                actions: []
            ),
            onSelect: { _, _ in },
            onCancel: {}
        )
    }
}
#endif
