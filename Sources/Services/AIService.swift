import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct AIParseResult: Sendable {
    let title: String
    let scheduledAt: Date
    let recurrenceRule: RecurrenceRule?
}

enum AISystemDefaultModelStatus: Equatable, Sendable {
    case available
    case unavailable(String)
}

struct AIServiceConfiguration: Sendable {
    let apiURL: URL
    let apiKey: String
    let apiSecret: String
    let model: String
}

enum AIServiceConfigurationLoader {
    private enum Defaults {
        static let deepSeekAPIURL = "https://api.deepseek.com/v1/chat/completions"
        static let deepSeekModel = "deepseek-chat"
        static let bundleEnvironmentResourceName = "AIConfig"
        static let bundleEnvironmentResourceExtension = "env"
        static let localEnvironmentFileName = ".env.local"
    }

    private enum SystemDefaultEnvironmentKeys {
        static let apiKey = "DEEPSEEK_API_KEY"
        static let apiSecret = "DEEPSEEK_API_SECRET"
        static let apiURL = "DEEPSEEK_API_URL"
        static let model = "DEEPSEEK_MODEL"
    }

    private enum CustomEnvironmentKeys {
        static let apiKey = "LLM_API_KEY"
        static let apiSecret = "LLM_API_SECRET"
        static let apiURL = "LLM_API_URL"
        static let model = "LLM_MODEL"
    }

    private struct ConfigurationKeySet {
        let apiKey: String
        let apiSecret: String
        let apiURL: String
        let model: String
        let defaultAPIURL: String
        let defaultModel: String
        let fallbackAPIKey: String?
        let fallbackAPISecret: String?
        let fallbackAPIURL: String?
        let fallbackModel: String?
    }

    private static let systemDefaultKeySet = ConfigurationKeySet(
        apiKey: SystemDefaultEnvironmentKeys.apiKey,
        apiSecret: SystemDefaultEnvironmentKeys.apiSecret,
        apiURL: SystemDefaultEnvironmentKeys.apiURL,
        model: SystemDefaultEnvironmentKeys.model,
        defaultAPIURL: Defaults.deepSeekAPIURL,
        defaultModel: Defaults.deepSeekModel,
        fallbackAPIKey: nil,
        fallbackAPISecret: nil,
        fallbackAPIURL: nil,
        fallbackModel: nil
    )

    private static let customKeySet = ConfigurationKeySet(
        apiKey: CustomEnvironmentKeys.apiKey,
        apiSecret: CustomEnvironmentKeys.apiSecret,
        apiURL: CustomEnvironmentKeys.apiURL,
        model: CustomEnvironmentKeys.model,
        defaultAPIURL: Defaults.deepSeekAPIURL,
        defaultModel: Defaults.deepSeekModel,
        fallbackAPIKey: SystemDefaultEnvironmentKeys.apiKey,
        fallbackAPISecret: SystemDefaultEnvironmentKeys.apiSecret,
        fallbackAPIURL: SystemDefaultEnvironmentKeys.apiURL,
        fallbackModel: SystemDefaultEnvironmentKeys.model
    )

    static func loadCustomConfiguration() throws -> AIServiceConfiguration {
        let values = mergedValues()
        return try configuration(from: values, keySet: customKeySet)
    }

    static func loadSystemDefaultConfiguration() throws -> AIServiceConfiguration {
        let values = mergedValues()
        return try configuration(from: values, keySet: systemDefaultKeySet)
    }

    static func persistedCustomConfiguration() -> (apiBaseURL: String, apiKey: String, model: String) {
        let fileValues = loadFileBackedValues()

        let apiBaseURL = sanitizedValue(named: CustomEnvironmentKeys.apiURL, from: fileValues)
            ?? sanitizedValue(named: SystemDefaultEnvironmentKeys.apiURL, from: fileValues)
            ?? LocalSecretsStore.value(for: .llmAPIBaseURL)
        let apiKey = sanitizedValue(named: CustomEnvironmentKeys.apiKey, from: fileValues)
            ?? sanitizedValue(named: SystemDefaultEnvironmentKeys.apiKey, from: fileValues)
            ?? LocalSecretsStore.value(for: .llmAPIKey)
        let model = sanitizedValue(named: CustomEnvironmentKeys.model, from: fileValues)
            ?? sanitizedValue(named: SystemDefaultEnvironmentKeys.model, from: fileValues)
            ?? Defaults.deepSeekModel

        return (apiBaseURL, apiKey, model)
    }

    static func saveCustomConfiguration(apiBaseURL: String, apiKey: String, model: String) {
        let normalizedAPIBaseURL = normalizedValue(apiBaseURL)
        let normalizedAPIKey = normalizedValue(apiKey)
        let normalizedModel = normalizedValue(model)
        let updatedContent = updatedEnvironmentFileContent(
            from: preferredEnvironmentFileContent(),
            updates: [
                CustomEnvironmentKeys.apiURL: normalizedAPIBaseURL,
                CustomEnvironmentKeys.apiKey: normalizedAPIKey,
                CustomEnvironmentKeys.model: normalizedModel,
            ]
        )

        guard let targetURL = preferredEnvironmentFileURLForWriting() else {
            NSLog("[AIConfig] 未找到可写的 .env.local 路径")
            return
        }

        do {
            try writeEnvironmentFileContent(updatedContent, to: targetURL)

            if let bundleURL = bundleEnvironmentFileURL(), bundleURL != targetURL {
                try? writeEnvironmentFileContent(updatedContent, to: bundleURL)
            }
        } catch {
            NSLog("[AIConfig] 写入环境配置失败: %@", error.localizedDescription)
        }
    }

    static func load(
        overridingAPIBaseURL apiBaseURL: String? = nil,
        apiKey: String? = nil,
        model: String? = nil
    ) throws -> AIServiceConfiguration {
        var values = mergedValues()

        if let apiBaseURL {
            if let normalizedAPIBaseURL = normalizedValue(apiBaseURL) {
                values[CustomEnvironmentKeys.apiURL] = normalizedAPIBaseURL
            } else {
                values.removeValue(forKey: CustomEnvironmentKeys.apiURL)
            }
        }

        if let apiKey {
            if let normalizedAPIKey = normalizedValue(apiKey) {
                values[CustomEnvironmentKeys.apiKey] = normalizedAPIKey
            } else {
                values.removeValue(forKey: CustomEnvironmentKeys.apiKey)
            }
        }

        if let model {
            if let normalizedModel = normalizedValue(model) {
                values[CustomEnvironmentKeys.model] = normalizedModel
            } else {
                values.removeValue(forKey: CustomEnvironmentKeys.model)
            }
        }

        return try configuration(from: values, keySet: customKeySet)
    }

    private static func configuration(
        from values: [String: String],
        keySet: ConfigurationKeySet
    ) throws -> AIServiceConfiguration {
        let apiKey = try requiredValue(named: keySet.apiKey, fallbackName: keySet.fallbackAPIKey, from: values)
        let apiSecret = sanitizedValue(named: keySet.apiSecret, fallbackName: keySet.fallbackAPISecret, from: values) ?? ""
        let apiURLString = sanitizedValue(named: keySet.apiURL, fallbackName: keySet.fallbackAPIURL, from: values) ?? keySet.defaultAPIURL
        let model = sanitizedValue(named: keySet.model, fallbackName: keySet.fallbackModel, from: values) ?? keySet.defaultModel

        guard let apiURL = resolvedAPIURL(from: apiURLString) else {
            throw AIServiceError.invalidConfiguration(keySet.apiURL)
        }

        return AIServiceConfiguration(apiURL: apiURL, apiKey: apiKey, apiSecret: apiSecret, model: model)
    }

    private static func mergedValues() -> [String: String] {
        var values = loadFileBackedValues()

        for (key, rawValue) in ProcessInfo.processInfo.environment {
            guard let value = normalizedValue(rawValue) else { continue }
            values[key] = value
        }

        for (key, value) in savedPreferenceValues() {
            values[key] = value
        }

        return values
    }

    private static func savedPreferenceValues() -> [String: String] {
        var values: [String: String] = [:]

        if let apiBaseURL = normalizedValue(ReminderPreferenceStorage.llmAPIBaseURL()) {
            values[CustomEnvironmentKeys.apiURL] = apiBaseURL
        }

        if let apiKey = normalizedValue(ReminderPreferenceStorage.llmAPIKey()) {
            values[CustomEnvironmentKeys.apiKey] = apiKey
        }

        if let apiSecret = normalizedValue(ReminderPreferenceStorage.llmAPISecret()) {
            values[CustomEnvironmentKeys.apiSecret] = apiSecret
        }

        if let model = normalizedValue(ReminderPreferenceStorage.llmModel()) {
            values[CustomEnvironmentKeys.model] = model
        }

        return values
    }

    private static func resolvedAPIURL(from rawValue: String) -> URL? {
        guard let url = URL(string: rawValue),
              let scheme = url.scheme, !scheme.isEmpty,
              let host = url.host, !host.isEmpty,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return nil
        }

        components.path = normalizedAPIPath(from: components.path)
        return components.url
    }

    private static func normalizedAPIPath(from path: String) -> String {
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmedPath.isEmpty else {
            return "/v1/chat/completions"
        }

        if trimmedPath.hasSuffix("chat/completions") {
            return "/\(trimmedPath)"
        }

        return "/\(trimmedPath)/chat/completions"
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

        if let projectEnvironmentURL = projectEnvironmentFileURL() {
            urls.append(projectEnvironmentURL)
        }

        if let bundleURL = bundleEnvironmentFileURL() {
            urls.append(bundleURL)
        }

        let currentDirectoryURL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        let currentDirectoryEnvironmentURL = currentDirectoryURL.appendingPathComponent(Defaults.localEnvironmentFileName)
        if urls.contains(currentDirectoryEnvironmentURL) == false {
            urls.append(currentDirectoryEnvironmentURL)
        }

        return urls
    }

    private static func bundleEnvironmentFileURL() -> URL? {
        Bundle.main.url(
            forResource: Defaults.bundleEnvironmentResourceName,
            withExtension: Defaults.bundleEnvironmentResourceExtension
        )
    }

    private static func projectEnvironmentFileURL() -> URL? {
        for baseURL in searchBaseURLs() {
            if let projectDirectoryURL = nearestProjectDirectory(startingAt: baseURL) {
                return projectDirectoryURL.appendingPathComponent(Defaults.localEnvironmentFileName)
            }
        }

        return nil
    }

    private static func preferredEnvironmentFileURLForWriting() -> URL? {
        if let projectEnvironmentURL = projectEnvironmentFileURL() {
            return projectEnvironmentURL
        }

        if let bundleURL = bundleEnvironmentFileURL() {
            return bundleURL
        }

        let currentDirectoryURL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        return currentDirectoryURL.appendingPathComponent(Defaults.localEnvironmentFileName)
    }

    private static func searchBaseURLs() -> [URL] {
        var urls: [URL] = []
        let currentDirectoryURL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        urls.append(currentDirectoryURL)

        let bundleAncestorsBaseURL = Bundle.main.bundleURL.deletingLastPathComponent()
        if urls.contains(bundleAncestorsBaseURL) == false {
            urls.append(bundleAncestorsBaseURL)
        }

        return urls
    }

    private static func nearestProjectDirectory(startingAt baseURL: URL) -> URL? {
        var currentURL = baseURL.standardizedFileURL

        while true {
            let packageURL = currentURL.appendingPathComponent("Package.swift")
            let gitURL = currentURL.appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: packageURL.path)
                || FileManager.default.fileExists(atPath: gitURL.path) {
                return currentURL
            }

            let parentURL = currentURL.deletingLastPathComponent()
            if parentURL == currentURL {
                return nil
            }

            currentURL = parentURL
        }
    }

    private static func preferredEnvironmentFileContent() -> String {
        for url in candidateEnvironmentFileURLs() {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            return content
        }

        return ""
    }

    private static func updatedEnvironmentFileContent(
        from content: String,
        updates: [String: String?]
    ) -> String {
        var lines = content.components(separatedBy: .newlines)
        if lines.count == 1, lines[0].isEmpty {
            lines = []
        }

        for (key, value) in updates {
            applyEnvironmentUpdate(key: key, value: value, to: &lines)
        }

        while let lastLine = lines.last,
              lastLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.removeLast()
        }

        guard lines.isEmpty == false else { return "" }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func applyEnvironmentUpdate(
        key: String,
        value: String?,
        to lines: inout [String]
    ) {
        let matchingIndexes = lines.indices.filter { index in
            environmentKey(from: lines[index]) == key
        }

        if let firstIndex = matchingIndexes.first {
            if let value {
                lines[firstIndex] = "\(key)=\(value)"
            } else {
                lines.remove(at: firstIndex)
            }

            for index in matchingIndexes.dropFirst().reversed() {
                lines.remove(at: index)
            }
            return
        }

        guard let value else { return }
        lines.append("\(key)=\(value)")
    }

    private static func environmentKey(from line: String) -> String? {
        let normalizedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedLine.isEmpty == false, normalizedLine.hasPrefix("#") == false else {
            return nil
        }

        let declaration = normalizedDeclaration(from: normalizedLine)
        let segments = declaration.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        guard segments.isEmpty == false else { return nil }

        let key = String(segments[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }

    private static func writeEnvironmentFileContent(_ content: String, to url: URL) throws {
        let directoryURL = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
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

    private static func requiredValue(
        named name: String,
        fallbackName: String? = nil,
        from values: [String: String]
    ) throws -> String {
        guard let value = sanitizedValue(named: name, fallbackName: fallbackName, from: values) else {
            throw AIServiceError.missingConfiguration(name)
        }

        return value
    }

    private static func sanitizedValue(
        named name: String,
        fallbackName: String? = nil,
        from values: [String: String]
    ) -> String? {
        if let rawValue = values[name], let normalized = normalizedValue(rawValue) {
            return normalized
        }

        guard let fallbackName, let rawValue = values[fallbackName] else { return nil }
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

    func systemDefaultModelStatus() -> AISystemDefaultModelStatus {
        do {
            _ = try AIServiceConfigurationLoader.loadSystemDefaultConfiguration()
            return .available
        } catch let error as AIServiceError {
            return .unavailable(systemDefaultModelUnavailableMessage(for: error))
        } catch {
            return .unavailable("DeepSeek 默认配置当前不可用")
        }
    }

    func parse(_ input: String) async throws -> AIParseResult {
        let referenceDate = Date()
        if ReminderPreferenceStorage.prefersSystemDefaultAIModel() {
            switch systemDefaultModelStatus() {
            case .available:
                return try await parseWithSystemDefaultModel(input, referenceDate: referenceDate)
            case .unavailable(let reason):
                do {
                    return try await parseWithRemoteModel(input, referenceDate: referenceDate)
                } catch let error as AIServiceError where error.isConfigurationError {
                    throw AIServiceError.systemDefaultModelUnavailable(reason)
                }
            }
        }

        return try await parseWithRemoteModel(input, referenceDate: referenceDate)
    }

    func testConnection(apiBaseURL: String, apiKey: String) async throws -> String {
        let configuration = try AIServiceConfigurationLoader.load(
            overridingAPIBaseURL: apiBaseURL,
            apiKey: apiKey,
            model: nil
        )

        let json = try await requestChatCompletions(
            configuration: configuration,
            messages: [
                ["role": "user", "content": "Reply with OK only."]
            ],
            temperature: 0,
            maxTokens: 8
        )
        try validateCompletionResponse(json)
        return configuration.model
    }

    func testConnection(apiBaseURL: String, apiKey: String, model: String) async throws -> String {
        let configuration = try AIServiceConfigurationLoader.load(
            overridingAPIBaseURL: apiBaseURL,
            apiKey: apiKey,
            model: model
        )

        let json = try await requestChatCompletions(
            configuration: configuration,
            messages: [
                ["role": "user", "content": "Reply with OK only."]
            ],
            temperature: 0,
            maxTokens: 8
        )
        try validateCompletionResponse(json)
        return configuration.model
    }

    private func parseWithRemoteModel(_ input: String, referenceDate: Date) async throws -> AIParseResult {
        let configuration = try AIServiceConfigurationLoader.loadCustomConfiguration()
        let json = try await requestChatCompletions(
            configuration: configuration,
            messages: [
                ["role": "system", "content": parsingInstructions(referenceDate: referenceDate)],
                ["role": "user", "content": input]
            ],
            temperature: 0.1,
            maxTokens: 200
        )
        let content = try extractMessageContent(from: json)
        let result = try parseJSON(content)
        return finalizedParseResult(result, for: input, referenceDate: referenceDate)
    }

    private func parsingInstructions(referenceDate: Date) -> String {
        let now = currentDateFormatter.string(from: referenceDate)

        return """
        你是一个待办事项解析助手。用户会输入一段自然语言描述的待办事项，你需要从中提取：
        1. title: 待办事项的标题（简洁明了）
        2. scheduled_at: 首次提醒时间，格式为 yyyy-MM-dd HH:mm
        3. recurrence: 可选的重复规则

        当前时间是：\(now)

        规则：
        - 如果用户说"明天"，就是明天
        - 如果用户说"下午3点"，就是15:00
        - 如果用户说"X分钟后"或"X min后"，就是当前时间按分钟对齐到00秒后再加X分钟
        - 如果用户说"半小时后"，就是当前时间按分钟对齐到00秒后再加30分钟
        - 如果用户说"X小时后"，就是当前时间按分钟对齐到00秒后再加X小时
        - 如果用户没有指定具体时间，默认设为当天的09:00
        - 如果用户没有指定日期，默认为今天
        - 如果用户说"每天"、"每日"，recurrence 为 {"type":"daily","hour":H,"minute":M}（从 scheduled_at 提取时分）
        - 如果用户说"每周X"、"每个周X"，recurrence 为 {"type":"weekly","weekday":W,"hour":H,"minute":M}（weekday: 1=周日,2=周一...7=周六）
        - 如果用户没有提到重复，不要返回 recurrence 字段
        - 如果无法从输入中识别出待办事项内容，返回 {"error": "no_title"}
        - 如果无法从输入中识别出时间信息，返回 {"error": "no_time"}
        - 如果输入完全无法理解，返回 {"error": "unknown"}
        - 只返回JSON，不要返回其他内容

        成功时返回格式（严格JSON）：
        {"title": "待办标题", "scheduled_at": "2026-03-17 15:00"}
        或带重复：
        {"title": "待办标题", "scheduled_at": "2026-03-17 15:00", "recurrence": {"type": "daily", "hour": 15, "minute": 0}}
        """
    }

    private func finalizedParseResult(
        _ result: AIParseResult,
        for input: String,
        referenceDate: Date
    ) -> AIParseResult {
        AIParseResult(
            title: result.title,
            scheduledAt: resolvedScheduledAt(for: input, fallback: result.scheduledAt, referenceDate: referenceDate),
            recurrenceRule: result.recurrenceRule
        )
    }

    private func parseWithSystemDefaultModel(_ input: String, referenceDate: Date) async throws -> AIParseResult {
        let configuration = try AIServiceConfigurationLoader.loadSystemDefaultConfiguration()
        let json = try await requestChatCompletions(
            configuration: configuration,
            messages: [
                ["role": "system", "content": parsingInstructions(referenceDate: referenceDate)],
                ["role": "user", "content": input]
            ],
            temperature: 0.1,
            maxTokens: 200
        )
        let content = try extractMessageContent(from: json)
        let result = try parseJSON(content)
        return finalizedParseResult(result, for: input, referenceDate: referenceDate)
    }

    private func systemDefaultModelUnavailableMessage(
        for reason: Any
    ) -> String {
        if let error = reason as? AIServiceError {
            switch error {
            case .missingConfiguration:
                return "DeepSeek 默认配置缺失"
            case .invalidConfiguration:
                return "DeepSeek 默认配置无效"
            case .systemDefaultModelUnavailable(let message):
                return message
            default:
                return error.localizedDescription
            }
        }

        return "DeepSeek 默认配置当前不可用"
    }

    private func requestChatCompletions(
        configuration: AIServiceConfiguration,
        messages: [[String: String]],
        temperature: Double,
        maxTokens: Int
    ) async throws -> [String: Any] {
        let body: [String: Any] = [
            "model": configuration.model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": maxTokens
        ]

        var request = URLRequest(url: configuration.apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        if !configuration.apiSecret.isEmpty {
            request.setValue(configuration.apiSecret, forHTTPHeaderField: "X-API-Secret")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIServiceError.requestFailed(statusCode: nil, message: error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw AIServiceError.requestFailed(
                statusCode: httpResponse.statusCode,
                message: extractErrorMessage(from: data)
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIServiceError.invalidResponse
        }

        return json
    }

    private func extractMessageContent(from json: [String: Any]) throws -> String {
        guard let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first
        else {
            throw AIServiceError.invalidResponse
        }

        if let message = firstChoice["message"] as? [String: Any],
           let content = messageContent(from: message) {
            return content
        }

        if let content = firstChoice["text"] as? String,
           let normalized = normalizedText(content) {
            return normalized
        }

        throw AIServiceError.invalidResponse
    }

    private func validateCompletionResponse(_ json: [String: Any]) throws {
        guard let choices = json["choices"] as? [[String: Any]], !choices.isEmpty else {
            throw AIServiceError.invalidResponse
        }
    }

    private func messageContent(from message: [String: Any]) -> String? {
        if let content = message["content"] as? String {
            return normalizedText(content)
        }

        if let contentParts = message["content"] as? [[String: Any]] {
            let text = contentParts
                .compactMap { part -> String? in
                    guard let value = part["text"] as? String else { return nil }
                    return normalizedText(value)
                }
                .joined(separator: "\n")

            return normalizedText(text)
        }

        return nil
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            guard let rawText = String(data: data, encoding: .utf8) else { return nil }
            return normalizedText(rawText)
        }

        if let error = json["error"] as? [String: Any] {
            if let message = error["message"] as? String,
               let normalized = normalizedText(message) {
                return normalized
            }

            if let code = error["code"] as? String,
               let normalized = normalizedText(code) {
                return normalized
            }
        }

        if let message = json["message"] as? String,
           let normalized = normalizedText(message) {
            return normalized
        }

        return nil
    }

    private func normalizedText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func parseJSON(_ content: String) throws -> AIParseResult {
        let jsonStr: String
        if let start = content.range(of: "{"), let end = content.range(of: "}", options: .backwards) {
            jsonStr = String(content[start.lowerBound...end.lowerBound])
        } else {
            jsonStr = content
        }

        guard let data = jsonStr.data(using: .utf8),
              let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw AIServiceError.parseFailed
        }

        if let error = parsed["error"] as? String {
            switch error {
            case "no_title": throw AIServiceError.noTitle
            case "no_time": throw AIServiceError.noTime
            default: throw AIServiceError.unrecognized
            }
        }

        guard let title = parsed["title"] as? String,
              let scheduledStr = parsed["scheduled_at"] as? String,
              let date = dateFormatter.date(from: scheduledStr)
        else {
            throw AIServiceError.parseFailed
        }

        var recurrenceRule: RecurrenceRule?
        if let recurrence = parsed["recurrence"] as? [String: Any],
           let type = recurrence["type"] as? String {
            switch type {
            case "daily":
                let hour = recurrence["hour"] as? Int ?? Calendar.autoupdatingCurrent.component(.hour, from: date)
                let minute = recurrence["minute"] as? Int ?? Calendar.autoupdatingCurrent.component(.minute, from: date)
                recurrenceRule = .daily(hour: hour, minute: minute)
            case "weekly":
                let weekday = recurrence["weekday"] as? Int ?? 2
                let hour = recurrence["hour"] as? Int ?? Calendar.autoupdatingCurrent.component(.hour, from: date)
                let minute = recurrence["minute"] as? Int ?? Calendar.autoupdatingCurrent.component(.minute, from: date)
                recurrenceRule = .weekly(weekday: weekday, hour: hour, minute: minute)
            default:
                break
            }
        }

        return AIParseResult(title: title, scheduledAt: date, recurrenceRule: recurrenceRule)
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
    case systemDefaultModelUnavailable(String)
    case requestFailed(statusCode: Int?, message: String?)
    case invalidResponse
    case parseFailed
    case noTitle
    case noTime
    case unrecognized

    var isConfigurationError: Bool {
        switch self {
        case .missingConfiguration, .invalidConfiguration:
            return true
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .missingConfiguration(let key):
            return "AI 配置缺失：\(key)，请在设置页、`.env.local` 或环境变量里补上"
        case .invalidConfiguration(let key):
            return "AI 配置无效：\(key)，检查一下格式别写飞了"
        case .systemDefaultModelUnavailable(let reason):
            return "系统免费模型（DeepSeek）不可用：\(reason)。请检查默认 DeepSeek 配置，或者关闭该开关后改用自定义 OpenAI 兼容配置。"
        case .requestFailed(let statusCode, let message):
            if let statusCode, let message, !message.isEmpty {
                return "AI 请求失败（HTTP \(statusCode)）：\(message)"
            }

            if let statusCode {
                return "AI 请求失败（HTTP \(statusCode)），检查接口地址、模型和密钥"
            }

            if let message, !message.isEmpty {
                return "AI 请求失败：\(message)"
            }

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
