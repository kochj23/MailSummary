//
//  ThemeEditorView.swift
//  Mail Summary
//
//  Visual theme editor with color pickers
//  Created by Jordan Koch on 2026-01-30.
//

import SwiftUI

struct ThemeEditorView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSection: ThemeSection = .backgrounds

    enum ThemeSection: String, CaseIterable {
        case backgrounds = "Backgrounds"
        case text = "Text"
        case accents = "Accents"
        case semantic = "Semantic"
        case categories = "Categories"
        case priorities = "Priorities"
        case ui = "UI Elements"

        var icon: String {
            switch self {
            case .backgrounds: return "rectangle.fill"
            case .text: return "textformat"
            case .accents: return "sparkle"
            case .semantic: return "info.circle.fill"
            case .categories: return "folder.fill"
            case .priorities: return "flag.fill"
            case .ui: return "square.stack.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            HSplitView {
                // Left: Section list
                sectionList
                    .frame(minWidth: 180, maxWidth: 220)

                // Right: Color editors
                colorEditors
                    .frame(minWidth: 400)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Theme Editor")
                    .font(.title2.bold())
                Text("Customize your Mail Summary appearance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Base theme selector
            HStack {
                Text("Start from:")
                    .foregroundColor(.secondary)
                Picker("Base", selection: baseThemeBinding) {
                    ForEach(ThemePreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    themeManager.cancelCustomThemeEdits()
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Save Theme") {
                    themeManager.saveCustomThemeEdits()
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var baseThemeBinding: Binding<ThemePreset> {
        Binding(
            get: { .dark }, // Default base
            set: { themeManager.resetCustomTheme(to: $0) }
        )
    }

    // MARK: - Section List

    private var sectionList: some View {
        List(selection: $selectedSection) {
            ForEach(ThemeSection.allCases, id: \.self) { section in
                HStack {
                    Image(systemName: section.icon)
                        .frame(width: 20)
                    Text(section.rawValue)
                }
                .tag(section)
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Color Editors

    @ViewBuilder
    private var colorEditors: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch selectedSection {
                case .backgrounds:
                    backgroundColors
                case .text:
                    textColors
                case .accents:
                    accentColors
                case .semantic:
                    semanticColors
                case .categories:
                    categoryColors
                case .priorities:
                    priorityColors
                case .ui:
                    uiColors
                }
            }
            .padding()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Color Sections

    private var backgroundColors: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Background Colors")
                .font(.headline)

            ColorEditor(title: "Primary Background", color: $themeManager.customTheme.primaryBackground)
            ColorEditor(title: "Secondary Background", color: $themeManager.customTheme.secondaryBackground)
            ColorEditor(title: "Tertiary Background", color: $themeManager.customTheme.tertiaryBackground)
        }
    }

    private var textColors: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Text Colors")
                .font(.headline)

            ColorEditor(title: "Primary Text", color: $themeManager.customTheme.primaryText)
            ColorEditor(title: "Secondary Text", color: $themeManager.customTheme.secondaryText)
            ColorEditor(title: "Tertiary Text", color: $themeManager.customTheme.tertiaryText)
        }
    }

    private var accentColors: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Accent Colors")
                .font(.headline)

            ColorEditor(title: "Primary Accent", color: $themeManager.customTheme.accent)
            ColorEditor(title: "Secondary Accent", color: $themeManager.customTheme.accentSecondary)
        }
    }

    private var semanticColors: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Semantic Colors")
                .font(.headline)

            ColorEditor(title: "Success", color: $themeManager.customTheme.success)
            ColorEditor(title: "Warning", color: $themeManager.customTheme.warning)
            ColorEditor(title: "Error", color: $themeManager.customTheme.error)
            ColorEditor(title: "Info", color: $themeManager.customTheme.info)
        }
    }

    private var categoryColors: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Category Colors")
                .font(.headline)

            ColorEditor(title: "Bills", color: $themeManager.customTheme.categoryBills)
            ColorEditor(title: "Orders", color: $themeManager.customTheme.categoryOrders)
            ColorEditor(title: "Work", color: $themeManager.customTheme.categoryWork)
            ColorEditor(title: "Personal", color: $themeManager.customTheme.categoryPersonal)
            ColorEditor(title: "Marketing", color: $themeManager.customTheme.categoryMarketing)
            ColorEditor(title: "Newsletters", color: $themeManager.customTheme.categoryNewsletters)
            ColorEditor(title: "Social", color: $themeManager.customTheme.categorySocial)
            ColorEditor(title: "Spam", color: $themeManager.customTheme.categorySpam)
            ColorEditor(title: "Other", color: $themeManager.customTheme.categoryOther)
        }
    }

    private var priorityColors: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Priority Colors")
                .font(.headline)

            ColorEditor(title: "High Priority", color: $themeManager.customTheme.priorityHigh)
            ColorEditor(title: "Medium Priority", color: $themeManager.customTheme.priorityMedium)
            ColorEditor(title: "Low Priority", color: $themeManager.customTheme.priorityLow)
        }
    }

    private var uiColors: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("UI Element Colors")
                .font(.headline)

            ColorEditor(title: "Card Background", color: $themeManager.customTheme.cardBackground)
            ColorEditor(title: "Card Border", color: $themeManager.customTheme.cardBorder)
            ColorEditor(title: "Divider", color: $themeManager.customTheme.divider)
            ColorEditor(title: "Shadow", color: $themeManager.customTheme.shadow)
        }
    }
}

// MARK: - Color Editor Component

struct ColorEditor: View {
    let title: String
    @Binding var color: CodableColor

    @State private var nsColor: NSColor = .clear

    var body: some View {
        HStack {
            Text(title)
                .frame(width: 150, alignment: .leading)

            ColorPicker("", selection: colorBinding)
                .labelsHidden()

            Text(color.hex)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80)

            // Color preview
            RoundedRectangle(cornerRadius: 4)
                .fill(color.color)
                .frame(width: 60, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { color.color },
            set: { color = CodableColor(color: $0) }
        )
    }
}

// MARK: - Theme Selection View

struct ThemeSelectionView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var showEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Theme")
                .font(.headline)

            // Preset grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                ForEach(ThemePreset.allCases, id: \.self) { preset in
                    ThemePresetCard(
                        preset: preset,
                        isSelected: themeManager.currentTheme.preset == preset,
                        onSelect: {
                            if preset == .custom {
                                showEditor = true
                            } else {
                                themeManager.applyPreset(preset)
                            }
                        }
                    )
                }
            }

            // Edit custom button
            if themeManager.currentTheme.preset == .custom {
                Button("Edit Custom Theme") {
                    themeManager.startEditingCustomTheme()
                    showEditor = true
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            ThemeEditorView()
        }
    }
}

// MARK: - Theme Preset Card

struct ThemePresetCard: View {
    let preset: ThemePreset
    let isSelected: Bool
    let onSelect: () -> Void

    private var theme: AppTheme {
        AppTheme.theme(for: preset)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                // Color preview
                HStack(spacing: 2) {
                    Rectangle().fill(theme.primaryBackground.color)
                    Rectangle().fill(theme.accent.color)
                    Rectangle().fill(theme.accentSecondary.color)
                }
                .frame(height: 30)
                .cornerRadius(4)

                // Label
                HStack(spacing: 4) {
                    Image(systemName: preset.icon)
                        .font(.caption)
                    Text(preset.rawValue)
                        .font(.caption)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ThemeEditorView()
}
