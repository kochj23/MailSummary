//
//  ExportView.swift
//  Mail Summary
//
//  Export & Backup UI
//  Created by Jordan Koch on 2026-01-26
//
//  User interface for exporting emails and creating backups.
//

import SwiftUI

struct ExportView: View {
    @ObservedObject var exportManager = ExportManager.shared
    @ObservedObject var mailEngine: MailEngine

    @State private var selectedFormat: ExportFormat = .csv
    @State private var includeCategories: Set<Email.EmailCategory> = []
    @State private var dateRange: DateRangeOption = .all
    @State private var customStartDate: Date = Date().addingTimeInterval(-30*86400)
    @State private var customEndDate: Date = Date()
    @State private var showingSuccess: Bool = false
    @State private var exportedFileURL: URL?

    @Environment(\.dismiss) var dismiss

    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case json = "JSON"
        case backup = "Full Backup"

        var icon: String {
            switch self {
            case .csv: return "tablecells"
            case .json: return "doc.text"
            case .backup: return "archivebox.fill"
            }
        }

        var description: String {
            switch self {
            case .csv: return "Spreadsheet format (Excel, Numbers)"
            case .json: return "Structured data format (for developers)"
            case .backup: return "Complete backup (settings, rules, templates, analytics)"
            }
        }
    }

    enum DateRangeOption: String, CaseIterable {
        case all = "All Time"
        case today = "Today"
        case week = "Last 7 Days"
        case month = "Last 30 Days"
        case quarter = "Last 90 Days"
        case custom = "Custom Range"

        func dateRange() -> (Date, Date)? {
            let now = Date()
            switch self {
            case .all:
                return nil
            case .today:
                let start = Calendar.current.startOfDay(for: now)
                return (start, now)
            case .week:
                return (now.addingTimeInterval(-7*86400), now)
            case .month:
                return (now.addingTimeInterval(-30*86400), now)
            case .quarter:
                return (now.addingTimeInterval(-90*86400), now)
            case .custom:
                return nil  // Use custom dates
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Export Form
            Form {
                // Format Selection
                Section("Export Format") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            HStack {
                                Image(systemName: format.icon)
                                Text(format.rawValue)
                            }
                            .tag(format)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(selectedFormat.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                // Date Range
                if selectedFormat != .backup {
                    Section("Date Range") {
                        Picker("Range", selection: $dateRange) {
                            ForEach(DateRangeOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }

                        if dateRange == .custom {
                            DatePicker("From", selection: $customStartDate, displayedComponents: .date)
                            DatePicker("To", selection: $customEndDate, displayedComponents: .date)
                        }
                    }

                    // Category Filter
                    Section("Categories") {
                        Text(includeCategories.isEmpty ? "All categories" : "\(includeCategories.count) selected")
                            .foregroundColor(.gray)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(Email.EmailCategory.allCases, id: \.self) { category in
                                CategoryFilterChip(
                                    category: category,
                                    isSelected: includeCategories.contains(category),
                                    onToggle: {
                                        if includeCategories.contains(category) {
                                            includeCategories.remove(category)
                                        } else {
                                            includeCategories.insert(category)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }

                // Preview
                Section("Preview") {
                    let filtered = filteredEmails()
                    Text("\(filtered.count) emails will be exported")
                        .font(.headline)
                        .foregroundColor(.white)
                }

                // Progress
                if exportManager.isExporting {
                    Section {
                        ProgressView(value: exportManager.exportProgress) {
                            Text("Exporting... \(Int(exportManager.exportProgress * 100))%")
                        }
                    }
                }

                // Success
                if showingSuccess, let url = exportedFileURL {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Export Complete!")
                                    .foregroundColor(.green)

                                Text(url.lastPathComponent)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            Button("Show in Finder") {
                                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding()

            Divider()

            // Actions
            actionsView
        }
        .frame(width: 700, height: 650)
        .background(Color.black)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("📤 Export & Backup")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Export emails or create full backup")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundColor(.gray)
        }
        .padding()
    }

    // MARK: - Actions

    private var actionsView: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Export") {
                performExport()
            }
            .buttonStyle(.borderedProminent)
            .disabled(exportManager.isExporting)
        }
        .padding()
    }

    // MARK: - Export Logic

    private func filteredEmails() -> [Email] {
        var filtered = mailEngine.emails

        // Filter by date range
        if selectedFormat != .backup {
            if dateRange == .custom {
                filtered = filtered.filter {
                    $0.dateReceived >= customStartDate && $0.dateReceived <= customEndDate
                }
            } else if let range = dateRange.dateRange() {
                filtered = filtered.filter {
                    $0.dateReceived >= range.0 && $0.dateReceived <= range.1
                }
            }

            // Filter by categories
            if !includeCategories.isEmpty {
                filtered = filtered.filter {
                    if let category = $0.category {
                        return includeCategories.contains(category)
                    }
                    return false
                }
            }
        }

        return filtered
    }

    private func performExport() {
        showingSuccess = false
        exportedFileURL = nil

        Task {
            let emails = filteredEmails()

            let url: URL?
            switch selectedFormat {
            case .csv:
                url = exportManager.exportToCSV(emails)
            case .json:
                url = exportManager.exportToJSON(emails)
            case .backup:
                url = exportManager.createBackup()
            }

            if let url = url {
                exportedFileURL = url
                showingSuccess = true
            }
        }
    }
}

// MARK: - Category Filter Chip

private struct CategoryFilterChip: View {
    let category: Email.EmailCategory
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: category.icon)
                Text(category.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? colorFrom(category.color).opacity(0.3) : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? colorFrom(category.color) : .gray)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? colorFrom(category.color) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func colorFrom(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "cyan": return .cyan
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "gray": return .gray
        case "yellow": return .yellow
        default: return .primary
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ExportView_Previews: PreviewProvider {
    static var previews: some View {
        ExportView(mailEngine: MailEngine())
    }
}
#endif
