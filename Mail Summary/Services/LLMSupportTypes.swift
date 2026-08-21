//
//  LLMSupportTypes.swift
//  Mail Summary
//
//  Supporting types for the multi-model LLM load balancer (ModelRegistry,
//  OpenRouterProvider, KeychainStore, LLMBackendManager). Ported from AIStudio's
//  shared LLM stack so the verbatim template files compile unchanged inside
//  Mail Summary. These live ALONGSIDE the existing `AIBackendManager` /
//  `AIBackend` layer and do not replace it.
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Combine

// MARK: - Backend type (verbatim from AIStudio Models/LLMBackendType.swift)

/// LLM backend type identifier
enum LLMBackendType: String, CaseIterable, Codable, Sendable {
    case ollama = "ollama"
    case mlx = "mlx"
    case tinyLLM = "tinyllm"
    case tinyChat = "tinychat"
    case openWebUI = "openwebui"
    case openRouter = "openrouter"
    case novaGateway = "novagateway"
    case auto = "auto"

    var displayName: String {
        switch self {
        case .ollama: return "Ollama"
        case .mlx: return "MLX Native"
        case .tinyLLM: return "TinyLLM"
        case .tinyChat: return "TinyChat"
        case .openWebUI: return "OpenWebUI"
        case .openRouter: return "OpenRouter (Frontier Models)"
        case .novaGateway: return "Nova Gateway"
        case .auto: return "Auto (Prefer Ollama)"
        }
    }

    var icon: String {
        switch self {
        case .ollama: return "network"
        case .mlx: return "cpu"
        case .tinyLLM: return "cube"
        case .tinyChat: return "bubble.left.and.bubble.right.fill"
        case .openWebUI: return "globe"
        case .openRouter: return "cloud"
        case .novaGateway: return "sparkle.magnifyingglass"
        case .auto: return "sparkles"
        }
    }

    var defaultURL: String {
        switch self {
        case .ollama: return "http://localhost:11434"
        case .mlx: return ""
        case .tinyLLM: return "http://localhost:8000"
        case .tinyChat: return "http://localhost:8000"
        case .openWebUI: return "http://localhost:8080"
        case .openRouter: return OpenRouterProvider.baseURL
        case .novaGateway: return ModelRegistry.novaGatewayDefaultURL
        case .auto: return ""
        }
    }

    var description: String {
        switch self {
        case .ollama: return "HTTP-based LLM API (localhost:11434)"
        case .mlx: return "Apple Silicon native inference via MLX"
        case .tinyLLM: return "TinyLLM lightweight server (localhost:8000)"
        case .tinyChat: return "TinyChat by Jason Cox (localhost:8000)"
        case .openWebUI: return "Self-hosted AI platform (localhost:8080)"
        case .openRouter: return "Frontier cloud models via OpenRouter (bring your own key)"
        case .novaGateway: return "Nova's gateway — OpenAI-compatible, inherits Nova's own routing (127.0.0.1:18792)"
        case .auto: return "Automatically choose best available backend"
        }
    }

    var attribution: String? {
        switch self {
        case .tinyLLM: return "TinyLLM by Jason Cox (https://github.com/jasonacox/TinyLLM)"
        case .tinyChat: return "TinyChat by Jason Cox (https://github.com/jasonacox/tinychat)"
        case .openWebUI: return "OpenWebUI Community Project (https://github.com/open-webui/open-webui)"
        default: return nil
        }
    }
}

/// Connection status for an LLM backend.
enum BackendStatus: Sendable, Equatable {
    case connected
    case disconnected
    case checking
    case error(String)

    var displayText: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .checking: return "Checking..."
        case .error(let msg): return "Error: \(msg)"
        }
    }

    var statusColor: String {
        switch self {
        case .connected: return "green"
        case .disconnected: return "gray"
        case .checking: return "yellow"
        case .error: return "red"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

/// Configuration for a single LLM backend.
struct LLMBackendConfiguration: Identifiable, Sendable {
    let id: UUID
    let type: LLMBackendType
    var url: String
    var status: BackendStatus

    init(type: LLMBackendType, url: String? = nil) {
        self.id = UUID()
        self.type = type
        self.url = url ?? type.defaultURL
        self.status = .disconnected
    }
}

// MARK: - Chat message (verbatim from AIStudio Models/ChatMessage.swift)

/// Role in a chat conversation.
enum ChatRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}

/// A single chat message.
struct ChatMessage: Identifiable, Codable, Sendable {
    let id: UUID
    let role: ChatRole
    var content: String
    let timestamp: Date

    init(role: ChatRole, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

// MARK: - Settings shim

/// Minimal UserDefaults-backed settings store for the multi-model load balancer.
/// Named `AppSettings` so the ported `LLMBackendManager` compiles unchanged.
/// Mail Summary previously had no `AppSettings`, so there is no collision.
///
/// The three load-balancer toggles (`useAllLocalModels`, `enableAllFrontierModels`,
/// `useNovaGateway`) all default to `false` — Nova Gateway is never required and
/// nothing routes through the balancer unless the user opts in.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard
    private static let prefix = "ms.llm."

    // Backend endpoints (Published so LLMBackendManager can observe changes).
    @Published var ollamaURL: String { didSet { save(ollamaURL, "ollamaURL") } }
    @Published var tinyLLMURL: String { didSet { save(tinyLLMURL, "tinyLLMURL") } }
    @Published var tinyChatURL: String { didSet { save(tinyChatURL, "tinyChatURL") } }
    @Published var openWebUIURL: String { didSet { save(openWebUIURL, "openWebUIURL") } }
    @Published var openRouterURL: String { didSet { save(openRouterURL, "openRouterURL") } }
    @Published var novaGatewayURL: String { didSet { save(novaGatewayURL, "novaGatewayURL") } }

    // Selection + model state.
    @Published var activeLLMBackendType: String { didSet { save(activeLLMBackendType, "activeLLMBackendType") } }
    @Published var selectedOllamaModel: String { didSet { save(selectedOllamaModel, "selectedOllamaModel") } }
    @Published var selectedOpenRouterModel: String { didSet { save(selectedOpenRouterModel, "selectedOpenRouterModel") } }

    // Load-balancer toggles (all default off; Nova never required).
    @Published var useAllLocalModels: Bool { didSet { save(useAllLocalModels, "useAllLocalModels") } }
    @Published var enableAllFrontierModels: Bool { didSet { save(enableAllFrontierModels, "enableAllFrontierModels") } }
    @Published var useNovaGateway: Bool { didSet { save(useNovaGateway, "useNovaGateway") } }

    // MLX / Python.
    @Published var pythonPath: String { didSet { save(pythonPath, "pythonPath") } }

    private init() {
        let d = UserDefaults.standard
        let p = AppSettings.prefix
        ollamaURL = d.string(forKey: p + "ollamaURL") ?? "http://localhost:11434"
        tinyLLMURL = d.string(forKey: p + "tinyLLMURL") ?? "http://localhost:8000"
        tinyChatURL = d.string(forKey: p + "tinyChatURL") ?? "http://localhost:8000"
        openWebUIURL = d.string(forKey: p + "openWebUIURL") ?? "http://localhost:8080"
        openRouterURL = d.string(forKey: p + "openRouterURL") ?? OpenRouterProvider.baseURL
        novaGatewayURL = d.string(forKey: p + "novaGatewayURL") ?? ModelRegistry.novaGatewayDefaultURL
        activeLLMBackendType = d.string(forKey: p + "activeLLMBackendType") ?? "auto"
        selectedOllamaModel = d.string(forKey: p + "selectedOllamaModel") ?? "mistral:latest"
        selectedOpenRouterModel = d.string(forKey: p + "selectedOpenRouterModel") ?? OpenRouterProvider.defaultModel
        useAllLocalModels = d.object(forKey: p + "useAllLocalModels") as? Bool ?? false
        enableAllFrontierModels = d.object(forKey: p + "enableAllFrontierModels") as? Bool ?? false
        useNovaGateway = d.object(forKey: p + "useNovaGateway") as? Bool ?? false
        pythonPath = d.string(forKey: p + "pythonPath") ?? "/opt/homebrew/bin/python3"
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: AppSettings.prefix + key)
    }
}
