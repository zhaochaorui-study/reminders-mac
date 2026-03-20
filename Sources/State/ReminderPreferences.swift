import Combine
import Foundation

enum ReminderPreferenceStorage {
    static let systemNotificationsEnabledKey = "systemNotificationsEnabled"
    static let inAppAlertsEnabledKey = "inAppAlertsEnabled"
    static let prefersSystemDefaultAIModelKey = "prefersSystemDefaultAIModel"
    static let weComWebhookURLKey = "weComWebhookURL"
    static let feishuWebhookURLKey = "feishuWebhookURL"
    static let menuBarShowLatestTodoKey = "menuBarShowLatestTodo"

    static func systemNotificationsEnabled(userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.object(forKey: systemNotificationsEnabledKey) as? Bool ?? false
    }

    static func inAppAlertsEnabled(userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.object(forKey: inAppAlertsEnabledKey) as? Bool ?? true
    }

    static func prefersSystemDefaultAIModel(userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.object(forKey: prefersSystemDefaultAIModelKey) as? Bool ?? false
    }

    static func weComWebhookURL(userDefaults: UserDefaults = .standard) -> String {
        userDefaults.string(forKey: weComWebhookURLKey) ?? ""
    }

    static func feishuWebhookURL(userDefaults: UserDefaults = .standard) -> String {
        userDefaults.string(forKey: feishuWebhookURLKey) ?? ""
    }

    static func menuBarShowLatestTodo(userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.object(forKey: menuBarShowLatestTodoKey) as? Bool ?? true
    }

    static func llmAPIBaseURL() -> String {
        AIServiceConfigurationLoader.persistedCustomConfiguration().apiBaseURL
    }

    static func llmAPIKey() -> String {
        AIServiceConfigurationLoader.persistedCustomConfiguration().apiKey
    }

    static func llmModel() -> String {
        AIServiceConfigurationLoader.persistedCustomConfiguration().model
    }

    static func llmAPISecret() -> String {
        LocalSecretsStore.value(for: .llmAPISecret)
    }
}

@MainActor
final class ReminderPreferences: ObservableObject {
    static let shared = ReminderPreferences()

    @Published var systemNotificationsEnabled: Bool {
        didSet { userDefaults.set(systemNotificationsEnabled, forKey: ReminderPreferenceStorage.systemNotificationsEnabledKey) }
    }

    @Published var inAppAlertsEnabled: Bool {
        didSet { userDefaults.set(inAppAlertsEnabled, forKey: ReminderPreferenceStorage.inAppAlertsEnabledKey) }
    }

    @Published var prefersSystemDefaultAIModel: Bool {
        didSet { userDefaults.set(prefersSystemDefaultAIModel, forKey: ReminderPreferenceStorage.prefersSystemDefaultAIModelKey) }
    }

    @Published var weComWebhookURL: String {
        didSet { userDefaults.set(weComWebhookURL, forKey: ReminderPreferenceStorage.weComWebhookURLKey) }
    }

    @Published var feishuWebhookURL: String {
        didSet { userDefaults.set(feishuWebhookURL, forKey: ReminderPreferenceStorage.feishuWebhookURLKey) }
    }

    @Published var menuBarShowLatestTodo: Bool {
        didSet { userDefaults.set(menuBarShowLatestTodo, forKey: ReminderPreferenceStorage.menuBarShowLatestTodoKey) }
    }

    @Published var llmAPIBaseURL: String

    @Published var llmAPIKey: String

    @Published var llmModel: String

    var hasEnabledAlertChannel: Bool {
        systemNotificationsEnabled || inAppAlertsEnabled
    }

    var hasConfiguredWebhook: Bool {
        !weComWebhookURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !feishuWebhookURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasConfiguredAICredentials: Bool {
        if prefersSystemDefaultAIModel {
            return true
        }

        return !llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !llmModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let userDefaults: UserDefaults

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.systemNotificationsEnabled = ReminderPreferenceStorage.systemNotificationsEnabled(userDefaults: userDefaults)
        self.inAppAlertsEnabled = ReminderPreferenceStorage.inAppAlertsEnabled(userDefaults: userDefaults)
        self.prefersSystemDefaultAIModel = ReminderPreferenceStorage.prefersSystemDefaultAIModel(userDefaults: userDefaults)
        self.weComWebhookURL = ReminderPreferenceStorage.weComWebhookURL(userDefaults: userDefaults)
        self.feishuWebhookURL = ReminderPreferenceStorage.feishuWebhookURL(userDefaults: userDefaults)
        self.menuBarShowLatestTodo = ReminderPreferenceStorage.menuBarShowLatestTodo(userDefaults: userDefaults)
        self.llmAPIBaseURL = ReminderPreferenceStorage.llmAPIBaseURL()
        self.llmAPIKey = ReminderPreferenceStorage.llmAPIKey()
        self.llmModel = ReminderPreferenceStorage.llmModel()
    }

    func saveWeComWebhookURL(_ value: String) {
        weComWebhookURL = Self.normalizedWebhookURL(value)
    }

    func saveFeishuWebhookURL(_ value: String) {
        feishuWebhookURL = Self.normalizedWebhookURL(value)
    }

    func saveLLMConfiguration(baseURL: String, apiKey: String, model: String) {
        AIServiceConfigurationLoader.saveCustomConfiguration(
            apiBaseURL: Self.normalizedCredentialValue(baseURL),
            apiKey: Self.normalizedCredentialValue(apiKey),
            model: Self.normalizedCredentialValue(model)
        )
        llmAPIBaseURL = ReminderPreferenceStorage.llmAPIBaseURL()
        llmAPIKey = ReminderPreferenceStorage.llmAPIKey()
        llmModel = ReminderPreferenceStorage.llmModel()
        LocalSecretsStore.deleteValue(for: .llmAPIBaseURL)
        LocalSecretsStore.deleteValue(for: .llmAPIKey)
        LocalSecretsStore.deleteValue(for: .llmAPISecret)
    }

    private static func normalizedWebhookURL(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedCredentialValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
