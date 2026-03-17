//
//  PIIRedactionManager.swift
//  Mail Summary
//
//  Detects and redacts personally identifiable information (PII) from emails
//  Created by Jordan Koch on 2026-01-30.
//

import Foundation

/// Types of PII that can be detected and redacted
enum PIIType: String, CaseIterable, Codable {
    case email = "Email Addresses"
    case phone = "Phone Numbers"
    case ssn = "Social Security Numbers"
    case creditCard = "Credit Card Numbers"
    case address = "Addresses"
    case name = "Names"
    case custom = "Custom Patterns"

    var icon: String {
        switch self {
        case .email: return "envelope"
        case .phone: return "phone"
        case .ssn: return "person.badge.shield.checkmark"
        case .creditCard: return "creditcard"
        case .address: return "location"
        case .name: return "person"
        case .custom: return "square.and.pencil"
        }
    }

    var redactionPlaceholder: String {
        switch self {
        case .email: return "[EMAIL REDACTED]"
        case .phone: return "[PHONE REDACTED]"
        case .ssn: return "[SSN REDACTED]"
        case .creditCard: return "[CARD REDACTED]"
        case .address: return "[ADDRESS REDACTED]"
        case .name: return "[NAME REDACTED]"
        case .custom: return "[REDACTED]"
        }
    }

    var description: String {
        switch self {
        case .email: return "name@domain.com patterns"
        case .phone: return "(555) 123-4567 patterns"
        case .ssn: return "123-45-6789 patterns"
        case .creditCard: return "4111-1111-1111-1111 patterns"
        case .address: return "Street addresses (limited)"
        case .name: return "Common first/last names"
        case .custom: return "User-defined regex patterns"
        }
    }
}

/// A detected PII instance in text
struct PIIMatch: Identifiable {
    let id = UUID()
    let type: PIIType
    let matchedText: String
    let range: Range<String.Index>
    let confidence: Double  // 0.0 - 1.0

    var displayText: String {
        // Show partial redaction for preview
        let length = matchedText.count
        if length <= 4 {
            return String(repeating: "*", count: length)
        }

        switch type {
        case .email:
            if let atIndex = matchedText.firstIndex(of: "@") {
                let localPart = matchedText[matchedText.startIndex..<atIndex]
                let domainPart = matchedText[atIndex...]
                if localPart.count > 2 {
                    return String(localPart.prefix(2)) + "***" + domainPart
                }
            }
            return matchedText.prefix(2) + "***"
        case .phone:
            return "***-***-" + matchedText.suffix(4)
        case .ssn:
            return "***-**-" + matchedText.suffix(4)
        case .creditCard:
            return "****-****-****-" + matchedText.suffix(4)
        default:
            return matchedText.prefix(2) + "***" + matchedText.suffix(2)
        }
    }
}

/// Result of PII scan on text
struct PIIScanResult {
    let originalText: String
    let matches: [PIIMatch]
    let redactedText: String

    var piiCount: Int { matches.count }
    var hasPII: Bool { !matches.isEmpty }

    var countByType: [PIIType: Int] {
        var counts: [PIIType: Int] = [:]
        for match in matches {
            counts[match.type, default: 0] += 1
        }
        return counts
    }
}

/// Manager for PII detection and redaction
@MainActor
class PIIRedactionManager: ObservableObject {
    static let shared = PIIRedactionManager()

    @Published var isScanning = false
    @Published var lastScanResults: [Int: PIIScanResult] = [:]  // Email ID -> Result
    @Published var enabledTypes: Set<PIIType> = Set(PIIType.allCases.filter { $0 != .custom })
    @Published var customPatterns: [CustomPIIPattern] = []

    // Regex patterns for PII detection
    private let patterns: [PIIType: String] = [
        .email: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,
        .phone: #"(?:\+?1?[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}"#,
        .ssn: #"\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b"#,
        .creditCard: #"\b(?:\d{4}[-\s]?){3}\d{4}\b"#,
        .address: #"\d{1,5}\s+\w+(?:\s+\w+)*\s+(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln|Way|Court|Ct|Circle|Cir)"#
    ]

    // Common names for name detection (subset)
    private let commonFirstNames: Set<String> = [
        "james", "john", "robert", "michael", "david", "william", "richard", "joseph", "thomas", "charles",
        "mary", "patricia", "jennifer", "linda", "elizabeth", "barbara", "susan", "jessica", "sarah", "karen",
        "christopher", "daniel", "matthew", "anthony", "mark", "donald", "steven", "paul", "andrew", "joshua"
    ]

    private let commonLastNames: Set<String> = [
        "smith", "johnson", "williams", "brown", "jones", "garcia", "miller", "davis", "rodriguez", "martinez",
        "hernandez", "lopez", "gonzalez", "wilson", "anderson", "thomas", "taylor", "moore", "jackson", "martin",
        "lee", "perez", "thompson", "white", "harris", "sanchez", "clark", "ramirez", "lewis", "robinson"
    ]

    private init() {
        loadCustomPatterns()
    }

    // MARK: - Scanning

    /// Scan text for PII
    func scanText(_ text: String) -> PIIScanResult {
        var allMatches: [PIIMatch] = []

        for type in enabledTypes {
            let matches = detectPII(type: type, in: text)
            allMatches.append(contentsOf: matches)
        }

        // Sort by position (for proper redaction order)
        allMatches.sort { $0.range.lowerBound < $1.range.lowerBound }

        // Create redacted text
        let redactedText = applyRedactions(to: text, matches: allMatches)

        return PIIScanResult(
            originalText: text,
            matches: allMatches,
            redactedText: redactedText
        )
    }

    /// Scan an email for PII
    func scanEmail(_ email: Email) -> PIIScanResult {
        var fullText = email.subject + "\n"
        if let body = email.body {
            fullText += body
        }

        let result = scanText(fullText)
        lastScanResults[email.id] = result
        return result
    }

    /// Scan multiple emails
    func scanEmails(_ emails: [Email]) async -> [Int: PIIScanResult] {
        isScanning = true
        var results: [Int: PIIScanResult] = [:]

        for email in emails {
            results[email.id] = scanEmail(email)
        }

        lastScanResults = results
        isScanning = false
        return results
    }

    // MARK: - Detection Methods

    /// Detect PII of a specific type
    private func detectPII(type: PIIType, in text: String) -> [PIIMatch] {
        switch type {
        case .name:
            return detectNames(in: text)
        case .custom:
            return detectCustomPatterns(in: text)
        default:
            return detectWithRegex(type: type, in: text)
        }
    }

    /// Detect PII using regex pattern
    private func detectWithRegex(type: PIIType, in text: String) -> [PIIMatch] {
        guard let pattern = patterns[type],
              let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)

        return matches.compactMap { match -> PIIMatch? in
            guard let swiftRange = Range(match.range, in: text) else { return nil }
            let matchedText = String(text[swiftRange])

            // Validate specific types
            let confidence = validateMatch(type: type, text: matchedText)
            guard confidence > 0.5 else { return nil }

            return PIIMatch(
                type: type,
                matchedText: matchedText,
                range: swiftRange,
                confidence: confidence
            )
        }
    }

    /// Detect names using dictionary matching
    private func detectNames(in text: String) -> [PIIMatch] {
        var matches: [PIIMatch] = []
        let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted)

        var currentIndex = text.startIndex

        for word in words {
            let lowercased = word.lowercased()

            if commonFirstNames.contains(lowercased) || commonLastNames.contains(lowercased) {
                // Find the range in the original text
                if let range = text.range(of: word, range: currentIndex..<text.endIndex) {
                    matches.append(PIIMatch(
                        type: .name,
                        matchedText: word,
                        range: range,
                        confidence: 0.7
                    ))
                    currentIndex = range.upperBound
                }
            } else if let range = text.range(of: word, range: currentIndex..<text.endIndex) {
                currentIndex = range.upperBound
            }
        }

        return matches
    }

    /// Detect custom user-defined patterns
    private func detectCustomPatterns(in text: String) -> [PIIMatch] {
        var matches: [PIIMatch] = []

        for customPattern in customPatterns where customPattern.isEnabled {
            guard let regex = try? NSRegularExpression(pattern: customPattern.pattern, options: [.caseInsensitive]) else {
                continue
            }

            let range = NSRange(text.startIndex..., in: text)
            let regexMatches = regex.matches(in: text, options: [], range: range)

            for match in regexMatches {
                guard let swiftRange = Range(match.range, in: text) else { continue }

                matches.append(PIIMatch(
                    type: .custom,
                    matchedText: String(text[swiftRange]),
                    range: swiftRange,
                    confidence: 0.9
                ))
            }
        }

        return matches
    }

    /// Validate a PII match for accuracy
    private func validateMatch(type: PIIType, text: String) -> Double {
        switch type {
        case .ssn:
            // SSN validation: Must be 9 digits
            let digits = text.filter { $0.isNumber }
            if digits.count != 9 { return 0.0 }
            // Common invalid SSNs
            if digits.hasPrefix("000") || digits.hasPrefix("666") || digits.hasPrefix("9") { return 0.3 }
            return 0.95

        case .creditCard:
            // Luhn algorithm check
            let digits = text.filter { $0.isNumber }
            if digits.count < 13 || digits.count > 19 { return 0.0 }
            return luhnCheck(digits) ? 0.95 : 0.3

        case .phone:
            let digits = text.filter { $0.isNumber }
            if digits.count < 10 || digits.count > 11 { return 0.0 }
            return 0.9

        default:
            return 0.9
        }
    }

    /// Luhn algorithm for credit card validation
    private func luhnCheck(_ digits: String) -> Bool {
        var sum = 0
        let digitArray = Array(digits.reversed())

        for (index, char) in digitArray.enumerated() {
            guard let digit = Int(String(char)) else { return false }

            if index % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }

        return sum % 10 == 0
    }

    // MARK: - Redaction

    /// Apply redactions to text
    private func applyRedactions(to text: String, matches: [PIIMatch]) -> String {
        guard !matches.isEmpty else { return text }

        var result = text
        // Process in reverse order to preserve string indices
        for match in matches.reversed() {
            let replacement = match.type.redactionPlaceholder
            result.replaceSubrange(match.range, with: replacement)
        }

        return result
    }

    /// Get redacted version of email
    func getRedactedEmail(_ email: Email) -> (subject: String, body: String?) {
        let subjectResult = scanText(email.subject)
        let bodyResult = email.body.map { scanText($0) }

        return (
            subject: subjectResult.redactedText,
            body: bodyResult?.redactedText
        )
    }

    // MARK: - Custom Patterns

    /// Add a custom PII pattern
    func addCustomPattern(name: String, pattern: String) {
        let custom = CustomPIIPattern(name: name, pattern: pattern, isEnabled: true)
        customPatterns.append(custom)
        saveCustomPatterns()
    }

    /// Remove a custom pattern
    func removeCustomPattern(id: UUID) {
        customPatterns.removeAll { $0.id == id }
        saveCustomPatterns()
    }

    /// Toggle custom pattern
    func toggleCustomPattern(id: UUID) {
        if let index = customPatterns.firstIndex(where: { $0.id == id }) {
            customPatterns[index].isEnabled.toggle()
            saveCustomPatterns()
        }
    }

    private func saveCustomPatterns() {
        if let data = try? JSONEncoder().encode(customPatterns) {
            UserDefaults.standard.set(data, forKey: "PIIRedactionManager_CustomPatterns")
        }
    }

    private func loadCustomPatterns() {
        if let data = UserDefaults.standard.data(forKey: "PIIRedactionManager_CustomPatterns"),
           let patterns = try? JSONDecoder().decode([CustomPIIPattern].self, from: data) {
            customPatterns = patterns
        }
    }

    // MARK: - Statistics

    /// Get total PII found across all scanned emails
    var totalPIIFound: Int {
        lastScanResults.values.reduce(0) { $0 + $1.piiCount }
    }

    /// Get count by PII type across all scanned emails
    func countByType() -> [PIIType: Int] {
        var totals: [PIIType: Int] = [:]
        for result in lastScanResults.values {
            for (type, count) in result.countByType {
                totals[type, default: 0] += count
            }
        }
        return totals
    }
}

/// Custom user-defined PII pattern
struct CustomPIIPattern: Identifiable, Codable {
    let id: UUID
    let name: String
    let pattern: String
    var isEnabled: Bool

    init(name: String, pattern: String, isEnabled: Bool = true) {
        self.id = UUID()
        self.name = name
        self.pattern = pattern
        self.isEnabled = isEnabled
    }
}
