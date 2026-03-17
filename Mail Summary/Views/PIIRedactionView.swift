//
//  PIIRedactionView.swift
//  Mail Summary
//
//  UI for PII detection and redaction
//  Created by Jordan Koch on 2026-01-30.
//

import SwiftUI

struct PIIRedactionView: View {
    @EnvironmentObject var mailEngine: MailEngine
    @ObservedObject var piiManager = PIIRedactionManager.shared

    @State private var selectedEmail: Email?
    @State private var showAddPatternSheet = false
    @State private var newPatternName = ""
    @State private var newPatternRegex = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            HSplitView {
                // Left: Settings & Email List
                leftPanel
                    .frame(minWidth: 300, maxWidth: 400)

                // Right: PII Details
                rightPanel
                    .frame(minWidth: 400)
            }
        }
        .navigationTitle("PII Redaction")
        .sheet(isPresented: $showAddPatternSheet) {
            addPatternSheet
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("PII Detection & Redaction")
                    .font(.title2.bold())

                if piiManager.totalPIIFound > 0 {
                    Text("\(piiManager.totalPIIFound) PII instances found")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            // Scan button
            if piiManager.isScanning {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button("Scan All Emails") {
                    Task {
                        await piiManager.scanEmails(mailEngine.emails)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(mailEngine.emails.isEmpty)
            }
        }
        .padding()
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(spacing: 0) {
            // PII Type Settings
            piiTypeSettings

            Divider()

            // Custom Patterns
            customPatternsSection

            Divider()

            // Email List with PII counts
            emailList
        }
    }

    private var piiTypeSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detection Types")
                .font(.headline)

            ForEach(PIIType.allCases.filter { $0 != .custom }, id: \.self) { type in
                Toggle(isOn: Binding(
                    get: { piiManager.enabledTypes.contains(type) },
                    set: { isOn in
                        if isOn {
                            piiManager.enabledTypes.insert(type)
                        } else {
                            piiManager.enabledTypes.remove(type)
                        }
                    }
                )) {
                    HStack {
                        Image(systemName: type.icon)
                            .frame(width: 20)
                        VStack(alignment: .leading) {
                            Text(type.rawValue)
                            Text(type.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .toggleStyle(.checkbox)
            }
        }
        .padding()
    }

    private var customPatternsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Custom Patterns")
                    .font(.headline)
                Spacer()
                Button(action: { showAddPatternSheet = true }) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }

            if piiManager.customPatterns.isEmpty {
                Text("No custom patterns defined")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(piiManager.customPatterns) { pattern in
                    HStack {
                        Toggle(isOn: Binding(
                            get: { pattern.isEnabled },
                            set: { _ in piiManager.toggleCustomPattern(id: pattern.id) }
                        )) {
                            Text(pattern.name)
                                .font(.subheadline)
                        }
                        .toggleStyle(.checkbox)

                        Spacer()

                        Button(action: { piiManager.removeCustomPattern(id: pattern.id) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
    }

    private var emailList: some View {
        List(selection: $selectedEmail) {
            ForEach(mailEngine.emails) { email in
                PIIEmailRow(email: email, piiResult: piiManager.lastScanResults[email.id])
                    .tag(email)
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        Group {
            if let email = selectedEmail {
                PIIDetailView(email: email)
            } else {
                VStack {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select an email to view PII details")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Add Pattern Sheet

    private var addPatternSheet: some View {
        VStack(spacing: 16) {
            Text("Add Custom PII Pattern")
                .font(.headline)

            TextField("Pattern Name", text: $newPatternName)
                .textFieldStyle(.roundedBorder)

            TextField("Regex Pattern", text: $newPatternRegex)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            // Validation status
            if !newPatternRegex.isEmpty {
                if isValidRegex(newPatternRegex) {
                    Label("Valid regex", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Label("Invalid regex", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }

            HStack {
                Button("Cancel") {
                    showAddPatternSheet = false
                    newPatternName = ""
                    newPatternRegex = ""
                }

                Spacer()

                Button("Add") {
                    piiManager.addCustomPattern(name: newPatternName, pattern: newPatternRegex)
                    showAddPatternSheet = false
                    newPatternName = ""
                    newPatternRegex = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(newPatternName.isEmpty || newPatternRegex.isEmpty || !isValidRegex(newPatternRegex))
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func isValidRegex(_ pattern: String) -> Bool {
        do {
            _ = try NSRegularExpression(pattern: pattern, options: [])
            return true
        } catch {
            return false
        }
    }
}

// MARK: - PII Email Row

struct PIIEmailRow: View {
    let email: Email
    let piiResult: PIIScanResult?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(email.subject)
                    .lineLimit(1)

                Text(email.sender)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let result = piiResult {
                if result.hasPII {
                    Label("\(result.piiCount)", systemImage: "exclamationmark.shield.fill")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                } else {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                }
            } else {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - PII Detail View

struct PIIDetailView: View {
    let email: Email
    @ObservedObject var piiManager = PIIRedactionManager.shared

    @State private var showRedacted = false

    private var scanResult: PIIScanResult? {
        piiManager.lastScanResults[email.id]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("PII Analysis")
                        .font(.headline)

                    Spacer()

                    Toggle("Show Redacted", isOn: $showRedacted)
                        .toggleStyle(.switch)
                }

                if let result = scanResult {
                    // PII Summary
                    HStack(spacing: 16) {
                        ForEach(Array(result.countByType.sorted { $0.value > $1.value }), id: \.key) { type, count in
                            HStack(spacing: 4) {
                                Image(systemName: type.icon)
                                Text("\(count)")
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                        }
                    }
                }
            }
            .padding()

            Divider()

            if let result = scanResult {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Subject
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Subject")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)

                            if showRedacted {
                                let redacted = piiManager.getRedactedEmail(email)
                                Text(redacted.subject)
                                    .textSelection(.enabled)
                            } else {
                                Text(email.subject)
                                    .textSelection(.enabled)
                            }
                        }

                        Divider()

                        // Body
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Body")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)

                            if showRedacted {
                                let redacted = piiManager.getRedactedEmail(email)
                                Text(redacted.body ?? "[No body]")
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            } else {
                                Text(email.body ?? "[No body]")
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }

                        Divider()

                        // PII Matches List
                        if !result.matches.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Detected PII (\(result.piiCount))")
                                    .font(.headline)

                                ForEach(result.matches) { match in
                                    HStack {
                                        Image(systemName: match.type.icon)
                                            .foregroundColor(.orange)
                                            .frame(width: 20)

                                        VStack(alignment: .leading) {
                                            Text(match.type.rawValue)
                                                .font(.caption.bold())
                                            Text(match.displayText)
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Text("\(Int(match.confidence * 100))%")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(8)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(4)
                                }
                            }
                        }
                    }
                    .padding()
                }
            } else {
                VStack {
                    Spacer()
                    Text("Email not scanned yet")
                        .foregroundColor(.secondary)
                    Button("Scan Now") {
                        _ = piiManager.scanEmail(email)
                    }
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PIIRedactionView()
        .environmentObject(MailEngine())
}
