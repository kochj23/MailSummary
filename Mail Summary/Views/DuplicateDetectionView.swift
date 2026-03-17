//
//  DuplicateDetectionView.swift
//  Mail Summary
//
//  UI for duplicate email detection and management
//  Created by Jordan Koch on 2026-01-30.
//

import SwiftUI

struct DuplicateDetectionView: View {
    @EnvironmentObject var mailEngine: MailEngine
    @ObservedObject var duplicateManager = DuplicateDetectionManager.shared

    @State private var selectedMethods: Set<DuplicateDetectionMethod> = Set(DuplicateDetectionMethod.allCases)
    @State private var selectedGroup: DuplicateGroup?
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            HSplitView {
                // Left: Settings & Results List
                leftPanel
                    .frame(minWidth: 300, maxWidth: 400)

                // Right: Selected Group Details
                rightPanel
                    .frame(minWidth: 400)
            }
        }
        .navigationTitle("Duplicate Detection")
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Duplicate Detection")
                    .font(.title2.bold())

                if let lastScan = duplicateManager.lastScanDate {
                    Text("Last scan: \(lastScan.formatted())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Scan button
            if duplicateManager.isScanning {
                HStack {
                    ProgressView(value: duplicateManager.scanProgress)
                        .frame(width: 100)
                    Text("\(Int(duplicateManager.scanProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Button("Scan for Duplicates") {
                    Task {
                        await duplicateManager.scanForDuplicates(mailEngine.emails, methods: selectedMethods)
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
            // Detection Methods
            methodSelector

            Divider()

            // Results Summary
            if !duplicateManager.duplicateGroups.isEmpty {
                resultsSummary
                Divider()
            }

            // Groups List
            groupsList
        }
    }

    private var methodSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detection Methods")
                .font(.headline)

            ForEach(DuplicateDetectionMethod.allCases, id: \.self) { method in
                Toggle(isOn: Binding(
                    get: { selectedMethods.contains(method) },
                    set: { isOn in
                        if isOn {
                            selectedMethods.insert(method)
                        } else {
                            selectedMethods.remove(method)
                        }
                    }
                )) {
                    HStack {
                        Image(systemName: method.icon)
                            .frame(width: 20)
                        VStack(alignment: .leading) {
                            Text(method.rawValue)
                            Text(method.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .toggleStyle(.checkbox)
            }

            // Similarity threshold slider
            VStack(alignment: .leading, spacing: 4) {
                Text("Similarity Threshold: \(Int(duplicateManager.similarityThreshold * 100))%")
                    .font(.caption)
                Slider(value: $duplicateManager.similarityThreshold, in: 0.5...1.0)
            }
            .padding(.top, 8)
        }
        .padding()
    }

    private var resultsSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Results")
                .font(.headline)

            HStack {
                Label("\(duplicateManager.duplicateGroups.count) groups", systemImage: "folder")
                Spacer()
                Label("\(duplicateManager.totalDuplicateCount) duplicates", systemImage: "doc.on.doc")
            }
            .font(.subheadline)

            // Per-method counts
            ForEach(DuplicateDetectionMethod.allCases, id: \.self) { method in
                let count = duplicateManager.duplicateCount(for: method)
                if count > 0 {
                    HStack {
                        Image(systemName: method.icon)
                            .frame(width: 16)
                        Text(method.rawValue)
                        Spacer()
                        Text("\(count)")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var groupsList: some View {
        List(selection: $selectedGroup) {
            if duplicateManager.duplicateGroups.isEmpty {
                if duplicateManager.isScanning {
                    HStack {
                        ProgressView()
                        Text("Scanning...")
                    }
                } else {
                    Text("No duplicates found. Click 'Scan' to detect duplicates.")
                        .foregroundColor(.secondary)
                        .padding()
                }
            } else {
                ForEach(duplicateManager.duplicateGroups) { group in
                    DuplicateGroupRow(group: group)
                        .tag(group)
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        Group {
            if let group = selectedGroup {
                DuplicateGroupDetailView(group: group)
            } else {
                VStack {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a duplicate group to view details")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Duplicate Group Row

struct DuplicateGroupRow: View {
    let group: DuplicateGroup

    var body: some View {
        HStack {
            Image(systemName: group.method.icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.representativeEmail.subject)
                    .lineLimit(1)
                    .font(.body)

                HStack {
                    Text(group.representativeEmail.sender)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(group.totalCount) emails")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            Text("+\(group.duplicateCount)")
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.orange)
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Duplicate Group Detail View

struct DuplicateGroupDetailView: View {
    let group: DuplicateGroup
    @ObservedObject var duplicateManager = DuplicateDetectionManager.shared
    @State private var showDeleteAlert = false
    @State private var deleteResult: (deleted: Int, failed: Int)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: group.method.icon)
                        .font(.title2)
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading) {
                        Text("Duplicate Group")
                            .font(.headline)
                        Text("Detection: \(group.method.rawValue)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Delete duplicates button
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete \(group.duplicateCount) Duplicates", systemImage: "trash")
                    }
                }

                Divider()

                // Representative email
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original (Keep)")
                        .font(.caption.bold())
                        .foregroundColor(.green)

                    EmailPreviewCard(email: group.representativeEmail, isOriginal: true)
                }
            }
            .padding()

            Divider()

            // Duplicates list
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Duplicates (\(group.duplicateCount))")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                        .padding(.horizontal)

                    ForEach(group.duplicates, id: \.id) { email in
                        EmailPreviewCard(email: email, isOriginal: false)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .alert("Delete Duplicates?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    deleteResult = await duplicateManager.deleteDuplicates(in: group)
                }
            }
        } message: {
            Text("This will permanently delete \(group.duplicateCount) duplicate emails. The original email will be kept.")
        }
    }
}

// MARK: - Email Preview Card

struct EmailPreviewCard: View {
    let email: Email
    let isOriginal: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(email.subject)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if isOriginal {
                    Label("Keep", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("Duplicate", systemImage: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            HStack {
                Text(email.sender)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text(email.dateReceived.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let body = email.body {
                Text(body.prefix(150) + (body.count > 150 ? "..." : ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isOriginal ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isOriginal ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    DuplicateDetectionView()
        .environmentObject(MailEngine())
}
