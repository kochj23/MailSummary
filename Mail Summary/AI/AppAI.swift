//
//  AppAI.swift
//  Mail Summary
//
//  The app's one AI object (NovaAIKit 1.0.0). Settings persist in UserDefaults (no secrets); API keys live only
//  in the Keychain under com.jkoch.mailsummary.<backend>.
//

import Foundation
import NovaAIKit

@MainActor
enum AppAI {
    nonisolated static let appID = "mailsummary"
    nonisolated static let appName = "Mail Summary"

    static let shared: NovaAI = {
        let ai = NovaAI(configuration: NovaAIConfiguration(appID: appID, appName: appName))
        AppAI.migrateLegacy(ai)
        return ai
    }()
}

extension AppAI {
    /// Old Keychain service of the retired copy-pasted AI backend manager (cloud credentials). The name is shared with other
    /// apps that carried the same file, so the OpenAI item is copied but not deleted.
    nonisolated static let legacyBackendService = "com.jkoch.aistudio.aibackend"
    /// Old OpenRouter Keychain item of the load balancer (owned by AIStudio: copy, keep).
    nonisolated static let legacyOpenRouterService = "com.jkoch.aistudio.openrouter"
    /// Accounts the old manager used for the removed Google/Azure/AWS/IBM backends.
    nonisolated static let obsoleteLegacyAccounts = [
        "AIBackend_GoogleCloud_Key", "AIBackend_Azure_Key", "AIBackend_Azure_Endpoint", "AIBackend_AWS_AccessKey",
        "AIBackend_AWS_SecretKey", "AIBackend_IBM_Key", "AIBackend_IBM_URL",
    ] + NovaAIKeys.obsoleteLegacyAccounts
    /// UserDefaults prefix of the old multi-model load balancer settings.
    nonisolated static let legacyBalancerPrefix = "ms.llm."
    nonisolated static let balancerMigratedMarker = "NovaAIKit.mailsummary.balancerMigrated"
    /// Values the old balancer wrote by default; they are not user choices, so they are not imported.
    nonisolated static let legacyBalancerDefaults: Set<String> = [
        "http://localhost:11434", "http://localhost:8000", "http://localhost:8080", "http://127.0.0.1:18792",
        "mistral:latest", "anthropic/claude-sonnet-4.5",
    ]

    /// One-time, idempotent migration of the retired AI backend manager + load-balancer settings and keys.
    static func migrateLegacy(_ ai: NovaAI, defaults: UserDefaults = .standard) {
        // 3a. URLs, backend, Ollama model, on/off; plaintext OpenAI key → Keychain; obsolete secrets/logs deleted.
        //     Security fix: removes any plaintext cloud keys and the old AI-guardian prompt log from UserDefaults.
        ai.migrateFromLegacyAIBackendManager(defaults: defaults)
        // 3b. Old Keychain items → com.jkoch.mailsummary.<backend>.
        ai.migrateLegacyKey(service: legacyBackendService, account: "AIBackend_OpenAI_Key", to: .openAI)
        ai.migrateLegacyKey(service: legacyOpenRouterService, account: "apiKey", to: .openRouter)
        // 3c. Removed backends' secrets: delete only, never read out.
        ai.keys.deleteObsoleteLegacyItems(service: legacyBackendService, accounts: obsoleteLegacyAccounts)
        migrateBalancerSettings(ai, defaults: defaults)
    }

    /// The old load balancer kept its own URLs/models under `ms.llm.*`. Import the non-default ones once, then
    /// remove the old keys (they hold no secrets).
    static func migrateBalancerSettings(_ ai: NovaAI, defaults: UserDefaults) {
        guard !defaults.bool(forKey: balancerMigratedMarker) else { return }
        defaults.set(true, forKey: balancerMigratedMarker)
        let p = legacyBalancerPrefix
        var s = ai.settings
        let urlMap: [String: NovaAIBackend] = [
            "ollamaURL": .ollama, "tinyLLMURL": .tinyLLM, "tinyChatURL": .tinyChat,
            "openWebUIURL": .openWebUI, "novaGatewayURL": .novaGateway,
        ]
        for (key, backend) in urlMap {
            if let v = defaults.string(forKey: p + key), !v.isEmpty, s.urls[backend.rawValue] == nil, v != backend.defaultURL,
               !legacyBalancerDefaults.contains(v) {
                s.setURL(v, for: backend)
            }
        }
        if let m = defaults.string(forKey: p + "selectedOpenRouterModel"), !m.isEmpty, !legacyBalancerDefaults.contains(m), s.models[NovaAIBackend.openRouter.rawValue] == nil {
            s.setModel(m, for: .openRouter)
        }
        if let m = defaults.string(forKey: p + "selectedOllamaModel"), !m.isEmpty, !legacyBalancerDefaults.contains(m), s.models[NovaAIBackend.ollama.rawValue] == nil {
            s.setModel(m, for: .ollama)
        }
        if s != ai.settings { ai.settings = s }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(p) {
            defaults.removeObject(forKey: key)
        }
    }
}
