import Foundation
import Security

enum LocalSecretsKey: String {
    case llmAPIBaseURL = "llm_api_base_url"
    case llmAPIKey = "llm_api_key"
    case llmAPISecret = "llm_api_secret"
}

enum LocalSecretsStore {
    private static let serviceName: String = {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.reminders.mac"
        return "\(bundleIdentifier).local-secrets"
    }()

    static func value(for key: LocalSecretsKey) -> String {
        guard let data = copyData(for: key),
              let value = String(data: data, encoding: .utf8)
        else {
            return ""
        }

        return value
    }

    static func set(_ value: String, for key: LocalSecretsKey) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            deleteValue(for: key)
            return
        }

        deleteValue(for: key)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: Data(normalized.utf8),
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            NSLog(
                "[Secrets] 保存 %@ 失败，service=%@，status=%d，message=%@",
                key.rawValue,
                serviceName,
                status,
                statusMessage(for: status)
            )
            return
        }
    }

    static func deleteValue(for key: LocalSecretsKey) {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            NSLog(
                "[Secrets] 删除 %@ 失败，service=%@，status=%d，message=%@",
                key.rawValue,
                serviceName,
                status,
                statusMessage(for: status)
            )
            return
        }
    }

    private static func copyData(for key: LocalSecretsKey) -> Data? {
        var query = baseQuery(for: key)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = kCFBooleanTrue

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            NSLog(
                "[Secrets] 读取 %@ 失败，service=%@，status=%d，message=%@",
                key.rawValue,
                serviceName,
                status,
                statusMessage(for: status)
            )
            return nil
        }
    }

    private static func statusMessage(for status: OSStatus) -> String {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return message
        }

        return "Unknown security error"
    }

    private static func baseQuery(for key: LocalSecretsKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
        ]
    }
}
