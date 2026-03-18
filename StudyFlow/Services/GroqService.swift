import Foundation

// MARK: - Parsed output models

struct ParsedSyllabus: Codable {
    var course: ParsedCourse
    var assignments: [ParsedAssignment]
}

struct ParsedCourse: Codable {
    var courseCode: String
    var title: String
    var description: String
    var professorName: String
    var term: String
    var meetingTimes: String?
    var location: String?
}

struct ParsedAssignment: Codable, Identifiable {
    var id = UUID()
    var title: String
    var description: String
    var dueDateString: String   // "YYYY-MM-DD"
    var type: String
    var totalPoints: Int

    private enum CodingKeys: String, CodingKey {
        case title, description, dueDateString, type, totalPoints
    }

    var dueDate: Date {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: dueDateString) ?? Date()
    }

    var validType: String {
        let valid = ["reading","essay","homework","quiz","exam",
                     "project","presentation","response","custom"]
        return valid.contains(type) ? type : "custom"
    }
}

// MARK: - Service

class GroqService {
    static let shared = GroqService()

    private let endpoint = "https://api.groq.com/openai/v1/chat/completions"
    private let model    = "llama-3.3-70b-versatile"

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "groq_api_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "groq_api_key") }
    }

    var hasApiKey: Bool { !apiKey.isEmpty }

    private let systemPrompt = """
    You are a syllabus parser. Extract course information and all graded assignments \
    from the provided syllabus text. Return ONLY valid JSON, no markdown, no explanation:
    {
      "course": {
        "courseCode": "string (e.g. SOC 1010)",
        "title": "string",
        "description": "1-2 sentence course overview",
        "professorName": "string",
        "term": "string (e.g. Spring 2026)",
        "meetingTimes": "string or null",
        "location": "string or null"
      },
      "assignments": [
        {
          "title": "string",
          "description": "brief description of what is required",
          "dueDateString": "YYYY-MM-DD",
          "type": "reading|essay|homework|quiz|exam|project|presentation|response|custom",
          "totalPoints": integer
        }
      ]
    }
    For due dates, infer the year from the term. If only a week is mentioned, \
    use Thursday of that week. Include every distinct graded assignment.
    """

    // Entry point: tries Apple Intelligence first, falls back to Groq
    func parseSyllabus(text: String) async throws -> ParsedSyllabus {
        if #available(iOS 18.1, *) {
            if let result = try? await parseWithAppleIntelligence(text: text) {
                return result
            }
        }
        return try await parseWithGroq(text: text)
    }

    // MARK: - Groq (cloud, OpenAI-compatible)

    private func parseWithGroq(text: String) async throws -> ParsedSyllabus {
        guard !apiKey.isEmpty else { throw GroqError.missingApiKey }

        let body: [String: Any] = [
            "model": model,
            "temperature": 0.1,
            "max_tokens": 4096,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "Parse this syllabus:\n\n\(text)"]
            ]
        ]

        var req = URLRequest(url: URL(string: endpoint)!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown"
            throw GroqError.networkError("HTTP error: \(msg)")
        }

        guard
            let json    = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else { throw GroqError.parseError("Unexpected response shape") }

        return try decodeSyllabus(content)
    }

    // MARK: - Apple Intelligence (on-device, iOS 18.1+)

    @available(iOS 18.1, *)
    private func parseWithAppleIntelligence(text: String) async throws -> ParsedSyllabus {
        // Use FoundationModels for on-device structured extraction.
        // Falls through to Groq if the device doesn't support Apple Intelligence.
        guard let result = try? await AppleIntelligenceParser.shared.parse(text: text) else {
            throw GroqError.appleIntelligenceUnavailable
        }
        return result
    }

    // MARK: - JSON cleanup & decode

    func decodeSyllabus(_ raw: String) throws -> ParsedSyllabus {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```json") { s = String(s.dropFirst(7)) }
        if s.hasPrefix("```")    { s = String(s.dropFirst(3))  }
        if s.hasSuffix("```")    { s = String(s.dropLast(3))   }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let d = s.data(using: .utf8) else {
            throw GroqError.parseError("UTF-8 encoding failed")
        }
        return try JSONDecoder().decode(ParsedSyllabus.self, from: d)
    }
}

// MARK: - Errors

enum GroqError: LocalizedError {
    case missingApiKey
    case networkError(String)
    case parseError(String)
    case appleIntelligenceUnavailable

    var errorDescription: String? {
        switch self {
        case .missingApiKey:              return "Groq API key not set — add it in Settings (⚙)."
        case .networkError(let m):        return "Network error: \(m)"
        case .parseError(let m):          return "Parse error: \(m)"
        case .appleIntelligenceUnavailable: return "Apple Intelligence unavailable on this device."
        }
    }
}
