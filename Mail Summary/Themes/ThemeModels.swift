//
//  ThemeModels.swift
//  Mail Summary
//
//  Theme data models for customizable UI themes
//  Created by Jordan Koch on 2026-01-30.
//

import SwiftUI

/// Available built-in themes
enum ThemePreset: String, CaseIterable, Codable {
    case light = "Light"
    case dark = "Dark"
    case oceanBlue = "Ocean Blue"
    case forestGreen = "Forest Green"
    case sunsetOrange = "Sunset Orange"
    case highContrast = "High Contrast"
    case solarizedLight = "Solarized Light"
    case solarizedDark = "Solarized Dark"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .oceanBlue: return "water.waves"
        case .forestGreen: return "leaf.fill"
        case .sunsetOrange: return "sunset.fill"
        case .highContrast: return "circle.lefthalf.filled"
        case .solarizedLight: return "sun.horizon.fill"
        case .solarizedDark: return "moon.stars.fill"
        case .custom: return "paintbrush.fill"
        }
    }
}

/// Complete theme definition with all colors
struct AppTheme: Codable, Equatable {
    var preset: ThemePreset

    // Primary colors
    var primaryBackground: CodableColor
    var secondaryBackground: CodableColor
    var tertiaryBackground: CodableColor

    // Text colors
    var primaryText: CodableColor
    var secondaryText: CodableColor
    var tertiaryText: CodableColor

    // Accent colors
    var accent: CodableColor
    var accentSecondary: CodableColor

    // Semantic colors
    var success: CodableColor
    var warning: CodableColor
    var error: CodableColor
    var info: CodableColor

    // Category colors (for email categories)
    var categoryBills: CodableColor
    var categoryOrders: CodableColor
    var categoryWork: CodableColor
    var categoryPersonal: CodableColor
    var categoryMarketing: CodableColor
    var categoryNewsletters: CodableColor
    var categorySocial: CodableColor
    var categorySpam: CodableColor
    var categoryOther: CodableColor

    // Priority colors
    var priorityHigh: CodableColor
    var priorityMedium: CodableColor
    var priorityLow: CodableColor

    // UI element colors
    var cardBackground: CodableColor
    var cardBorder: CodableColor
    var divider: CodableColor
    var shadow: CodableColor

    // MARK: - Built-in Themes

    static let light = AppTheme(
        preset: .light,
        primaryBackground: CodableColor(hex: "#FFFFFF"),
        secondaryBackground: CodableColor(hex: "#F5F5F7"),
        tertiaryBackground: CodableColor(hex: "#E8E8ED"),
        primaryText: CodableColor(hex: "#1D1D1F"),
        secondaryText: CodableColor(hex: "#6E6E73"),
        tertiaryText: CodableColor(hex: "#8E8E93"),
        accent: CodableColor(hex: "#007AFF"),
        accentSecondary: CodableColor(hex: "#5856D6"),
        success: CodableColor(hex: "#34C759"),
        warning: CodableColor(hex: "#FF9500"),
        error: CodableColor(hex: "#FF3B30"),
        info: CodableColor(hex: "#5AC8FA"),
        categoryBills: CodableColor(hex: "#FF3B30"),
        categoryOrders: CodableColor(hex: "#007AFF"),
        categoryWork: CodableColor(hex: "#5856D6"),
        categoryPersonal: CodableColor(hex: "#34C759"),
        categoryMarketing: CodableColor(hex: "#FF9500"),
        categoryNewsletters: CodableColor(hex: "#00C7BE"),
        categorySocial: CodableColor(hex: "#FF2D55"),
        categorySpam: CodableColor(hex: "#8E8E93"),
        categoryOther: CodableColor(hex: "#636366"),
        priorityHigh: CodableColor(hex: "#FF3B30"),
        priorityMedium: CodableColor(hex: "#FF9500"),
        priorityLow: CodableColor(hex: "#34C759"),
        cardBackground: CodableColor(hex: "#FFFFFF"),
        cardBorder: CodableColor(hex: "#E5E5EA"),
        divider: CodableColor(hex: "#C6C6C8"),
        shadow: CodableColor(hex: "#00000020")
    )

    static let dark = AppTheme(
        preset: .dark,
        primaryBackground: CodableColor(hex: "#000000"),
        secondaryBackground: CodableColor(hex: "#1C1C1E"),
        tertiaryBackground: CodableColor(hex: "#2C2C2E"),
        primaryText: CodableColor(hex: "#FFFFFF"),
        secondaryText: CodableColor(hex: "#EBEBF5"),
        tertiaryText: CodableColor(hex: "#8E8E93"),
        accent: CodableColor(hex: "#0A84FF"),
        accentSecondary: CodableColor(hex: "#5E5CE6"),
        success: CodableColor(hex: "#30D158"),
        warning: CodableColor(hex: "#FF9F0A"),
        error: CodableColor(hex: "#FF453A"),
        info: CodableColor(hex: "#64D2FF"),
        categoryBills: CodableColor(hex: "#FF453A"),
        categoryOrders: CodableColor(hex: "#0A84FF"),
        categoryWork: CodableColor(hex: "#5E5CE6"),
        categoryPersonal: CodableColor(hex: "#30D158"),
        categoryMarketing: CodableColor(hex: "#FF9F0A"),
        categoryNewsletters: CodableColor(hex: "#66D4CF"),
        categorySocial: CodableColor(hex: "#FF375F"),
        categorySpam: CodableColor(hex: "#8E8E93"),
        categoryOther: CodableColor(hex: "#636366"),
        priorityHigh: CodableColor(hex: "#FF453A"),
        priorityMedium: CodableColor(hex: "#FF9F0A"),
        priorityLow: CodableColor(hex: "#30D158"),
        cardBackground: CodableColor(hex: "#1C1C1E"),
        cardBorder: CodableColor(hex: "#38383A"),
        divider: CodableColor(hex: "#38383A"),
        shadow: CodableColor(hex: "#00000040")
    )

    static let oceanBlue = AppTheme(
        preset: .oceanBlue,
        primaryBackground: CodableColor(hex: "#0D1B2A"),
        secondaryBackground: CodableColor(hex: "#1B263B"),
        tertiaryBackground: CodableColor(hex: "#415A77"),
        primaryText: CodableColor(hex: "#E0E1DD"),
        secondaryText: CodableColor(hex: "#778DA9"),
        tertiaryText: CodableColor(hex: "#415A77"),
        accent: CodableColor(hex: "#00B4D8"),
        accentSecondary: CodableColor(hex: "#48CAE4"),
        success: CodableColor(hex: "#06D6A0"),
        warning: CodableColor(hex: "#FFD166"),
        error: CodableColor(hex: "#EF476F"),
        info: CodableColor(hex: "#90E0EF"),
        categoryBills: CodableColor(hex: "#EF476F"),
        categoryOrders: CodableColor(hex: "#00B4D8"),
        categoryWork: CodableColor(hex: "#118AB2"),
        categoryPersonal: CodableColor(hex: "#06D6A0"),
        categoryMarketing: CodableColor(hex: "#FFD166"),
        categoryNewsletters: CodableColor(hex: "#48CAE4"),
        categorySocial: CodableColor(hex: "#EF476F"),
        categorySpam: CodableColor(hex: "#778DA9"),
        categoryOther: CodableColor(hex: "#415A77"),
        priorityHigh: CodableColor(hex: "#EF476F"),
        priorityMedium: CodableColor(hex: "#FFD166"),
        priorityLow: CodableColor(hex: "#06D6A0"),
        cardBackground: CodableColor(hex: "#1B263B"),
        cardBorder: CodableColor(hex: "#415A77"),
        divider: CodableColor(hex: "#415A77"),
        shadow: CodableColor(hex: "#00000040")
    )

    static let forestGreen = AppTheme(
        preset: .forestGreen,
        primaryBackground: CodableColor(hex: "#1A1A2E"),
        secondaryBackground: CodableColor(hex: "#16213E"),
        tertiaryBackground: CodableColor(hex: "#0F3460"),
        primaryText: CodableColor(hex: "#E8F5E9"),
        secondaryText: CodableColor(hex: "#81C784"),
        tertiaryText: CodableColor(hex: "#4CAF50"),
        accent: CodableColor(hex: "#4CAF50"),
        accentSecondary: CodableColor(hex: "#81C784"),
        success: CodableColor(hex: "#66BB6A"),
        warning: CodableColor(hex: "#FFCA28"),
        error: CodableColor(hex: "#EF5350"),
        info: CodableColor(hex: "#29B6F6"),
        categoryBills: CodableColor(hex: "#EF5350"),
        categoryOrders: CodableColor(hex: "#29B6F6"),
        categoryWork: CodableColor(hex: "#7E57C2"),
        categoryPersonal: CodableColor(hex: "#66BB6A"),
        categoryMarketing: CodableColor(hex: "#FFCA28"),
        categoryNewsletters: CodableColor(hex: "#26A69A"),
        categorySocial: CodableColor(hex: "#EC407A"),
        categorySpam: CodableColor(hex: "#78909C"),
        categoryOther: CodableColor(hex: "#546E7A"),
        priorityHigh: CodableColor(hex: "#EF5350"),
        priorityMedium: CodableColor(hex: "#FFCA28"),
        priorityLow: CodableColor(hex: "#66BB6A"),
        cardBackground: CodableColor(hex: "#16213E"),
        cardBorder: CodableColor(hex: "#4CAF50"),
        divider: CodableColor(hex: "#2E7D32"),
        shadow: CodableColor(hex: "#00000040")
    )

    static let sunsetOrange = AppTheme(
        preset: .sunsetOrange,
        primaryBackground: CodableColor(hex: "#2D132C"),
        secondaryBackground: CodableColor(hex: "#3D1E3D"),
        tertiaryBackground: CodableColor(hex: "#522B5B"),
        primaryText: CodableColor(hex: "#FBE8D3"),
        secondaryText: CodableColor(hex: "#F0A500"),
        tertiaryText: CodableColor(hex: "#E85A4F"),
        accent: CodableColor(hex: "#FF6B35"),
        accentSecondary: CodableColor(hex: "#F7931E"),
        success: CodableColor(hex: "#7CB518"),
        warning: CodableColor(hex: "#F0A500"),
        error: CodableColor(hex: "#E85A4F"),
        info: CodableColor(hex: "#4ECDC4"),
        categoryBills: CodableColor(hex: "#E85A4F"),
        categoryOrders: CodableColor(hex: "#4ECDC4"),
        categoryWork: CodableColor(hex: "#9B5DE5"),
        categoryPersonal: CodableColor(hex: "#7CB518"),
        categoryMarketing: CodableColor(hex: "#F0A500"),
        categoryNewsletters: CodableColor(hex: "#00BBF9"),
        categorySocial: CodableColor(hex: "#F15BB5"),
        categorySpam: CodableColor(hex: "#9E9E9E"),
        categoryOther: CodableColor(hex: "#757575"),
        priorityHigh: CodableColor(hex: "#E85A4F"),
        priorityMedium: CodableColor(hex: "#F0A500"),
        priorityLow: CodableColor(hex: "#7CB518"),
        cardBackground: CodableColor(hex: "#3D1E3D"),
        cardBorder: CodableColor(hex: "#FF6B35"),
        divider: CodableColor(hex: "#522B5B"),
        shadow: CodableColor(hex: "#00000050")
    )

    static let highContrast = AppTheme(
        preset: .highContrast,
        primaryBackground: CodableColor(hex: "#000000"),
        secondaryBackground: CodableColor(hex: "#1A1A1A"),
        tertiaryBackground: CodableColor(hex: "#333333"),
        primaryText: CodableColor(hex: "#FFFFFF"),
        secondaryText: CodableColor(hex: "#FFFF00"),
        tertiaryText: CodableColor(hex: "#00FFFF"),
        accent: CodableColor(hex: "#FFFF00"),
        accentSecondary: CodableColor(hex: "#00FFFF"),
        success: CodableColor(hex: "#00FF00"),
        warning: CodableColor(hex: "#FFFF00"),
        error: CodableColor(hex: "#FF0000"),
        info: CodableColor(hex: "#00FFFF"),
        categoryBills: CodableColor(hex: "#FF0000"),
        categoryOrders: CodableColor(hex: "#00FFFF"),
        categoryWork: CodableColor(hex: "#FF00FF"),
        categoryPersonal: CodableColor(hex: "#00FF00"),
        categoryMarketing: CodableColor(hex: "#FFFF00"),
        categoryNewsletters: CodableColor(hex: "#00FFFF"),
        categorySocial: CodableColor(hex: "#FF00FF"),
        categorySpam: CodableColor(hex: "#808080"),
        categoryOther: CodableColor(hex: "#C0C0C0"),
        priorityHigh: CodableColor(hex: "#FF0000"),
        priorityMedium: CodableColor(hex: "#FFFF00"),
        priorityLow: CodableColor(hex: "#00FF00"),
        cardBackground: CodableColor(hex: "#1A1A1A"),
        cardBorder: CodableColor(hex: "#FFFFFF"),
        divider: CodableColor(hex: "#FFFFFF"),
        shadow: CodableColor(hex: "#FFFFFF30")
    )

    static let solarizedLight = AppTheme(
        preset: .solarizedLight,
        primaryBackground: CodableColor(hex: "#FDF6E3"),
        secondaryBackground: CodableColor(hex: "#EEE8D5"),
        tertiaryBackground: CodableColor(hex: "#DDD6C3"),
        primaryText: CodableColor(hex: "#657B83"),
        secondaryText: CodableColor(hex: "#93A1A1"),
        tertiaryText: CodableColor(hex: "#839496"),
        accent: CodableColor(hex: "#268BD2"),
        accentSecondary: CodableColor(hex: "#2AA198"),
        success: CodableColor(hex: "#859900"),
        warning: CodableColor(hex: "#B58900"),
        error: CodableColor(hex: "#DC322F"),
        info: CodableColor(hex: "#268BD2"),
        categoryBills: CodableColor(hex: "#DC322F"),
        categoryOrders: CodableColor(hex: "#268BD2"),
        categoryWork: CodableColor(hex: "#6C71C4"),
        categoryPersonal: CodableColor(hex: "#859900"),
        categoryMarketing: CodableColor(hex: "#B58900"),
        categoryNewsletters: CodableColor(hex: "#2AA198"),
        categorySocial: CodableColor(hex: "#D33682"),
        categorySpam: CodableColor(hex: "#93A1A1"),
        categoryOther: CodableColor(hex: "#839496"),
        priorityHigh: CodableColor(hex: "#DC322F"),
        priorityMedium: CodableColor(hex: "#B58900"),
        priorityLow: CodableColor(hex: "#859900"),
        cardBackground: CodableColor(hex: "#EEE8D5"),
        cardBorder: CodableColor(hex: "#93A1A1"),
        divider: CodableColor(hex: "#93A1A1"),
        shadow: CodableColor(hex: "#00000015")
    )

    static let solarizedDark = AppTheme(
        preset: .solarizedDark,
        primaryBackground: CodableColor(hex: "#002B36"),
        secondaryBackground: CodableColor(hex: "#073642"),
        tertiaryBackground: CodableColor(hex: "#094552"),
        primaryText: CodableColor(hex: "#839496"),
        secondaryText: CodableColor(hex: "#657B83"),
        tertiaryText: CodableColor(hex: "#586E75"),
        accent: CodableColor(hex: "#268BD2"),
        accentSecondary: CodableColor(hex: "#2AA198"),
        success: CodableColor(hex: "#859900"),
        warning: CodableColor(hex: "#B58900"),
        error: CodableColor(hex: "#DC322F"),
        info: CodableColor(hex: "#268BD2"),
        categoryBills: CodableColor(hex: "#DC322F"),
        categoryOrders: CodableColor(hex: "#268BD2"),
        categoryWork: CodableColor(hex: "#6C71C4"),
        categoryPersonal: CodableColor(hex: "#859900"),
        categoryMarketing: CodableColor(hex: "#B58900"),
        categoryNewsletters: CodableColor(hex: "#2AA198"),
        categorySocial: CodableColor(hex: "#D33682"),
        categorySpam: CodableColor(hex: "#657B83"),
        categoryOther: CodableColor(hex: "#586E75"),
        priorityHigh: CodableColor(hex: "#DC322F"),
        priorityMedium: CodableColor(hex: "#B58900"),
        priorityLow: CodableColor(hex: "#859900"),
        cardBackground: CodableColor(hex: "#073642"),
        cardBorder: CodableColor(hex: "#586E75"),
        divider: CodableColor(hex: "#586E75"),
        shadow: CodableColor(hex: "#00000040")
    )

    /// Get theme for preset
    static func theme(for preset: ThemePreset) -> AppTheme {
        switch preset {
        case .light: return .light
        case .dark: return .dark
        case .oceanBlue: return .oceanBlue
        case .forestGreen: return .forestGreen
        case .sunsetOrange: return .sunsetOrange
        case .highContrast: return .highContrast
        case .solarizedLight: return .solarizedLight
        case .solarizedDark: return .solarizedDark
        case .custom: return .dark // Custom starts from dark as base
        }
    }
}

/// Codable wrapper for Color
struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        if hexSanitized.count == 8 {
            // RGBA
            red = Double((rgb >> 24) & 0xFF) / 255.0
            green = Double((rgb >> 16) & 0xFF) / 255.0
            blue = Double((rgb >> 8) & 0xFF) / 255.0
            alpha = Double(rgb & 0xFF) / 255.0
        } else {
            // RGB
            red = Double((rgb >> 16) & 0xFF) / 255.0
            green = Double((rgb >> 8) & 0xFF) / 255.0
            blue = Double(rgb & 0xFF) / 255.0
            alpha = 1.0
        }
    }

    init(color: Color) {
        let nsColor = NSColor(color)
        red = Double(nsColor.redComponent)
        green = Double(nsColor.greenComponent)
        blue = Double(nsColor.blueComponent)
        alpha = Double(nsColor.alphaComponent)
    }

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    var hex: String {
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - SwiftUI Color Extension

extension Color {
    init(codable: CodableColor) {
        self.init(red: codable.red, green: codable.green, blue: codable.blue, opacity: codable.alpha)
    }
}
