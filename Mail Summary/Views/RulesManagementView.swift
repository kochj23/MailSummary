//
//  RulesManagementView.swift
//  Mail Summary
//
//  Smart Rules Engine - UI
//  Created by Jordan Koch on 2026-01-26
//
//  User interface for creating, editing, and managing email rules.
//

import SwiftUI

struct RulesManagementView: View {
    @ObservedObject var rulesEngine = RulesEngine.shared
    @State private var showingRuleEditor = false
    @State private var editingRule: EmailRule?
    @State private var showingStatistics = false
    @State private var showingImportExport = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("📋 Email Rules")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                // Statistics button
                Button(action: { showingStatistics.toggle() }) {
                    Image(systemName: "chart.bar.fill")
                }
                .buttonStyle(.plain)
                .help("View Statistics")

                // Import/Export button
                Button(action: { showingImportExport.toggle() }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .help("Import/Export Rules")

                // Add Rule button
                Button(action: { createNewRule() }) {
                    Label("New Rule", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Rules List
            if rulesEngine.rules.isEmpty {
                emptyStateView
            } else {
                rulesListView
            }
        }
        .frame(width: 800, height: 600)
        .background(Color.black)
        .sheet(isPresented: $showingRuleEditor) {
            if let rule = editingRule {
                RuleEditorView(rule: rule, onSave: { updatedRule in
                    rulesEngine.updateRule(updatedRule)
                    editingRule = nil
                }, onCancel: {
                    editingRule = nil
                })
            }
        }
        .sheet(isPresented: $showingStatistics) {
            RuleStatisticsView()
        }
        .sheet(isPresented: $showingImportExport) {
            ImportExportView()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Rules Yet")
                .font(.title)
                .foregroundColor(.white)

            Text("Create rules to automatically organize your emails")
                .foregroundColor(.gray)

            Button(action: { createNewRule() }) {
                Label("Create First Rule", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Rules List

    private var rulesListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(rulesEngine.rules) { rule in
                    RuleCard(rule: rule, onEdit: {
                        editingRule = rule
                        showingRuleEditor = true
                    }, onToggle: {
                        rulesEngine.toggleRule(rule.id)
                    }, onDelete: {
                        rulesEngine.deleteRule(rule.id)
                    })
                }
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func createNewRule() {
        let newRule = EmailRule(
            name: "New Rule",
            conditions: [RuleCondition(type: .categoryIs(.marketing))],
            actions: [RuleAction(type: .markRead)]
        )
        editingRule = newRule
        showingRuleEditor = true
    }
}

// MARK: - Rule Card

struct RuleCard: View {
    let rule: EmailRule
    let onEdit: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Toggle("", isOn: .constant(rule.isEnabled))
                    .labelsHidden()
                    .onChange(of: rule.isEnabled) { _ in onToggle() }

                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.name)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(rule.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                // Priority badge
                Text("\(rule.priority)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
                    .foregroundColor(.blue)

                // Edit button
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .foregroundColor(.cyan)

                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            // Conditions
            HStack(spacing: 8) {
                Text("IF")
                    .font(.caption)
                    .foregroundColor(.gray)

                Text(rule.matchType.displayName.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)

                ForEach(rule.conditions) { condition in
                    ConditionChip(condition: condition)
                }
            }

            // Actions
            HStack(spacing: 8) {
                Text("THEN")
                    .font(.caption)
                    .foregroundColor(.gray)

                ForEach(rule.actions) { action in
                    ActionChip(action: action)
                }
            }

            // Statistics
            if rule.executionCount > 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Executed \(rule.executionCount) time\(rule.executionCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .opacity(rule.isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - Condition Chip

struct ConditionChip: View {
    let condition: RuleCondition

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: condition.type.icon)
                .font(.caption)
            Text(condition.type.displayName)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.purple.opacity(0.2))
        .foregroundColor(.purple)
        .cornerRadius(8)
    }
}

// MARK: - Action Chip

struct ActionChip: View {
    let action: RuleAction

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: action.type.icon)
                .font(.caption)
            Text(action.type.displayName)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.2))
        .foregroundColor(.green)
        .cornerRadius(8)
    }
}

// MARK: - Rule Editor View

struct RuleEditorView: View {
    @State var rule: EmailRule
    let onSave: (EmailRule) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Rule")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)

                Button("Save") {
                    onSave(rule)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!rule.isValid)
            }
            .padding()

            Divider()

            Form {
                Section("Rule Name") {
                    TextField("Name", text: $rule.name)
                }

                Section("Priority") {
                    Slider(value: Binding(
                        get: { Double(rule.priority) },
                        set: { rule.priority = Int($0) }
                    ), in: 1...100, step: 1)
                    Text("Priority: \(rule.priority)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Section("Conditions") {
                    Picker("Match Type", selection: $rule.matchType) {
                        Text("All (AND)").tag(EmailRule.MatchType.all)
                        Text("Any (OR)").tag(EmailRule.MatchType.any)
                    }

                    // TODO: Add condition editor
                    Text("Conditions: \(rule.conditions.count)")
                        .foregroundColor(.gray)
                }

                Section("Actions") {
                    // TODO: Add action editor
                    Text("Actions: \(rule.actions.count)")
                        .foregroundColor(.gray)
                }
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .background(Color.black)
    }
}

// MARK: - Statistics View

struct RuleStatisticsView: View {
    @ObservedObject var rulesEngine = RulesEngine.shared

    var body: some View {
        VStack(spacing: 20) {
            Text("📊 Rule Statistics")
                .font(.title)
                .fontWeight(.bold)

            Grid(alignment: .leading, horizontalSpacing: 30, verticalSpacing: 15) {
                GridRow {
                    statCell("Total Rules", value: "\(rulesEngine.statistics.totalRules)")
                    statCell("Enabled", value: "\(rulesEngine.statistics.enabledRules)")
                }

                GridRow {
                    statCell("Total Executions", value: "\(rulesEngine.statistics.totalExecutions)")
                    statCell("Success Rate", value: String(format: "%.1f%%", rulesEngine.statistics.successRate * 100))
                }

                GridRow {
                    statCell("Successful", value: "\(rulesEngine.statistics.successfulExecutions)")
                    statCell("Failed", value: "\(rulesEngine.statistics.failedExecutions)")
                }

                GridRow {
                    statCell("Avg Time", value: String(format: "%.2fms", rulesEngine.statistics.avgExecutionTime * 1000))
                    if let lastDate = rulesEngine.statistics.lastExecutionDate {
                        statCell("Last Run", value: formatDate(lastDate))
                    }
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .background(Color.black)
    }

    private func statCell(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(width: 200, alignment: .leading)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Import/Export View

struct ImportExportView: View {
    @ObservedObject var rulesEngine = RulesEngine.shared
    @State private var exportedJSON = ""
    @State private var importJSON = ""
    @State private var showingSuccess = false
    @State private var showingError = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Import/Export Rules")
                .font(.title)
                .fontWeight(.bold)

            // Export
            VStack(alignment: .leading, spacing: 10) {
                Text("Export")
                    .font(.headline)

                if let json = rulesEngine.exportRules() {
                    TextEditor(text: .constant(json))
                        .frame(height: 150)
                        .border(Color.gray.opacity(0.3))

                    Button("Copy to Clipboard") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(json, forType: .string)
                        showingSuccess = true
                    }
                }
            }

            Divider()

            // Import
            VStack(alignment: .leading, spacing: 10) {
                Text("Import")
                    .font(.headline)

                TextEditor(text: $importJSON)
                    .frame(height: 150)
                    .border(Color.gray.opacity(0.3))

                Button("Import Rules") {
                    if rulesEngine.importRules(from: importJSON) {
                        showingSuccess = true
                        importJSON = ""
                    } else {
                        showingError = true
                    }
                }
                .disabled(importJSON.isEmpty)
            }

            if showingSuccess {
                Text("✅ Success!")
                    .foregroundColor(.green)
            }

            if showingError {
                Text("❌ Import failed - invalid JSON")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .frame(width: 600, height: 500)
        .background(Color.black)
    }
}

// MARK: - Preview

#if DEBUG
struct RulesManagementView_Previews: PreviewProvider {
    static var previews: some View {
        RulesManagementView()
    }
}
#endif
