//
//  AIKitAdoptionTests.swift
//  Mail SummaryTests
//
//  Mail Summary's AI contract on NovaAIKit 1.0.0, in the seven categories: security, performance, retry, unit,
//  integration, functional, frame/UI state. Every test uses an in-memory settings store, an in-memory key store and a
//  stub URLSession: nothing touches the real Keychain or the network. Fixtures are synthetic (example.com).
//

import XCTest
import SwiftUI
import AppKit
import NovaAIKit
@testable import Mail_Summary

// MARK: - Support

/// Stub transport: either refuses every connection or answers every request with `reply` (Ollama /api/chat shape).
final class AIStubProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var replyText: String?
    nonisolated(unsafe) private static var count = 0

    static func refuseAll() { lock.lock(); replyText = nil; count = 0; lock.unlock() }
    static func reply(_ text: String) { lock.lock(); replyText = text; count = 0; lock.unlock() }
    static var requestCount: Int { lock.lock(); defer { lock.unlock() }; return count }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); Self.count += 1; let text = Self.replyText; Self.lock.unlock()
        guard let text, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        let payload: [String: Any] = url.path.hasSuffix("/api/tags")
            ? ["models": [["name": "qwen3:8b"]]]
            : ["message": ["role": "assistant", "content": text], "done": true]
        let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

enum AITestSupport {
    /// Ollama only, so a stubbed reply is the single candidate.
    static let ollamaOnly = NovaAISettings(backend: .ollama)

    @MainActor
    static func makeAI(_ settings: NovaAISettings = NovaAISettings(), keys: NovaAIMemoryKeyStore = NovaAIMemoryKeyStore()) -> NovaAI {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [AIStubProtocol.self]
        return NovaAI(configuration: NovaAIConfiguration(appID: AppAI.appID, appName: AppAI.appName),
                      storage: NovaAIMemoryStorage(settings), keyStore: keys,
                      session: URLSession(configuration: cfg), sleep: { _ in })
    }

    static func email(id: Int = 1, subject: String, sender: String = "Example Sender", body: String? = nil,
                      category: Email.EmailCategory? = nil, isRead: Bool = false) -> Email {
        Email(id: id, messageId: "msg-\(id)", subject: subject, sender: sender, senderEmail: "sender\(id)@example.com",
              dateReceived: Date(), body: body, isRead: isRead, category: category, priority: nil, aiSummary: nil,
              actions: [], senderReputation: nil)
    }

    static let stats = MailboxStats(totalEmails: 12, unreadEmails: 7, todayEmails: 3, highPriorityEmails: 2, actionsCount: 1)

    static func throwaway() -> UserDefaults {
        let name = "MailSummaryAITests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    static var sourceRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }
}

// MARK: - 1. Security

final class AISecurityTests: XCTestCase {
    func testKeychainServiceNames() {
        let c = NovaAIConfiguration(appID: AppAI.appID, appName: AppAI.appName)
        XCTAssertEqual(c.keychainService(for: .openRouter), "com.jkoch.mailsummary.openrouter")
        XCTAssertEqual(c.keychainService(for: .openAI), "com.jkoch.mailsummary.openai")
        XCTAssertEqual(NovaAIConfiguration.keychainAccount, "apiKey")
    }

    @MainActor
    func testPlaintextOpenAIKeyMovesFromDefaultsToKeychain() {
        let defaults = AITestSupport.throwaway()
        defaults.set("placeholder-openai-test-value", forKey: "AIBackend_OpenAI_Key")
        defaults.set("obsolete", forKey: "AIBackend_GoogleCloud_Key")
        defaults.set(["prompt log"], forKey: "AIGuardian_UsageLog")
        let keys = NovaAIMemoryKeyStore()
        let ai = AITestSupport.makeAI(keys: keys)
        AppAI.migrateLegacy(ai, defaults: defaults)
        XCTAssertNil(defaults.object(forKey: "AIBackend_OpenAI_Key"), "plaintext key must leave UserDefaults")
        XCTAssertNil(defaults.object(forKey: "AIBackend_GoogleCloud_Key"))
        XCTAssertNil(defaults.object(forKey: "AIGuardian_UsageLog"))
        XCTAssertTrue(ai.hasAPIKey(for: .openAI))
    }

    @MainActor
    func testLegacyKeychainItemsMigrateAndObsoleteOnesAreDeleted() {
        let keys = NovaAIMemoryKeyStore()
        _ = keys.write("or-test-key", service: AppAI.legacyOpenRouterService, account: "apiKey")
        _ = keys.write("placeholder-legacy-test-value", service: AppAI.legacyBackendService, account: "AIBackend_OpenAI_Key")
        _ = keys.write("gcloud", service: AppAI.legacyBackendService, account: "AIBackend_GoogleCloud_Key")
        _ = keys.write("aws", service: AppAI.legacyBackendService, account: "AIBackend_AWS_SecretKey")
        let ai = AITestSupport.makeAI(keys: keys)
        AppAI.migrateLegacy(ai, defaults: AITestSupport.throwaway())
        XCTAssertTrue(ai.hasAPIKey(for: .openRouter))
        XCTAssertTrue(ai.hasAPIKey(for: .openAI))
        // Shared legacy items are kept (other apps may still read them); removed backends' secrets are gone.
        XCTAssertNotNil(keys.read(service: AppAI.legacyOpenRouterService, account: "apiKey"))
        XCTAssertNil(keys.read(service: AppAI.legacyBackendService, account: "AIBackend_GoogleCloud_Key"))
        XCTAssertNil(keys.read(service: AppAI.legacyBackendService, account: "AIBackend_AWS_SecretKey"))
    }

    @MainActor
    func testKeyedBackendsNeverUsedWithoutKeyOrOverHTTP() async {
        AIStubProtocol.reply(#"{"category":"Bills"}"#)
        var s = NovaAISettings(backend: .openRouter)
        s.setURL("http://openrouter.example.com/api/v1", for: .openRouter)
        let keys = NovaAIMemoryKeyStore()
        let ai = AITestSupport.makeAI(s, keys: keys)
        // No key → nothing is sent.
        XCTAssertTrue(ai.engine.candidates().isEmpty)
        _ = ai.setAPIKey("or-test-key", for: .openRouter)
        let engine = AICategorizationEngine(ai: ai)
        let category = await engine.categorizeEmail(AITestSupport.email(subject: "Your weekly digest"))
        XCTAssertEqual(category, .newsletters, "http URL for a keyed backend must be refused → keyword result")
        XCTAssertEqual(AIStubProtocol.requestCount, 0, "a key must never be sent over plain http")
    }

    func testNoLegacyAIClientInSources() throws {
        let app = AITestSupport.sourceRoot.appendingPathComponent("Mail Summary")
        let banned = ["AIBackendManager.shared", "EthicalAIGuardian", "AIBackendStatusMenu", "OPENAI_API_KEY",
                      "LLMBackendManager", "KeychainStore("]
        let files = FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
        XCTAssertFalse(files.isEmpty)
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for b in banned { XCTAssertFalse(text.contains(b), "\(file.lastPathComponent) still references \(b)") }
        }
    }
}

// MARK: - 2. Performance

final class AIPerformanceTests: XCTestCase {
    @MainActor
    func testOfflineFallbackDoesNotHang() async {
        AIStubProtocol.refuseAll()
        let engine = AICategorizationEngine(ai: AITestSupport.makeAI())
        let start = Date()
        for i in 0..<10 {
            _ = await engine.categorizeEmail(AITestSupport.email(id: i, subject: "Invoice \(i)"))
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 10, "offline categorization must fall back quickly")
    }

    func testKeywordRulesAreFast() {
        let emails = (0..<500).map { AITestSupport.email(id: $0, subject: $0 % 2 == 0 ? "Payment due" : "Weekly digest") }
        measure {
            for e in emails {
                _ = AICategorizationEngine.categorizeWithKeywords(e)
                _ = AICategorizationEngine.scorePriorityWithRules(e)
            }
        }
    }
}

// MARK: - 3. Retry

final class AIRetryTests: XCTestCase {
    @MainActor
    func testInvalidReplyIsRetriedOnceThenFallsBack() async {
        AIStubProtocol.reply(#"{"category":"Groceries"}"#)   // not a category → rejected twice
        let engine = AICategorizationEngine(ai: AITestSupport.makeAI(AITestSupport.ollamaOnly))
        let category = await engine.categorizeEmail(AITestSupport.email(subject: "Invoice for October"))
        XCTAssertEqual(category, .bills, "keyword fallback after the rejected retry")
        XCTAssertEqual(AIStubProtocol.requestCount, 2, "one ask plus one corrective retry")
    }

    func testRetryPolicyIsBounded() {
        let c = NovaAIConfiguration(appID: AppAI.appID, appName: AppAI.appName)
        XCTAssertGreaterThanOrEqual(c.retry.maxAttempts, 1)
        XCTAssertLessThanOrEqual(c.retry.worstCaseSleep, 10)
    }
}

// MARK: - 4. Unit (validators and built-in rules)

final class AIUnitTests: XCTestCase {
    func testCategoryValidator() throws {
        XCTAssertEqual(try AICategorizationEngine.parseCategory(#"{"category":"bills","confidence":0.9}"#), .bills)
        XCTAssertEqual(try AICategorizationEngine.parseCategory("```json\n{\"category\": \"Work\"}\n```"), .work)
        XCTAssertThrowsError(try AICategorizationEngine.parseCategory(#"{"category":"Groceries"}"#))
        XCTAssertThrowsError(try AICategorizationEngine.parseCategory("Bills"))
    }

    func testPriorityValidatorClamps() throws {
        XCTAssertEqual(try AICategorizationEngine.parsePriority(#"{"priority": 42}"#), 10)
        XCTAssertEqual(try AICategorizationEngine.parsePriority(#"{"priority": -3}"#), 1)
        XCTAssertEqual(try AICategorizationEngine.parsePriority(#"{"priority": 7.4}"#), 7)
        XCTAssertThrowsError(try AICategorizationEngine.parsePriority(#"{"priority": "high"}"#))
    }

    func testImportanceAndFactorsClamp() throws {
        XCTAssertEqual(try AICategorizationEngine.parseImportance(#"{"importance": 3}"#), 1)
        XCTAssertEqual(try AICategorizationEngine.parseImportance(#"{"importance": -1}"#), 0)
        let f = try AICategorizationEngine.parseActionableFactors(#"{"hasDeadline": true, "urgencyScore": 9}"#)
        XCTAssertTrue(f.hasDeadline)
        XCTAssertEqual(f.urgencyScore, 1)
    }

    func testActionsValidatorCapsAndCleans() throws {
        let many = (0..<25).map { #"{"type":"weird","text":"Item \#($0)"}"# }.joined(separator: ",")
        let actions = try AICategorizationEngine.parseActions("{\"actions\": [\(many), {\"type\":\"meeting\",\"text\":\"  \"}]}")
        XCTAssertEqual(actions.count, AICategorizationEngine.maxActions)
        XCTAssertTrue(actions.allSatisfy { $0.type == .task && !$0.text.isEmpty })
        XCTAssertTrue(try AICategorizationEngine.parseActions(#"{"actions": []}"#).isEmpty)
        XCTAssertThrowsError(try AICategorizationEngine.parseActions("no json here"))
    }

    func testSummaryValidatorRejectsInventedNumbers() throws {
        let source = "Total emails: 12\nUnread: 7"
        XCTAssertNoThrow(try AICategorizationEngine.validateGroundedSummary("You have 7 unread of 12.", source: source))
        XCTAssertThrowsError(try AICategorizationEngine.validateGroundedSummary("You have 99 unread.", source: source))
        XCTAssertThrowsError(try AICategorizationEngine.validateShortText("   "))
        XCTAssertEqual(try AICategorizationEngine.validateShortText("**Bold** text").contains("*"), false)
    }

    func testQueryAndInsightsValidators() throws {
        let f = try AICategorizationEngine.parseQueryResponse(#"{"category":"Bills","minPriority":50,"unreadOnly":true}"#)
        XCTAssertEqual(f.categories, [.bills])
        XCTAssertEqual(f.minPriority, 10)
        XCTAssertTrue(f.unreadOnly)
        XCTAssertThrowsError(try AICategorizationEngine.parseQueryResponse("sure!"))
        XCTAssertThrowsError(try AICategorizationEngine.parseInsights(#"{"dailyDigest": ""}"#))
        let insights = try AICategorizationEngine.parseInsights(
            #"{"dailyDigest":"Two bills.","recommendations":[{"priority":99,"title":"T","description":"D"}],"predictions":[{"prediction":"P","confidence":4,"basis":"B"}]}"#)
        XCTAssertEqual(insights.recommendations.first?.priority, 10)
        XCTAssertEqual(insights.predictions.first?.confidence, 1)
    }

    func testReplyValidator() throws {
        XCTAssertThrowsError(try ReplyTemplateManager.validateReply("Hi {{name}}, thanks"))
        XCTAssertThrowsError(try ReplyTemplateManager.validateReply(""))
        XCTAssertEqual(try ReplyTemplateManager.validateReply("Thanks, will do."), "Thanks, will do.")
    }

    func testBuiltInRules() {
        XCTAssertEqual(AICategorizationEngine.categorizeWithKeywords(AITestSupport.email(subject: "Invoice #1")), .bills)
        XCTAssertEqual(AICategorizationEngine.scorePriorityWithRules(AITestSupport.email(subject: "URGENT: reply")), 10)
        XCTAssertEqual(AICategorizationEngine.basicEmailSummary(body: "First sentence. Second one. Third."), "First sentence. Second one.")
        let actions = AICategorizationEngine.extractActionsWithRules(subject: "Hello", body: "Please send the form.\nThe report is due Friday.")
        XCTAssertEqual(actions.map(\.type), [.task, .deadline])
        XCTAssertEqual(AICategorizationEngine.basicSenderImportance(openRate: 0.9, category: .work), 1)
        XCTAssertTrue(ReplyTemplateManager.basicSmartReply(sender: "Alex Example", subject: "Lunch").hasPrefix("Hi Alex,"))
    }

    func testBackendSetIsTheKitSet() {
        XCTAssertEqual(NovaAIBackend.allCases.count, 9)
        XCTAssertEqual(NovaAIBackend.novaGateway.rawValue, "novagateway")
        XCTAssertTrue(NovaAIBackend.openRouter.defaultURL.hasPrefix("https://"))
        XCTAssertTrue(NovaAIBackend.openAI.defaultURL.hasPrefix("https://"))
    }
}

// MARK: - 5. Integration (engine ↔ NovaAIKit ↔ stub transport)

final class AIIntegrationTests: XCTestCase {
    @MainActor
    func testValidAIRepliesAreUsed() async {
        let ai = AITestSupport.makeAI(AITestSupport.ollamaOnly)
        let engine = AICategorizationEngine(ai: ai)
        AIStubProtocol.reply(#"{"category":"Work","confidence":0.9}"#)
        let category = await engine.categorizeEmail(AITestSupport.email(subject: "Lunch?"))
        XCTAssertEqual(category, .work)
        AIStubProtocol.reply(#"{"priority": 8}"#)
        let priority = await engine.scoreEmailPriority(AITestSupport.email(subject: "Lunch?"))
        XCTAssertEqual(priority, 8)
        AIStubProtocol.reply("You have 7 unread emails, 2 need attention.")
        let summary = await engine.overallSummary(emails: [], stats: AITestSupport.stats)
        XCTAssertTrue(summary.isAI)
        XCTAssertTrue(summary.source.label.hasPrefix("AI · Ollama"))
        XCTAssertEqual(ai.status.lastSource, summary.source)
    }

    @MainActor
    func testLegacySettingsMigrate() {
        let defaults = AITestSupport.throwaway()
        defaults.set("Ollama", forKey: "AIBackend_Active")
        defaults.set("http://ollama.example.com:11434", forKey: "AIBackend_OllamaURL")
        defaults.set("llama3.2:3b", forKey: "AIBackend_OllamaModel")
        defaults.set("http://nova.example.com:18792", forKey: "ms.llm.novaGatewayURL")
        defaults.set("openai/gpt-4o", forKey: "ms.llm.selectedOpenRouterModel")
        defaults.set("mistral:latest", forKey: "ms.llm.selectedOllamaModel")
        let ai = AITestSupport.makeAI()
        AppAI.migrateLegacy(ai, defaults: defaults)
        XCTAssertEqual(ai.settings.backend, .ollama)
        XCTAssertEqual(ai.settings.url(for: .ollama), "http://ollama.example.com:11434")
        XCTAssertEqual(ai.settings.model(for: .ollama), "llama3.2:3b", "old balancer default must not override the user's model")
        XCTAssertEqual(ai.settings.url(for: .novaGateway), "http://nova.example.com:18792")
        XCTAssertEqual(ai.settings.model(for: .openRouter), "openai/gpt-4o")
        XCTAssertNil(defaults.object(forKey: "ms.llm.novaGatewayURL"), "old balancer keys are removed")
        // Idempotent: a second run changes nothing.
        let before = ai.settings
        AppAI.migrateLegacy(ai, defaults: defaults)
        XCTAssertEqual(ai.settings, before)
    }
}

// MARK: - 6. Functional (every feature works with AI off and offline)

final class AIFunctionalTests: XCTestCase {
    @MainActor
    private func runAllFeatures(_ engine: AICategorizationEngine) async -> [String] {
        let bill = AITestSupport.email(subject: "Invoice: payment due", body: "Your invoice is attached. Payment is due Friday.")
        var out: [String] = []
        out.append(await engine.categorizeEmail(bill).rawValue)
        out.append(String(await engine.scoreEmailPriority(bill)))
        out.append(await engine.generateSummary(for: bill) ?? "")
        out.append(String(await engine.extractActions(from: bill).count))
        out.append(await engine.generateOverallSummary(emails: [bill], stats: AITestSupport.stats))
        out.append(String(await engine.analyzeSenderImportance(bill, emailHistory: [bill])))
        out.append(String(await engine.detectActionableFactors(bill).hasPayment))
        out.append(String(await engine.parseNaturalLanguageQuery("unread bills today").unreadOnly))
        out.append(await engine.generateInsights(emails: [bill], analytics: EmailAnalytics()).dailyDigest)
        return out
    }

    @MainActor
    func testEveryFeatureWorksWithAIOff() async {
        AIStubProtocol.reply(#"{"category":"Spam"}"#)
        let ai = AITestSupport.makeAI(NovaAISettings(enabled: false))
        let out = await runAllFeatures(AICategorizationEngine(ai: ai))
        XCTAssertEqual(out[0], "Bills")
        XCTAssertEqual(out[1], "9")
        XCTAssertEqual(out[2], "Your invoice is attached. Payment is due Friday.")
        XCTAssertEqual(out[3], "1")
        XCTAssertTrue(out[4].contains("7 unread"))
        XCTAssertEqual(out[6], "true")
        XCTAssertEqual(out[7], "true")
        XCTAssertFalse(out[8].isEmpty)
        XCTAssertEqual(AIStubProtocol.requestCount, 0, "AI off: nothing is sent")
        XCTAssertEqual(ai.status.state, .off)
    }

    @MainActor
    func testEveryFeatureFallsBackWhenOffline() async {
        AIStubProtocol.refuseAll()
        let ai = AITestSupport.makeAI()
        let out = await runAllFeatures(AICategorizationEngine(ai: ai))
        XCTAssertEqual(out[0], "Bills")
        XCTAssertEqual(out[1], "9")
        XCTAssertFalse(out[2].isEmpty)
        XCTAssertTrue(out[4].contains("7 unread"))
        XCTAssertFalse(out[8].isEmpty)
        if case .fallback = ai.status.lastSource {} else { XCTFail("last source should be the built-in fallback") }
    }
}

// MARK: - 7. Frame / UI state

final class AIFrameTests: XCTestCase {
    @MainActor
    func testStatusReflectsOnOffAndOffline() async {
        AIStubProtocol.refuseAll()
        let ai = AITestSupport.makeAI(AITestSupport.ollamaOnly)
        await ai.refreshStatus()
        XCTAssertNotEqual(ai.status.state, .online)
        XCTAssertFalse(ai.status.isReachable)
        ai.settings.enabled = false
        XCTAssertEqual(ai.status.state, .off)
        XCTAssertNotEqual(NovaAIStatusIndicator.color(.off), NovaAIStatusIndicator.color(.online))
    }

    @MainActor
    func testStatusGoesOnlineWithReachableBackend() async {
        AIStubProtocol.reply("ok")
        let ai = AITestSupport.makeAI(AITestSupport.ollamaOnly)
        await ai.refreshStatus()
        XCTAssertEqual(ai.status.state, .online)
        XCTAssertEqual(ai.status.activeBackend, .ollama)
    }

    @MainActor
    func testSettingsAndIndicatorViewsBuild() {
        let ai = AITestSupport.makeAI()
        let settings = NSHostingView(rootView: NovaAISettingsView(ai: ai, footer: "When AI is off, Mail Summary uses built-in rules."))
        settings.frame = NSRect(x: 0, y: 0, width: 560, height: 520)
        settings.layoutSubtreeIfNeeded()
        let indicator = NSHostingView(rootView: NovaAIStatusIndicator(ai: ai, checksOnAppear: false))
        indicator.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(settings.fittingSize.width, 0)
        XCTAssertGreaterThan(indicator.fittingSize.width, 0)
    }
}
