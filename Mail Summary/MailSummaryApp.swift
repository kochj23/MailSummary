//
//  MailSummaryApp.swift
//  Mail Summary
//
//  AI-powered email assistant for macOS
//  Created by Jordan Koch on 2026-01-22
//

import SwiftUI
import NovaAIKit

@main
struct MailSummaryApp: App {
    @StateObject private var mailEngine = MailEngine()

    init() {
        NovaAPIServer.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(mailEngine)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowStyle(.hiddenTitleBar)

        #if os(macOS)
        MenuBarExtra("Mail Summary", systemImage: "envelope.badge.fill") {
            MenuBarView()
                .environmentObject(mailEngine)
        }

        Settings {
            NovaAISettingsView(
                ai: AppAI.shared,
                footer: "When AI is off or unreachable, Mail Summary uses its built-in keyword categorization, rule-based priorities, template summaries and replies."
            )
            .frame(minWidth: 560, minHeight: 520)
        }
        #endif
    }
}
