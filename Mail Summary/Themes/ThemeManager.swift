//
//  ThemeManager.swift
//  Mail Summary
//
//  Manages app-wide theme selection and persistence
//  Created by Jordan Koch on 2026-01-30.
//

import SwiftUI
import Combine

/// Manages themes across the app with persistence
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    /// Current active theme
    @Published var currentTheme: AppTheme {
        didSet {
            saveTheme()
        }
    }

    /// Custom theme (user-edited)
    @Published var customTheme: AppTheme {
        didSet {
            saveCustomTheme()
        }
    }

    /// Whether custom theme is being edited
    @Published var isEditingCustomTheme = false

    private let themeKey = "MailSummary_CurrentTheme"
    private let customThemeKey = "MailSummary_CustomTheme"

    private init() {
        // Load saved theme or default to system appearance
        if let data = UserDefaults.standard.data(forKey: themeKey),
           let theme = try? JSONDecoder().decode(AppTheme.self, from: data) {
            currentTheme = theme
        } else {
            // Default based on system appearance
            currentTheme = NSApp.effectiveAppearance.name == .darkAqua ? .dark : .light
        }

        // Load custom theme
        if let data = UserDefaults.standard.data(forKey: customThemeKey),
           let theme = try? JSONDecoder().decode(AppTheme.self, from: data) {
            customTheme = theme
        } else {
            customTheme = .dark
            customTheme.preset = .custom
        }
    }

    // MARK: - Theme Selection

    /// Apply a preset theme
    func applyPreset(_ preset: ThemePreset) {
        if preset == .custom {
            currentTheme = customTheme
        } else {
            currentTheme = AppTheme.theme(for: preset)
        }
    }

    /// Get all available presets
    var availablePresets: [ThemePreset] {
        ThemePreset.allCases
    }

    // MARK: - Custom Theme Editing

    /// Start editing custom theme (creates copy from current)
    func startEditingCustomTheme() {
        if currentTheme.preset != .custom {
            customTheme = currentTheme
            customTheme.preset = .custom
        }
        isEditingCustomTheme = true
    }

    /// Save custom theme edits and apply
    func saveCustomThemeEdits() {
        isEditingCustomTheme = false
        currentTheme = customTheme
        saveCustomTheme()
    }

    /// Cancel custom theme edits
    func cancelCustomThemeEdits() {
        isEditingCustomTheme = false
        // Reload saved custom theme
        if let data = UserDefaults.standard.data(forKey: customThemeKey),
           let theme = try? JSONDecoder().decode(AppTheme.self, from: data) {
            customTheme = theme
        }
    }

    /// Reset custom theme to a preset base
    func resetCustomTheme(to preset: ThemePreset) {
        customTheme = AppTheme.theme(for: preset)
        customTheme.preset = .custom
    }

    // MARK: - Persistence

    private func saveTheme() {
        if let data = try? JSONEncoder().encode(currentTheme) {
            UserDefaults.standard.set(data, forKey: themeKey)
        }
    }

    private func saveCustomTheme() {
        if let data = try? JSONEncoder().encode(customTheme) {
            UserDefaults.standard.set(data, forKey: customThemeKey)
        }
    }

    // MARK: - Convenience Colors

    /// Get color for email category
    func color(for category: Email.EmailCategory) -> Color {
        switch category {
        case .bills: return currentTheme.categoryBills.color
        case .orders: return currentTheme.categoryOrders.color
        case .work: return currentTheme.categoryWork.color
        case .personal: return currentTheme.categoryPersonal.color
        case .marketing: return currentTheme.categoryMarketing.color
        case .newsletters: return currentTheme.categoryNewsletters.color
        case .social: return currentTheme.categorySocial.color
        case .spam: return currentTheme.categorySpam.color
        case .other: return currentTheme.categoryOther.color
        }
    }

    /// Get color for priority level
    func color(forPriority priority: Int) -> Color {
        if priority >= 7 {
            return currentTheme.priorityHigh.color
        } else if priority >= 4 {
            return currentTheme.priorityMedium.color
        } else {
            return currentTheme.priorityLow.color
        }
    }
}

// MARK: - Theme Environment Key

private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppTheme = .dark
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - View Modifier for Themed Views

struct ThemedViewModifier: ViewModifier {
    @ObservedObject var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        content
            .environment(\.appTheme, themeManager.currentTheme)
    }
}

extension View {
    /// Apply the current theme to this view hierarchy
    func themed() -> some View {
        modifier(ThemedViewModifier())
    }
}

// MARK: - Theme-Aware View Components

extension View {
    /// Apply themed background
    func themedBackground(_ keyPath: KeyPath<AppTheme, CodableColor>) -> some View {
        self.modifier(ThemedBackgroundModifier(colorPath: keyPath))
    }

    /// Apply themed foreground
    func themedForeground(_ keyPath: KeyPath<AppTheme, CodableColor>) -> some View {
        self.modifier(ThemedForegroundModifier(colorPath: keyPath))
    }
}

struct ThemedBackgroundModifier: ViewModifier {
    @ObservedObject var themeManager = ThemeManager.shared
    let colorPath: KeyPath<AppTheme, CodableColor>

    func body(content: Content) -> some View {
        content
            .background(themeManager.currentTheme[keyPath: colorPath].color)
    }
}

struct ThemedForegroundModifier: ViewModifier {
    @ObservedObject var themeManager = ThemeManager.shared
    let colorPath: KeyPath<AppTheme, CodableColor>

    func body(content: Content) -> some View {
        content
            .foregroundColor(themeManager.currentTheme[keyPath: colorPath].color)
    }
}
