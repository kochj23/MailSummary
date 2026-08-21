//
//  LLMLoadBalancerSettingsView.swift
//  Mail Summary
//
//  Settings surface for the multi-model LLM load balancer: three toggles
//  (all-local / all-frontier / Nova Gateway), the OpenRouter API key (stored in
//  the macOS Keychain, never UserDefaults), and the Nova Gateway endpoint.
//
//  This is additive — it sits inside the existing AIBackendSelectionView and does
//  not disturb the existing Ollama / OpenAI configuration. Nova Gateway is always
//  optional; a failed health check simply marks it unavailable.
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct LLMLoadBalancerSettingsView: View {
    @StateObject private var llm = LLMBackendManager()
    @ObservedObject private var settings = AppSettings.shared

    @State private var openRouterKeyInput: String = ""
    @State private var keySaved: Bool = false
    @State private var poolCount: Int = 0
    @State private var isDiscovering: Bool = false

    var body: some View {
        Section {
            Text("Multi-Model Load Balancer")
                .font(.headline)

            Text("Spread each request across every enabled model. Local Ollama + MLX, frontier models via OpenRouter, and Nova Gateway can all be balanced together. All toggles are off by default.")
                .font(.caption)
                .foregroundColor(.secondary)

            // MARK: Three toggles

            Toggle(isOn: Binding(
                get: { settings.useAllLocalModels },
                set: { settings.useAllLocalModels = $0; refreshPool() }
            )) {
                Label("All local models (Ollama + MLX)", systemImage: "cpu")
            }

            Toggle(isOn: Binding(
                get: { settings.enableAllFrontierModels },
                set: { settings.enableAllFrontierModels = $0; refreshPool() }
            )) {
                Label("All frontier models (OpenRouter)", systemImage: "cloud")
            }

            Toggle(isOn: Binding(
                get: { settings.useNovaGateway },
                set: { settings.useNovaGateway = $0; refreshPool() }
            )) {
                Label("Nova Gateway (optional)", systemImage: "sparkle.magnifyingglass")
            }

            Divider()

            // MARK: OpenRouter key (Keychain-backed)

            Text("OpenRouter API Key")
                .font(.subheadline).bold()
            HStack {
                SecureField("sk-or-...", text: $openRouterKeyInput)
                    .textFieldStyle(.roundedBorder)
                Button(keySaved ? "Saved" : "Save") {
                    llm.setOpenRouterAPIKey(openRouterKeyInput)
                    keySaved = llm.hasOpenRouterKey
                    Task { await llm.fetchOpenRouterModels() }
                }
                .buttonStyle(.bordered)
                if llm.hasOpenRouterKey {
                    Button("Clear") {
                        llm.setOpenRouterAPIKey("")
                        openRouterKeyInput = ""
                        keySaved = false
                    }
                }
            }
            Text("Stored in the macOS Keychain. One key unlocks all frontier models.")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            // MARK: Nova Gateway endpoint

            Text("Nova Gateway Endpoint")
                .font(.subheadline).bold()
            TextField("http://127.0.0.1:18792", text: Binding(
                get: { settings.novaGatewayURL },
                set: { settings.novaGatewayURL = $0 }
            ))
            .textFieldStyle(.roundedBorder)

            Divider()

            // MARK: Pool status

            HStack {
                Button {
                    refreshPool()
                } label: {
                    Label(isDiscovering ? "Discovering..." : "Refresh Pool", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isDiscovering)

                Spacer()

                Text("\(poolCount) model\(poolCount == 1 ? "" : "s") in balancer pool")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .onAppear {
            keySaved = llm.hasOpenRouterKey
            refreshPool()
        }
    }

    private func refreshPool() {
        isDiscovering = true
        Task {
            let pool = await llm.discoverEnabledPool()
            await MainActor.run {
                poolCount = pool.count
                isDiscovering = false
            }
        }
    }
}
