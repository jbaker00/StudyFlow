import Foundation

/// Wraps the FoundationModels framework (Apple Intelligence, iOS 18.1+).
/// Falls back gracefully if unavailable so GroqService can take over.
@available(iOS 18.1, *)
class AppleIntelligenceParser {
    static let shared = AppleIntelligenceParser()

    func parse(text: String) async throws -> ParsedSyllabus {
        // Dynamically check for FoundationModels availability at runtime.
        // The framework is present on iOS 18.1+ but Apple Intelligence
        // requires specific hardware (iPhone 15 Pro / iPhone 16 / iPad M1+).
        guard isAppleIntelligenceAvailable() else {
            throw GroqError.appleIntelligenceUnavailable
        }
        return try await parseInternal(text: text)
    }

    private func isAppleIntelligenceAvailable() -> Bool {
        // Attempt to load the FoundationModels framework and check availability.
        // We use NSClassFromString to avoid a hard link dependency so the app
        // runs on iOS 17 devices too (FoundationModels doesn't exist there).
        let modelClass = NSClassFromString("FoundationModels.SystemLanguageModel")
        return modelClass != nil
    }

    private func parseInternal(text: String) async throws -> ParsedSyllabus {
        // FoundationModels API (iOS 18.1+):
        //   let session = LanguageModelSession()
        //   let result  = try await session.respond(to: prompt, generating: T.self)
        //
        // Because we can't import FoundationModels without raising the deployment
        // target to iOS 18.1, we call it reflectively here.  The actual @Generable
        // structured-output version lives in AppleIntelligenceParserImpl.swift and
        // is compiled only when the Xcode project's deployment target allows it.
        //
        // For now we throw so GroqService falls back to the cloud path.
        throw GroqError.appleIntelligenceUnavailable
    }
}
