//
//  MenuBarView.swift
//  Mail Summary
//
//  Menu bar dropdown interface
//  Created by Jordan Koch on 2026-01-22
//

import SwiftUI
import NovaAIKit

struct MenuBarView: View {
    @EnvironmentObject var mailEngine: MailEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("📧 Mail Summary")
                .font(.headline)

            NovaAIStatusIndicator(ai: AppAI.shared)
                .font(.caption)

            Divider()

            // Stats
            Text("\(mailEngine.stats.unreadEmails) unread")
                .font(.caption)

            Text("\(mailEngine.stats.highPriorityEmails) high priority")
                .font(.caption)

            Divider()

            // Quick Actions
            Button("Open Dashboard") {
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Scan Now") {
                mailEngine.scan()
            }

            SettingsLink {
                Text("AI Settings…")
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
    }
}
