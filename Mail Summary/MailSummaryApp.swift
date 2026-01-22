//
//  MailSummaryApp.swift
//  Mail Summary
//
//  AI-powered email assistant for macOS
//  Created by Jordan Koch on 2026-01-22
//

import SwiftUI

@main
struct MailSummaryApp: App {
    @StateObject private var mailEngine = MailEngine()

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
        #endif
    }
}
