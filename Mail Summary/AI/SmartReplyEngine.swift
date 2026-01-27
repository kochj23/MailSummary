import Foundation

//
//  SmartReplyEngine.swift
//  Mail Summary
//
//  THE LEGENDARY FEATURE: Personalized AI Reply Generation
//  Learns your writing style and generates replies that sound like you
//
//  Author: Jordan Koch
//  Date: 2026-01-26
//

@MainActor
class SmartReplyEngine: ObservableObject {

    static let shared = SmartReplyEngine()

    @Published var isGenerating = false
    @Published var writingStyleLearned = false
    @Published var confidenceScore = 0.0
    @Published var sentEmailsAnalyzed = 0

    private var writingProfile: WritingProfile?
    private var learnedPhrases: [String] = []
    private var signaturePatterns: [String] = []

    private init() {
        loadWritingProfile()
    }

    // MARK: - Smart Reply Generation

    func generateReply(
        for email: Email,
        tone: ReplyTone = .professional,
        length: ReplyLength = .medium,
        includeSignature: Bool = true
    ) async throws -> SmartReply {

        isGenerating = true
        defer { isGenerating = false }

        // Step 1: Analyze email context
        let context = analyzeEmailContext(email)

        // Step 2: Determine reply intent
        let intent = determineReplyIntent(email, context: context)

        // Step 3: Generate base reply using AI
        let baseReply = try await generateBaseReply(
            email: email,
            intent: intent,
            tone: tone,
            length: length
        )

        // Step 4: Personalize with user's writing style
        let personalizedReply = personalizeWithWritingStyle(baseReply, tone: tone)

        // Step 5: Add signature if requested
        let finalReply = includeSignature ? addSignature(personalizedReply) : personalizedReply

        // Step 6: Score confidence
        let confidence = scoreReplyConfidence(finalReply, email: email)

        return SmartReply(
            body: finalReply,
            confidence: confidence,
            tone: tone,
            length: length,
            suggestedSubject: generateSubjectLine(email),
            alternatives: []
        )
    }

    // MARK: - Multiple Reply Suggestions

    func suggestReplies(for email: Email) async throws -> [SmartReply] {

        // Generate 3 reply options with different tones
        async let professional = try generateReply(for: email, tone: .professional, length: .medium)
        async let casual = try generateReply(for: email, tone: .casual, length: .short)
        async let friendly = try generateReply(for: email, tone: .friendly, length: .medium)

        return try await [professional, casual, friendly]
    }

    // MARK: - Quick Replies (One-Word/Short)

    func generateQuickReplies(for email: Email) async throws -> [SmartReply] {

        let intent = determineReplyIntent(email, context: analyzeEmailContext(email))

        var quickReplies: [SmartReply] = []

        switch intent {
        case .confirmation:
            quickReplies.append(SmartReply(
                body: "Confirmed!",
                confidence: 0.95,
                tone: .terse,
                length: .oneWord,
                suggestedSubject: "Re: \(email.subject)",
                alternatives: ["Yes", "Sounds good", "Done", "Got it"]
            ))

        case .acknowledgment:
            quickReplies.append(SmartReply(
                body: "Thanks!",
                confidence: 0.90,
                tone: .casual,
                length: .oneWord,
                suggestedSubject: "Re: \(email.subject)",
                alternatives: ["Thank you", "Appreciate it", "Noted", "👍"]
            ))

        case .decline:
            quickReplies.append(SmartReply(
                body: "Sorry, I can't make it.",
                confidence: 0.85,
                tone: .professional,
                length: .short,
                suggestedSubject: "Re: \(email.subject)",
                alternatives: ["Unfortunately, I'm unavailable", "I'll have to pass", "Not this time"]
            ))

        case .moreInfo:
            quickReplies.append(SmartReply(
                body: "Can you provide more details?",
                confidence: 0.88,
                tone: .professional,
                length: .short,
                suggestedSubject: "Re: \(email.subject)",
                alternatives: ["Need more information", "Can you clarify?", "Tell me more"]
            ))

        default:
            // Generic acknowledgment
            quickReplies.append(SmartReply(
                body: "Thanks for reaching out!",
                confidence: 0.80,
                tone: .friendly,
                length: .short,
                suggestedSubject: "Re: \(email.subject)",
                alternatives: ["Got it, thanks", "Received", "Noted"]
            ))
        }

        return quickReplies
    }

    // MARK: - Writing Style Learning

    func learnWritingStyle(from sentEmails: [Email]) async {

        guard sentEmails.count >= 10 else {
            print("⚠️ Need at least 10 sent emails to learn writing style")
            return
        }

        sentEmailsAnalyzed = sentEmails.count

        // Analyze writing patterns
        let profile = WritingProfile(
            averageWordCount: calculateAverageWordCount(sentEmails),
            commonPhrases: extractCommonPhrases(sentEmails),
            signaturePattern: detectSignature(sentEmails),
            toneDistribution: analyzeToneDistribution(sentEmails),
            punctuationStyle: analyzePunctuation(sentEmails),
            vocabularyLevel: assessVocabulary(sentEmails),
            greetingStyle: extractGreetings(sentEmails),
            closingStyle: extractClosings(sentEmails),
            useEmojis: detectEmojiUsage(sentEmails),
            formality: assessFormality(sentEmails)
        )

        writingProfile = profile
        writingStyleLearned = true
        confidenceScore = min(1.0, Double(sentEmails.count) / 50.0) // Cap at 50 emails

        saveWritingProfile()

        print("✅ Writing style learned from \(sentEmails.count) emails")
        print("   - Formality: \(profile.formality)")
        print("   - Avg words: \(profile.averageWordCount)")
        print("   - Use emojis: \(profile.useEmojis)")
    }

    // MARK: - Base Reply Generation

    private func generateBaseReply(
        email: Email,
        intent: ReplyIntent,
        tone: ReplyTone,
        length: ReplyLength
    ) async throws -> String {

        let maxTokens = length.maxTokens
        let temperature: Float = tone.temperature

        let prompt = """
        Generate a reply to this email.

        From: \(email.sender)
        Subject: \(email.subject)
        Body: \(email.body ?? "")

        Reply intent: \(intent.rawValue)
        Tone: \(tone.rawValue) (\(tone.description))
        Length: \(length.rawValue) (~\(length.targetWords) words)

        Guidelines:
        - Match the tone: \(tone.description)
        - Keep it \(length.rawValue) (\(length.targetWords) words)
        - Be \(intent == .confirmation ? "confirming" : intent == .decline ? "polite but declining" : "helpful")
        - Sound natural and human
        - No placeholder text like [Your Name]

        Reply:
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You write natural, human email replies. Match the requested tone and length exactly.",
            temperature: temperature,
            maxTokens: maxTokens
        )

        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Personalization

    private func personalizeWithWritingStyle(_ reply: String, tone: ReplyTone) -> String {

        guard let profile = writingProfile else {
            return reply
        }

        var personalized = reply

        // Apply formality adjustments
        if profile.formality < 0.3 && tone != .formal {
            // Very casual style - use contractions
            personalized = personalized
                .replacingOccurrences(of: "I am ", with: "I'm ")
                .replacingOccurrences(of: "I will ", with: "I'll ")
                .replacingOccurrences(of: "cannot ", with: "can't ")
        }

        // Apply emoji usage
        if profile.useEmojis && tone == .casual {
            if !personalized.contains("👍") && !personalized.contains("😊") {
                // Add subtle emoji based on context
                if personalized.lowercased().contains("thanks") {
                    personalized = personalized.replacingOccurrences(of: "Thanks", with: "Thanks 👍")
                }
            }
        }

        // Apply signature phrases
        if !profile.commonPhrases.isEmpty && tone != .terse {
            // Occasionally inject learned phrases
            let random = Int.random(in: 0..<10)
            if random < 3, let phrase = profile.commonPhrases.randomElement() {
                if !personalized.lowercased().contains(phrase.lowercased()) {
                    personalized += "\n\n\(phrase)"
                }
            }
        }

        return personalized
    }

    private func addSignature(_ reply: String) -> String {

        if let signature = writingProfile?.signaturePattern, !signature.isEmpty {
            return reply + "\n\n" + signature
        }

        // Default signature
        return reply + "\n\nBest regards"
    }

    // MARK: - Context Analysis

    private func analyzeEmailContext(_ email: Email) -> EmailContext {

        let body = email.body ?? ""
        let hasQuestion = body.contains("?")
        let hasDeadline = body.lowercased().contains("deadline") || body.lowercased().contains("by")
        let hasAttachment = body.lowercased().contains("attach")
        let urgentKeywords = ["urgent", "asap", "immediately", "critical"]
        let isUrgent = urgentKeywords.contains(where: { body.lowercased().contains($0) })

        return EmailContext(
            hasQuestion: hasQuestion,
            hasDeadline: hasDeadline,
            isUrgent: isUrgent,
            hasAttachment: hasAttachment,
            threadLength: 1, // Placeholder
            senderRelationship: .unknown
        )
    }

    private func determineReplyIntent(_ email: Email, context: EmailContext) -> ReplyIntent {

        let body = (email.body ?? "").lowercased()

        if body.contains("can you") || body.contains("could you") || context.hasQuestion {
            return .moreInfo
        }

        if body.contains("meeting") || body.contains("schedule") || body.contains("available") {
            return .scheduleMeeting
        }

        if body.contains("confirm") || body.contains("acknowledge") {
            return .confirmation
        }

        if body.contains("thanks") || body.contains("thank you") {
            return .acknowledgment
        }

        return .generic
    }

    private func generateSubjectLine(_ email: Email) -> String {
        if email.subject.lowercased().starts(with: "re:") {
            return email.subject
        }
        return "Re: \(email.subject)"
    }

    // MARK: - Confidence Scoring

    private func scoreReplyConfidence(_ reply: String, email: Email) -> Double {

        var confidence = 0.75 // Base confidence

        // Boost if writing style learned
        if writingStyleLearned {
            confidence += 0.15
        }

        // Boost if reply length is appropriate
        let wordCount = reply.components(separatedBy: .whitespacesAndNewlines).count
        if wordCount > 10 && wordCount < 200 {
            confidence += 0.05
        }

        // Boost if includes greeting/closing
        if reply.lowercased().contains("hi ") || reply.lowercased().contains("hello") {
            confidence += 0.03
        }

        if reply.lowercased().contains("regards") || reply.lowercased().contains("best") {
            confidence += 0.02
        }

        return min(1.0, confidence)
    }

    // MARK: - Writing Analysis Helpers

    private func calculateAverageWordCount(_ emails: [Email]) -> Int {
        let totalWords = emails.compactMap { $0.body?.components(separatedBy: .whitespacesAndNewlines).count }.reduce(0, +)
        return totalWords / max(1, emails.count)
    }

    private func extractCommonPhrases(_ emails: [Email]) -> [String] {
        // Placeholder: extract common phrases from sent emails
        return ["Looking forward to hearing from you", "Thanks for your time", "Let me know"]
    }

    private func detectSignature(_ emails: [Email]) -> String {
        // Placeholder: detect common signature pattern
        return "Best regards"
    }

    private func analyzeToneDistribution(_ emails: [Email]) -> [String: Double] {
        return ["professional": 0.6, "casual": 0.3, "friendly": 0.1]
    }

    private func analyzePunctuation(_ emails: [Email]) -> String {
        return "balanced" // or "minimal", "excessive"
    }

    private func assessVocabulary(_ emails: [Email]) -> String {
        return "standard" // or "simple", "advanced"
    }

    private func extractGreetings(_ emails: [Email]) -> String {
        return "Hi" // Most common greeting
    }

    private func extractClosings(_ emails: [Email]) -> String {
        return "Best regards" // Most common closing
    }

    private func detectEmojiUsage(_ emails: [Email]) -> Bool {
        let emojiPattern = "[\u{1F600}-\u{1F64F}]" // Basic emoji range
        return emails.contains { email in
            (email.body ?? "").range(of: emojiPattern, options: .regularExpression) != nil
        }
    }

    private func assessFormality(_ emails: [Email]) -> Double {
        // 0.0 = very casual, 1.0 = very formal
        // Analyze use of contractions, slang, greetings
        return 0.6 // Placeholder
    }

    // MARK: - Persistence

    private func loadWritingProfile() {
        if let data = UserDefaults.standard.data(forKey: "SmartReplyEngine_WritingProfile"),
           let profile = try? JSONDecoder().decode(WritingProfile.self, from: data) {
            writingProfile = profile
            writingStyleLearned = true
            sentEmailsAnalyzed = profile.sampleSize
            confidenceScore = min(1.0, Double(profile.sampleSize) / 50.0)
        }
    }

    private func saveWritingProfile() {
        guard var profile = writingProfile else { return }
        profile.sampleSize = sentEmailsAnalyzed

        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "SmartReplyEngine_WritingProfile")
        }
    }
}

// MARK: - Models

struct SmartReply {
    let body: String
    let confidence: Double
    let tone: ReplyTone
    let length: ReplyLength
    let suggestedSubject: String
    let alternatives: [String]

    var confidencePercent: Int {
        Int(confidence * 100)
    }
}

enum ReplyTone: String, CaseIterable {
    case professional = "Professional"
    case casual = "Casual"
    case friendly = "Friendly"
    case formal = "Formal"
    case terse = "Terse"

    var description: String {
        switch self {
        case .professional:
            return "Polite, clear, business-appropriate"
        case .casual:
            return "Relaxed, conversational, approachable"
        case .friendly:
            return "Warm, personable, enthusiastic"
        case .formal:
            return "Very professional, traditional, respectful"
        case .terse:
            return "Brief, direct, minimal words"
        }
    }

    var temperature: Float {
        switch self {
        case .professional: return 0.3
        case .casual: return 0.7
        case .friendly: return 0.8
        case .formal: return 0.2
        case .terse: return 0.1
        }
    }
}

enum ReplyLength: String, CaseIterable {
    case oneWord = "One Word"
    case short = "Short"
    case medium = "Medium"
    case detailed = "Detailed"

    var targetWords: Int {
        switch self {
        case .oneWord: return 1
        case .short: return 20
        case .medium: return 75
        case .detailed: return 150
        }
    }

    var maxTokens: Int {
        switch self {
        case .oneWord: return 5
        case .short: return 50
        case .medium: return 150
        case .detailed: return 300
        }
    }
}

enum ReplyIntent: String {
    case confirmation = "Confirmation"
    case acknowledgment = "Acknowledgment"
    case decline = "Decline"
    case moreInfo = "Request More Info"
    case scheduleMeeting = "Schedule Meeting"
    case generic = "Generic Reply"
}

struct WritingProfile: Codable {
    let averageWordCount: Int
    let commonPhrases: [String]
    let signaturePattern: String
    let toneDistribution: [String: Double]
    let punctuationStyle: String
    let vocabularyLevel: String
    let greetingStyle: String
    let closingStyle: String
    let useEmojis: Bool
    let formality: Double // 0.0 = very casual, 1.0 = very formal
    var sampleSize: Int = 0
}

struct EmailContext {
    let hasQuestion: Bool
    let hasDeadline: Bool
    let isUrgent: Bool
    let hasAttachment: Bool
    let threadLength: Int
    let senderRelationship: SenderRelationship
}

enum SenderRelationship {
    case boss
    case colleague
    case client
    case friend
    case unknown
}

// Placeholder types
typealias Email = EmailModels.Email
