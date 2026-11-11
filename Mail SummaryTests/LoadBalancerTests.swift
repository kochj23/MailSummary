//
//  LoadBalancerTests.swift
//  Mail SummaryTests
//
//  The old in-app multi-model load balancer (ModelRegistry / LoadBalancer / LLMBackendType) was replaced by
//  NovaAIKit's Auto failover. These deterministic (no-network) tests keep the same coverage against the kit:
//  backend set, failover order, local-endpoint spreading, health gating and keyed-backend gating.
//
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
import NovaAIKit
@testable import Mail_Summary

final class LoadBalancerTests: XCTestCase {

    private func engine(_ settings: NovaAISettings, keys: NovaAIMemoryKeyStore = NovaAIMemoryKeyStore(),
                        health: NovaAIHealth? = nil) -> NovaAIEngine {
        let cfg = NovaAIConfiguration(appID: AppAI.appID, appName: AppAI.appName)
        return NovaAIEngine(configuration: cfg, settings: settings, keys: NovaAIKeys(configuration: cfg, store: keys),
                            health: health, sleep: { _ in })
    }

    // MARK: - Backend types

    func testNovaGatewayBackendType() {
        XCTAssertEqual(NovaAIBackend.novaGateway.rawValue, "novagateway")
        XCTAssertEqual(NovaAIBackend.novaGateway.defaultURL, "http://127.0.0.1:18792")
        XCTAssertFalse(NovaAIBackend.novaGateway.symbolName.isEmpty)
        XCTAssertEqual(NovaAIBackend.allCases.count, 9)
    }

    func testLegacyBackendNamesMap() {
        XCTAssertEqual(NovaAIBackend(legacyName: "Ollama"), .ollama)
        XCTAssertEqual(NovaAIBackend(legacyName: "OpenAI"), .openAI)
    }

    // MARK: - Failover order (replaces the old FailoverPlanner chain)

    func testAutoChainIsLocalFirstThenCloud() {
        let chain = engine(NovaAISettings()).chain()
        XCTAssertEqual(chain.first, .ollama)
        XCTAssertEqual(Array(chain.suffix(2)), [.openRouter, .openAI])
        XCTAssertLessThan(chain.firstIndex(of: .novaGateway)!, chain.firstIndex(of: .openRouter)!)
    }

    func testExplicitBackendIsTheOnlyCandidate() {
        XCTAssertEqual(engine(NovaAISettings(backend: .tinyChat)).chain(), [.tinyChat])
    }

    // MARK: - Pool composition (all-local balancing → extra Ollama endpoints)

    func testExtraOllamaEndpointsJoinThePool() {
        var s = NovaAISettings(backend: .ollama)
        s.extraOllamaEndpoints = [NovaAIEndpoint(url: "http://gpu-a.example.com:11434", model: "llama3.2:3b"),
                                  NovaAIEndpoint(url: "http://gpu-b.example.com:11434", model: "")]
        let c = engine(s).candidates()
        XCTAssertEqual(c.count, 3)
        XCTAssertEqual(c[1].model, "llama3.2:3b")
        XCTAssertEqual(c[2].model, s.model(for: .ollama), "an endpoint without a model uses the configured one")
    }

    func testDuplicateEndpointsAreDeduplicated() {
        var s = NovaAISettings(backend: .ollama)
        s.extraOllamaEndpoints = [NovaAIEndpoint(url: s.url(for: .ollama), model: "")]
        XCTAssertEqual(engine(s).candidates().count, 1)
    }

    // MARK: - Frontier models (OpenRouter) gated by a Keychain key

    func testFrontierModelsNeedAKey() {
        let keys = NovaAIMemoryKeyStore()
        XCTAssertFalse(engine(NovaAISettings(), keys: keys).candidates().contains { $0.backend == .openRouter })
        let cfg = NovaAIConfiguration(appID: AppAI.appID, appName: AppAI.appName)
        _ = keys.write("placeholder", service: cfg.keychainService(for: .openRouter), account: NovaAIConfiguration.keychainAccount)
        XCTAssertTrue(engine(NovaAISettings(), keys: keys).candidates().contains { $0.backend == .openRouter })
    }

    // MARK: - Health gating

    func testHealthMarksExpire() {
        final class Clock: @unchecked Sendable { var now = Date(timeIntervalSince1970: 0) }
        let clock = Clock()
        let health = NovaAIHealth(ttl: 60, now: { clock.now })
        health.mark("http://a.example.com", ok: false)
        XCTAssertEqual(health.status("http://a.example.com"), false)
        XCTAssertNil(health.status("http://b.example.com"))
        clock.now = clock.now.addingTimeInterval(120)
        XCTAssertNil(health.status("http://a.example.com"), "a stale failure no longer excludes the endpoint")
        health.mark("http://a.example.com", ok: true)
        health.reset()
        XCTAssertNil(health.status("http://a.example.com"))
    }
}
