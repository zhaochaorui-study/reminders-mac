import Foundation

struct AIParseResult: Sendable {
    let title: String
    let scheduledAt: Date
}

private struct AIServiceConfiguration: Sendable {
    let apiURL: URL
    let apiKey: String
    let model: String
}

private enum AIServiceConfigurationLoader {
    private enum Defaults {
        static let apiURL = "https://api.deepseek.com/v1/chat/completions"
        static let model = "deepseek-chat"
        static let bundleEnvironmentResourceName = "AIConfig"
        static let bundleEnvironmentResourceExtension = "env"
        static let localEnvironmentFileName = ".env.local"
    }

    static func load() throws -> AIServiceConfiguration {
        let values = mergedValues()
        let apiKey = try requiredValue(named: "DEEPSEEK_API_KEY", from: values)
        let apiURLString = sanitizedValue(named: "DEEPSEEK_API_URL", from: values) ?? Defaults.apiURL
        let model = sanitizedValue(named: "DEEPSEEK_MODEL", from: values) ?? Defaults.model

        guard let apiURL = URL(string: apiURLString) else {
            throw AIServiceError.invalidConfiguration("DEEPSEEK_API_URL")
        }

        return AIServiceConfiguration(apiURL: apiURL, apiKey: apiKey, model: model)
    }

    private static func mergedValues() -> [String: String] {
        var values = loadFileBackedValues()

        for (key, rawValue) in ProcessInfo.processInfo.environment {
            guard let value = normalizedValue(rawValue) else { continue }
            values[key] = value
        }

        return values
    }

    private static func loadFileBackedValues() -> [String: String] {
        for url in candidateEnvironmentFileURLs() {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            return parseEnvironmentFile(at: url)
        }

        return [:]
    }

    private static func candidateEnvironmentFileURLs() -> [URL] {
        var urls: [URL] = []

        if let bundleURL = Bundle.main.url(
            forResource: Defaults.bundleEnvironmentResourceName,
            withExtension: Defaults.bundleEnvironmentResourceExtension
        ) {
            urls.append(bundleURL)
        }

        let currentDirectoryURL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        urls.append(currentDirectoryURL.appendingPathComponent(Defaults.localEnvironmentFileName))

        return urls
    }

    private static func parseEnvironmentFile(at url: URL) -> [String: String] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return [:]
        }

        var values: [String: String] = [:]
        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            let declaration = normalizedDeclaration(from: line)
            let segments = declaration.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard segments.count == 2 else { continue }

            let key = String(segments[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let rawValue = String(segments[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, let value = normalizedValue(rawValue) else { continue }

            values[key] = value
        }

        return values
    }

    private static func normalizedDeclaration(from line: String) -> String {
        guard line.hasPrefix("export ") else { return line }
        return String(line.dropFirst("export ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func requiredValue(named name: String, from values: [String: String]) throws -> String {
        guard let value = sanitizedValue(named: name, from: values) else {
            throw AIServiceError.missingConfiguration(name)
        }

        return value
    }

    private static func sanitizedValue(named name: String, from values: [String: String]) -> String? {
        guard let rawValue = values[name] else { return nil }
        return normalizedValue(rawValue)
    }

    private static func normalizedValue(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.count >= 2, trimmed.hasPrefix("\""), trimmed.hasSuffix("\"") {
            return String(trimmed.dropFirst().dropLast())
        }

        if trimmed.count >= 2, trimmed.hasPrefix("'"), trimmed.hasSuffix("'") {
            return String(trimmed.dropFirst().dropLast())
        }

        return trimmed
    }
}

final class AIService: @unchecked Sendable {
    static let shared = AIService()

    private let relativeMinutesPatterns = [
        #"(\d+)\s*(?:个)?\s*(?:分钟|分|mins?|minutes?)\s*(?:后|之后|以后)"#,
        #"(\d+)\s*(?:minute|minutes)\s*later"#
    ]
    private let relativeHoursPatterns = [
        #"(\d+)\s*(?:个)?\s*(?:小时|h|hours?)\s*(?:后|之后|以后)"#,
        #"(\d+)\s*(?:hour|hours)\s*later"#
    ]

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = TimeZone.current
        return f
    }()

    private let currentDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm EEEE"
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone.current
        return f
    }()

    func parse(_ input: String) async throws -> AIParseResult {
        let configuration = try AIServiceConfigurationLoader.load()
        let referenceDate = Date()
        let now = currentDateFormatter.string(from: referenceDate)

        let systemPrompt = """
        你是一个待办事项解析助手。用户会输入一段自然语言描述的待办事项，你需要从中提取：
        1. title: 待办事项的标题（简洁明了）
        2. scheduled_at: 提醒时间，格式为 yyyy-MM-dd HH:mm

        当前时间是：\(now)

        规则：
        - 如果用户说"明天"，就是明天
        - 如果用户说"下午3点"，就是15:00
        - 如果用户说"X分钟后"或"X min后"，就是当前时间按分钟对齐到00秒后再加X分钟
        - 如果用户说"半小时后"，就是当前时间按分钟对齐到00秒后再加30分钟
        - 如果用户说"X小时后"，就是当前时间按分钟对齐到00秒后再加X小时
        - 如果用户没有指定具体时间，默认设为当天的09:00
        - 如果用户没有指定日期，默认为今天
        - 如果无法从输入中识别出待办事项内容，返回 {"error": "no_title"}
        - 如果无法从输入中识别出时间信息，返回 {"error": "no_time"}
        - 如果输入完全无法理解，返回 {"error": "unknown"}
        - 只返回JSON，不要返回其他内容

        成功时返回格式（严格JSON）：
        {"title": "待办标题", "scheduled_at": "2026-03-17 15:00"}
        """

        let body: [String: Any] = [
            "model": configuration.model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": input]
            ],
            "temperature": 0.1,
            "max_tokens": 200
        ]

        var request = URLRequest(url: configuration.apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AIServiceError.requestFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw AIServiceError.invalidResponse
        }

        let result = try parseJSON(content)
        return AIParseResult(
            title: result.title,
            scheduledAt: resolvedScheduledAt(for: input, fallback: result.scheduledAt, referenceDate: referenceDate)
        )
    }

    private func parseJSON(_ content: String) throws -> AIParseResult {
        let jsonStr: String
        if let start = content.range(of: "{"), let end = content.range(of: "}", options: .backwards) {
            jsonStr = String(content[start.lowerBound...end.lowerBound])
        } else {
            jsonStr = content
        }

        guard let data = jsonStr.data(using: .utf8),
              let parsed = try JSONSerialization.jsonObject(with: data) as? [String: String]
        else {
            throw AIServiceError.parseFailed
        }

        if let error = parsed["error"] {
            switch error {
            case "no_title": throw AIServiceError.noTitle
            case "no_time": throw AIServiceError.noTime
            default: throw AIServiceError.unrecognized
            }
        }

        guard let title = parsed["title"],
              let scheduledStr = parsed["scheduled_at"],
              let date = dateFormatter.date(from: scheduledStr)
        else {
            throw AIServiceError.parseFailed
        }

        return AIParseResult(title: title, scheduledAt: date)
    }

    private func resolvedScheduledAt(for input: String, fallback: Date, referenceDate: Date) -> Date {
        relativeScheduledAt(from: input, referenceDate: referenceDate) ?? fallback
    }

    private func relativeScheduledAt(from input: String, referenceDate: Date) -> Date? {
        let normalizedInput = input.lowercased()
        let alignedReferenceDate = minuteAlignedDate(from: referenceDate)

        if normalizedInput.contains("半小时后")
            || normalizedInput.contains("半小时之后")
            || normalizedInput.contains("半小时以后")
            || normalizedInput.contains("半个小时后")
            || normalizedInput.contains("半个小时之后")
            || normalizedInput.contains("半个小时以后") {
            return alignedReferenceDate.addingTimeInterval(30 * 60)
        }

        if let minutes = firstMatchedInteger(in: normalizedInput, patterns: relativeMinutesPatterns) {
            return alignedReferenceDate.addingTimeInterval(Double(minutes) * 60)
        }

        if let hours = firstMatchedInteger(in: normalizedInput, patterns: relativeHoursPatterns) {
            return alignedReferenceDate.addingTimeInterval(Double(hours) * 60 * 60)
        }

        return nil
    }

    private func minuteAlignedDate(from referenceDate: Date) -> Date {
        Calendar.autoupdatingCurrent.dateInterval(of: .minute, for: referenceDate)?.start ?? referenceDate
    }

    private func firstMatchedInteger(in input: String, patterns: [String]) -> Int? {
        for pattern in patterns {
            guard let value = firstMatchedInteger(in: input, pattern: pattern) else { continue }
            return value
        }

        return nil
    }

    private func firstMatchedInteger(in input: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        guard let match = regex.firstMatch(in: input, options: [], range: range),
              match.numberOfRanges > 1,
              let matchRange = Range(match.range(at: 1), in: input)
        else {
            return nil
        }

        return Int(input[matchRange])
    }
}

enum AIServiceError: LocalizedError {
    case missingConfiguration(String)
    case invalidConfiguration(String)
    case requestFailed
    case invalidResponse
    case parseFailed
    case noTitle
    case noTime
    case unrecognized

    var errorDescription: String? {
        switch self {
        case .missingConfiguration(let key):
            return "AI 配置缺失：\(key)，请在 .env.local 或环境变量里补上"
        case .invalidConfiguration(let key):
            return "AI 配置无效：\(key)，检查一下格式别写飞了"
        case .requestFailed:
            return "AI 解析失败，请稍后重试"
        case .invalidResponse:
            return "AI 返回内容不可用，请稍后重试"
        case .parseFailed:
            return "解析结果失败，请换个说法试试"
        case .noTitle:
            return "没识别到待办事项，试试描述具体要做什么"
        case .noTime:
            return "没识别到时间，试试加上「明天」「3点」「10分钟后」"
        case .unrecognized:
            return "没理解你的意思，试试像「明天下午3点开会」这样描述"
        }
    }
}
