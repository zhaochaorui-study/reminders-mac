import SwiftUI

private enum SettingsComponentLayout {
    static let cardRowSpacing: CGFloat = 12
    static let textSpacing: CGFloat = 4
    static let iconSize: CGFloat = 36
    static let iconCornerRadius: CGFloat = 12
    static let iconFontSize: CGFloat = 15
    static let titleFontSize: CGFloat = 13
    static let bodyFontSize: CGFloat = 11
    static let noteFontSize: CGFloat = 10
    static let fieldLabelFontSize: CGFloat = 10
    static let fieldFontSize: CGFloat = 11
    static let fieldHeight: CGFloat = 38
    static let fieldHorizontalPadding: CGFloat = 11
    static let fieldCornerRadius: CGFloat = 12
    static let buttonHeight: CGFloat = 36
    static let buttonCornerRadius: CGFloat = 12
    static let testButtonWidth: CGFloat = 86
    static let clearButtonWidth: CGFloat = 48
    static let saveButtonWidth: CGFloat = 54
    static let contentHorizontalPadding: CGFloat = 14
    static let contentVerticalPadding: CGFloat = 12
    static let nestedCardCornerRadius: CGFloat = 16
    static let insetCornerRadius: CGFloat = 14
    static let badgeFontSize: CGFloat = 10
    static let badgeHorizontalPadding: CGFloat = 8
    static let badgeVerticalPadding: CGFloat = 5
    static let badgeDotSize: CGFloat = 6
    static let compactSpacing: CGFloat = 8
}

private struct SettingsInlineFeedback: Equatable {
    enum Tone {
        case success
        case failure
    }

    let tone: Tone
    let message: String

    var iconName: String {
        switch tone {
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "exclamationmark.triangle.fill"
        }
    }

    @MainActor
    var accent: Color {
        switch tone {
        case .success:
            return RemindersPalette.accentGreen
        case .failure:
            return RemindersPalette.accentRed
        }
    }
}

struct ReminderSettingsView: View {
    private enum Layout {
        static let windowSize = CGSize(width: 504, height: 612)
        static let outerPadding: CGFloat = 18
        static let stackSpacing: CGFloat = 16
        static let cardSpacing: CGFloat = 10
        static let sectionSpacing: CGFloat = 14
        static let cardCornerRadius: CGFloat = 20
        static let contentBottomPadding: CGFloat = 8
    }

    @ObservedObject private var preferences = ReminderPreferences.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var draftLLMAPIBaseURL = ""
    @State private var draftLLMAPIKey = ""
    @State private var draftWeComWebhookURL = ""
    @State private var draftFeishuWebhookURL = ""
    @State private var isTestingLLMConnection = false
    @State private var aiTestFeedback: SettingsInlineFeedback?
    @State private var aiTestRequestToken = UUID()

    static let preferredWindowSize = Layout.windowSize

    private var isCandy: Bool {
        themeManager.isCandyTheme
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Layout.stackSpacing) {
                    headerSection
                    channelSection
                    aiSection
                    webhookSection
                    footerNote
                }
                .padding(Layout.outerPadding)
                .padding(.bottom, Layout.contentBottomPadding)
                .frame(width: Self.preferredWindowSize.width, alignment: .topLeading)
            }
            .frame(width: Self.preferredWindowSize.width, height: Self.preferredWindowSize.height, alignment: .topLeading)
        }
        .onAppear(perform: syncSavedDrafts)
        .onChange(of: draftLLMAPIBaseURL) {
            invalidateAITestState()
        }
        .onChange(of: draftLLMAPIKey) {
            invalidateAITestState()
        }
        .onChange(of: preferences.prefersSystemDefaultAIModel) {
            invalidateAITestState()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("提醒设置")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(RemindersPalette.primaryText)

            Text("把提醒通道、AI 配置和外部转发分开管，别等到点了才想起来开关没开、接口没配。")
                .font(.system(size: 12, weight: .medium, design: isCandy ? .rounded : .default))
                .foregroundStyle(RemindersPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            statusBadges
        }
    }

    private var statusBadges: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                systemNotificationBadge
                inAppAlertBadge
                aiCredentialBadge
                webhookBadge
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    systemNotificationBadge
                    inAppAlertBadge
                }

                HStack(spacing: 6) {
                    aiCredentialBadge
                    webhookBadge
                }
            }
        }
    }

    private var systemNotificationBadge: some View {
        SettingsStatusBadgeView(
            title: "系统弹窗",
            isEnabled: preferences.systemNotificationsEnabled,
            accent: RemindersPalette.accentBlue
        )
    }

    private var inAppAlertBadge: some View {
        SettingsStatusBadgeView(
            title: "内置弹窗",
            isEnabled: preferences.inAppAlertsEnabled,
            accent: RemindersPalette.accentOrange
        )
    }

    private var aiCredentialBadge: some View {
        SettingsStatusBadgeView(
            title: "AI 配置",
            isEnabled: preferences.hasConfiguredAICredentials,
            accent: RemindersPalette.accentOrange
        )
    }

    private var webhookBadge: some View {
        SettingsStatusBadgeView(
            title: "Webhook",
            isEnabled: preferences.hasConfiguredWebhook,
            accent: RemindersPalette.accentGreen
        )
    }

    private var channelSection: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            VStack(alignment: .leading, spacing: 6) {
                Text("提醒通道")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RemindersPalette.primaryText)

                Text("系统通知适合挂在后台时兜底，内置弹窗适合你正盯着桌面时直接处理。")
                    .font(.system(size: 11))
                    .foregroundStyle(RemindersPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: Layout.cardSpacing) {
                SettingsToggleCardView(
                    iconName: "macwindow.badge.plus",
                    iconAccent: RemindersPalette.accentBlue,
                    title: "启用系统弹窗提示",
                    description: "到点后通过 macOS 通知横幅提醒。首次打开时会请求系统通知权限。",
                    isOn: $preferences.systemNotificationsEnabled
                )

                SettingsToggleCardView(
                    iconName: "rectangle.stack.badge.play",
                    iconAccent: RemindersPalette.accentOrange,
                    title: "启用内置弹窗",
                    description: "在桌面右上角展示应用自己的提醒面板，支持稍后提醒和直接完成。",
                    isOn: $preferences.inAppAlertsEnabled
                )
            }

            if preferences.hasEnabledAlertChannel == false {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RemindersPalette.accentRed)
                        .padding(.top, 2)

                    Text("两个开关都关掉之后，到点不会出现任何弹窗提醒，只能自己记着。这个设置可不是闹着玩的。")
                        .font(.system(size: 11, weight: .medium, design: isCandy ? .rounded : .default))
                        .foregroundStyle(RemindersPalette.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RemindersPalette.validationBg, in: RoundedRectangle(cornerRadius: SettingsComponentLayout.insetCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: SettingsComponentLayout.insetCornerRadius, style: .continuous)
                        .stroke(RemindersPalette.accentRed.opacity(0.28), lineWidth: 0.8)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                .fill(RemindersPalette.panel)
                .overlay {
                    RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                        .stroke(RemindersPalette.border.opacity(0.62), lineWidth: 0.8)
                }
        )
        .shadow(color: RemindersPalette.shadow.opacity(isCandy ? 0.16 : 0.24), radius: 14, x: 0, y: 8)
    }

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            VStack(alignment: .leading, spacing: 6) {
                Text("AI 解析")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RemindersPalette.primaryText)

                Text("可以直接切到系统免费默认模型，也可以保留下面的自定义接口做备用。自定义没填时，仍会回退本地 `.env.local`。")
                    .font(.system(size: 11))
                    .foregroundStyle(RemindersPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SettingsToggleCardView(
                iconName: "cpu.fill",
                iconAccent: RemindersPalette.accentGreen,
                title: "使用系统免费默认模型",
                description: "开启后，主面板 AI 解析会优先使用 macOS 系统自带模型，不需要填写自定义 Base URL 和 API Key。系统模型不可用时，会自动回退到下面的自定义配置或 `.env.local`。",
                isOn: $preferences.prefersSystemDefaultAIModel
            )

            if let systemDefaultModelFeedback {
                SettingsFeedbackBannerView(feedback: systemDefaultModelFeedback)
            }

            SettingsAICredentialsCardView(
                iconName: "sparkles.rectangle.stack.fill",
                iconAccent: RemindersPalette.accentOrange,
                title: aiConfigurationCardTitle,
                description: aiConfigurationCardDescription,
                baseURL: $draftLLMAPIBaseURL,
                apiKey: $draftLLMAPIKey,
                savedBaseURL: preferences.llmAPIBaseURL,
                savedAPIKey: preferences.llmAPIKey,
                isTestingConnection: isTestingLLMConnection,
                testFeedback: aiTestFeedback,
                onTest: testLLMConfiguration,
                onSave: saveLLMConfiguration
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                .fill(RemindersPalette.panel)
                .overlay {
                    RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                        .stroke(RemindersPalette.border.opacity(0.62), lineWidth: 0.8)
                }
        )
        .shadow(color: RemindersPalette.shadow.opacity(isCandy ? 0.16 : 0.24), radius: 14, x: 0, y: 8)
    }

    private var webhookSection: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Webhook 转发")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RemindersPalette.primaryText)

                Text("提醒到点后会按你保存的地址自动推送。没保存就不发，地址改了也得记得重新点保存。")
                    .font(.system(size: 11))
                    .foregroundStyle(RemindersPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: Layout.cardSpacing) {
                SettingsWebhookFieldCardView(
                    iconName: "building.2.crop.circle",
                    iconAccent: RemindersPalette.accentGreen,
                    title: "企微 Webhook",
                    description: "企业微信机器人地址，通常形如 https://qyapi.weixin.qq.com/cgi-bin/webhook/send?...",
                    placeholder: "粘贴企业微信机器人 Webhook",
                    text: $draftWeComWebhookURL,
                    savedText: preferences.weComWebhookURL,
                    onSave: saveWeComWebhook
                )

                SettingsWebhookFieldCardView(
                    iconName: "paperplane.circle",
                    iconAccent: RemindersPalette.accentBlue,
                    title: "飞书 Webhook",
                    description: "飞书群机器人地址，通常形如 https://open.feishu.cn/open-apis/bot/v2/hook/...",
                    placeholder: "粘贴飞书机器人 Webhook",
                    text: $draftFeishuWebhookURL,
                    savedText: preferences.feishuWebhookURL,
                    onSave: saveFeishuWebhook
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                .fill(RemindersPalette.panel)
                .overlay {
                    RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                        .stroke(RemindersPalette.border.opacity(0.62), lineWidth: 0.8)
                }
        )
        .shadow(color: RemindersPalette.shadow.opacity(isCandy ? 0.16 : 0.24), radius: 14, x: 0, y: 8)
    }

    private var footerNote: some View {
        Text("提示：系统免费默认模型开关会立即生效；自定义 AI 配置和 Webhook 仍然需要点“保存”才会真正写入本地。AI 解析会先看系统模型开关，其次才用这里保存的 Base URL 和 API Key。")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(RemindersPalette.tertiaryText)
            .padding(.horizontal, 2)
    }

    private var aiConfigurationCardTitle: String {
        preferences.prefersSystemDefaultAIModel ? "备用自定义 AI 配置" : "主面板 AI 配置"
    }

    private var aiConfigurationCardDescription: String {
        if preferences.prefersSystemDefaultAIModel {
            return "上面的系统免费默认模型开着时，主面板会优先走系统模型；下面这套 Base URL 和 API Key 会作为备用配置保留，系统模型不可用或你关闭开关后再接管。"
        }

        return "用于自然语言解析待办。Base URL 支持填 OpenAI 兼容地址，程序会自动补到 `/chat/completions`；API Key 留空就没法调。"
    }

    private var systemDefaultModelFeedback: SettingsInlineFeedback? {
        guard preferences.prefersSystemDefaultAIModel else { return nil }

        switch AIService.shared.systemDefaultModelStatus() {
        case .available:
            return SettingsInlineFeedback(
                tone: .success,
                message: "系统免费默认模型已启用，主面板 AI 解析会优先走本机模型，不需要自定义接口。"
            )
        case .unavailable(let reason):
            return SettingsInlineFeedback(
                tone: .failure,
                message: "系统免费默认模型当前不可用：\(reason)。主面板会回退到下面的自定义配置；如果你也没配，那就别指望它能凭空解析。"
            )
        }
    }

    private var backgroundColors: [Color] {
        if isCandy {
            return [Color(hex: 0xEEE6D7), Color(hex: 0xF7F1E7)]
        }
        return [Color(hex: 0x181312), Color(hex: 0x241A17)]
    }

    private func syncSavedDrafts() {
        invalidateAITestState()
        draftLLMAPIBaseURL = preferences.llmAPIBaseURL
        draftLLMAPIKey = preferences.llmAPIKey
        draftWeComWebhookURL = preferences.weComWebhookURL
        draftFeishuWebhookURL = preferences.feishuWebhookURL
    }

    private func saveLLMConfiguration() {
        invalidateAITestState()
        preferences.saveLLMConfiguration(baseURL: draftLLMAPIBaseURL, apiKey: draftLLMAPIKey)
        draftLLMAPIBaseURL = preferences.llmAPIBaseURL
        draftLLMAPIKey = preferences.llmAPIKey
    }

    private func saveWeComWebhook() {
        preferences.saveWeComWebhookURL(draftWeComWebhookURL)
        draftWeComWebhookURL = preferences.weComWebhookURL
    }

    private func saveFeishuWebhook() {
        preferences.saveFeishuWebhookURL(draftFeishuWebhookURL)
        draftFeishuWebhookURL = preferences.feishuWebhookURL
    }

    private func invalidateAITestState() {
        aiTestRequestToken = UUID()
        isTestingLLMConnection = false
        aiTestFeedback = nil
    }

    private func testLLMConfiguration() {
        let requestToken = UUID()
        aiTestRequestToken = requestToken
        isTestingLLMConnection = true
        aiTestFeedback = nil

        let currentBaseURL = draftLLMAPIBaseURL
        let currentAPIKey = draftLLMAPIKey

        Task {
            do {
                let model = try await AIService.shared.testConnection(
                    apiBaseURL: currentBaseURL,
                    apiKey: currentAPIKey
                )

                await MainActor.run {
                    guard aiTestRequestToken == requestToken else { return }
                    isTestingLLMConnection = false
                    aiTestFeedback = SettingsInlineFeedback(
                        tone: .success,
                        message: "连通了，当前模型 \(model) 能正常响应。"
                    )
                }
            } catch {
                await MainActor.run {
                    guard aiTestRequestToken == requestToken else { return }
                    isTestingLLMConnection = false
                    aiTestFeedback = SettingsInlineFeedback(
                        tone: .failure,
                        message: error.localizedDescription
                    )
                }
            }
        }
    }
}

private struct SettingsTextInputFieldView: View {
    let label: String
    let placeholder: String
    let accent: Color
    @Binding var text: String
    var isSecure: Bool = false

    @ObservedObject private var themeManager = ThemeManager.shared

    private var isCandy: Bool {
        themeManager.isCandyTheme
    }

    private var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SettingsComponentLayout.fieldCornerRadius, style: .continuous)
    }

    private var placeholderColor: Color {
        if isCandy {
            return RemindersPalette.secondaryText.opacity(0.50)
        }

        return RemindersPalette.tertiaryText.opacity(0.88)
    }

    private var fieldBackground: LinearGradient {
        if isCandy {
            return LinearGradient(
                colors: [
                    Color(hex: 0xF4ECDF),
                    RemindersPalette.card,
                    accent.opacity(0.10),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                RemindersPalette.field,
                RemindersPalette.elevated.opacity(0.96),
                accent.opacity(0.18),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var fieldBorderColor: Color {
        if isCandy {
            return accent.opacity(0.18)
        }

        return accent.opacity(0.26)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: SettingsComponentLayout.fieldLabelFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(RemindersPalette.tertiaryText)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: SettingsComponentLayout.fieldFontSize, weight: .medium, design: isCandy ? .rounded : .default))
                        .foregroundStyle(placeholderColor)
                        .padding(.horizontal, SettingsComponentLayout.fieldHorizontalPadding)
                        .allowsHitTesting(false)
                }

                inputField
                    .textFieldStyle(.plain)
                    .font(.system(size: SettingsComponentLayout.fieldFontSize, weight: .medium))
                    .foregroundStyle(RemindersPalette.primaryText)
                    .padding(.horizontal, SettingsComponentLayout.fieldHorizontalPadding)
                    .frame(height: SettingsComponentLayout.fieldHeight)
            }
            .background(fieldBackground, in: fieldShape)
            .overlay {
                fieldShape
                    .stroke(fieldBorderColor, lineWidth: 0.9)
            }
            .shadow(
                color: accent.opacity(isCandy ? 0.08 : 0.12),
                radius: isCandy ? 10 : 6,
                x: 0,
                y: 3
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var inputField: some View {
        if isSecure {
            SecureField("", text: $text)
        } else {
            TextField("", text: $text)
        }
    }
}

private struct SettingsActionButtonView: View {
    let title: String
    let width: CGFloat
    let accent: Color
    let isProminent: Bool
    let isEnabled: Bool
    let action: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared

    private var isCandy: Bool {
        themeManager.isCandyTheme
    }

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: isProminent ? .bold : .semibold, design: .rounded))
            .foregroundStyle(isProminent ? Color.white : RemindersPalette.secondaryText)
            .frame(width: width, height: SettingsComponentLayout.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: SettingsComponentLayout.buttonCornerRadius, style: .continuous)
                    .fill(
                        isProminent
                            ? accent
                            : (isCandy ? RemindersPalette.card : RemindersPalette.field)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: SettingsComponentLayout.buttonCornerRadius, style: .continuous)
                            .stroke(
                                isProminent ? accent.opacity(0.2) : RemindersPalette.border.opacity(0.48),
                                lineWidth: 0.8
                            )
                    }
            )
            .disabled(!isEnabled)
    }
}

private struct SettingsToggleCardView: View {
    let iconName: String
    let iconAccent: Color
    let title: String
    let description: String
    @Binding var isOn: Bool

    @ObservedObject private var themeManager = ThemeManager.shared

    private var isCandy: Bool {
        themeManager.isCandyTheme
    }

    var body: some View {
        HStack(alignment: .center, spacing: SettingsComponentLayout.cardRowSpacing) {
            ZStack {
                RoundedRectangle(cornerRadius: SettingsComponentLayout.iconCornerRadius, style: .continuous)
                    .fill(iconAccent.opacity(isCandy ? 0.16 : 0.2))

                Image(systemName: iconName)
                    .font(.system(size: SettingsComponentLayout.iconFontSize, weight: .semibold))
                    .foregroundStyle(iconAccent)
            }
            .frame(width: SettingsComponentLayout.iconSize, height: SettingsComponentLayout.iconSize)

            VStack(alignment: .leading, spacing: SettingsComponentLayout.textSpacing) {
                Text(title)
                    .font(.system(size: SettingsComponentLayout.titleFontSize, weight: .semibold))
                    .foregroundStyle(RemindersPalette.primaryText)

                Text(description)
                    .font(.system(size: SettingsComponentLayout.bodyFontSize))
                    .foregroundStyle(RemindersPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(iconAccent)
        }
        .padding(.horizontal, SettingsComponentLayout.contentHorizontalPadding)
        .padding(.vertical, SettingsComponentLayout.contentVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: SettingsComponentLayout.nestedCardCornerRadius, style: .continuous)
                .fill(isCandy ? RemindersPalette.card : RemindersPalette.field)
                .overlay {
                    RoundedRectangle(cornerRadius: SettingsComponentLayout.nestedCardCornerRadius, style: .continuous)
                        .stroke(RemindersPalette.border.opacity(0.48), lineWidth: 0.8)
                }
        )
    }
}

private struct SettingsAICredentialsCardView: View {
    let iconName: String
    let iconAccent: Color
    let title: String
    let description: String
    @Binding var baseURL: String
    @Binding var apiKey: String
    let savedBaseURL: String
    let savedAPIKey: String
    let isTestingConnection: Bool
    let testFeedback: SettingsInlineFeedback?
    let onTest: () -> Void
    let onSave: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared

    private var isCandy: Bool {
        themeManager.isCandyTheme
    }

    private var trimmedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedSavedBaseURL: String {
        savedBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedSavedAPIKey: String {
        savedAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEnabled: Bool {
        !trimmedSavedBaseURL.isEmpty || !trimmedSavedAPIKey.isEmpty
    }

    private var hasUnsavedChanges: Bool {
        trimmedBaseURL != trimmedSavedBaseURL || trimmedAPIKey != trimmedSavedAPIKey
    }

    private var canTestConnection: Bool {
        !trimmedAPIKey.isEmpty && !isTestingConnection
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: SettingsComponentLayout.cardRowSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: SettingsComponentLayout.iconCornerRadius, style: .continuous)
                        .fill(iconAccent.opacity(isCandy ? 0.16 : 0.2))

                    Image(systemName: iconName)
                        .font(.system(size: SettingsComponentLayout.iconFontSize, weight: .semibold))
                        .foregroundStyle(iconAccent)
                }
                .frame(width: SettingsComponentLayout.iconSize, height: SettingsComponentLayout.iconSize)

                VStack(alignment: .leading, spacing: SettingsComponentLayout.textSpacing) {
                    Text(title)
                        .font(.system(size: SettingsComponentLayout.titleFontSize, weight: .semibold))
                        .foregroundStyle(RemindersPalette.primaryText)

                    Text(description)
                        .font(.system(size: SettingsComponentLayout.bodyFontSize))
                        .foregroundStyle(RemindersPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                SettingsMiniStateBadgeView(
                    title: isEnabled ? "已配置" : "未配置",
                    accent: isEnabled ? iconAccent : RemindersPalette.tertiaryText
                )
            }

            VStack(spacing: SettingsComponentLayout.compactSpacing) {
                SettingsTextInputFieldView(
                    label: "Base URL",
                    placeholder: "例如 https://api.deepseek.com/v1",
                    accent: iconAccent,
                    text: $baseURL
                )

                SettingsTextInputFieldView(
                    label: "API Key",
                    placeholder: "填写主面板 AI 解析要用的 API Key",
                    accent: iconAccent,
                    text: $apiKey,
                    isSecure: true
                )
            }

            HStack(spacing: SettingsComponentLayout.compactSpacing) {
                Spacer(minLength: 0)

                SettingsActionButtonView(
                    title: isTestingConnection ? "测试中" : "测试大模型",
                    width: SettingsComponentLayout.testButtonWidth,
                    accent: iconAccent,
                    isProminent: false,
                    isEnabled: canTestConnection,
                    action: onTest
                )

                SettingsActionButtonView(
                    title: "清空",
                    width: SettingsComponentLayout.clearButtonWidth,
                    accent: iconAccent,
                    isProminent: false,
                    isEnabled: !baseURL.isEmpty || !apiKey.isEmpty
                ) {
                    baseURL = ""
                    apiKey = ""
                }

                SettingsActionButtonView(
                    title: "保存",
                    width: SettingsComponentLayout.saveButtonWidth,
                    accent: iconAccent,
                    isProminent: hasUnsavedChanges,
                    isEnabled: hasUnsavedChanges,
                    action: onSave
                )
            }

            if let testFeedback {
                SettingsFeedbackBannerView(feedback: testFeedback)
            }

            HStack(alignment: .top, spacing: SettingsComponentLayout.compactSpacing) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(iconAccent)
                    .padding(.top, 2)

                Text("Base URL 和 API Key 会写入当前项目的 `.env.local`，仅保存在你本机工作目录里，不会被本应用额外上传或共享。只有你主动点主面板里的 AI 解析时，当前输入内容才会发到你配置的大模型接口。")
                    .font(.system(size: SettingsComponentLayout.noteFontSize, weight: .medium))
                    .foregroundStyle(RemindersPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                iconAccent.opacity(isCandy ? 0.12 : 0.16),
                in: RoundedRectangle(cornerRadius: SettingsComponentLayout.insetCornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: SettingsComponentLayout.insetCornerRadius, style: .continuous)
                    .stroke(iconAccent.opacity(0.22), lineWidth: 0.8)
            }
        }
        .padding(.horizontal, SettingsComponentLayout.contentHorizontalPadding)
        .padding(.vertical, SettingsComponentLayout.contentVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: SettingsComponentLayout.nestedCardCornerRadius, style: .continuous)
                .fill(isCandy ? RemindersPalette.card : RemindersPalette.field)
                .overlay {
                    RoundedRectangle(cornerRadius: SettingsComponentLayout.nestedCardCornerRadius, style: .continuous)
                        .stroke(RemindersPalette.border.opacity(0.48), lineWidth: 0.8)
                }
        )
    }
}

private struct SettingsFeedbackBannerView: View {
    let feedback: SettingsInlineFeedback

    @ObservedObject private var themeManager = ThemeManager.shared

    private var isCandy: Bool {
        themeManager.isCandyTheme
    }

    var body: some View {
        HStack(alignment: .top, spacing: SettingsComponentLayout.compactSpacing) {
            Image(systemName: feedback.iconName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(feedback.accent)
                .padding(.top, 2)

            Text(feedback.message)
                .font(.system(size: SettingsComponentLayout.noteFontSize, weight: .medium))
                .foregroundStyle(RemindersPalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            feedback.accent.opacity(isCandy ? 0.12 : 0.16),
            in: RoundedRectangle(cornerRadius: SettingsComponentLayout.insetCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: SettingsComponentLayout.insetCornerRadius, style: .continuous)
                .stroke(feedback.accent.opacity(0.22), lineWidth: 0.8)
        }
    }
}

private struct SettingsWebhookFieldCardView: View {
    let iconName: String
    let iconAccent: Color
    let title: String
    let description: String
    let placeholder: String
    @Binding var text: String
    let savedText: String
    let onSave: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared

    private var isCandy: Bool {
        themeManager.isCandyTheme
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedSavedText: String {
        savedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEnabled: Bool {
        !trimmedSavedText.isEmpty
    }

    private var hasUnsavedChanges: Bool {
        trimmedText != trimmedSavedText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: SettingsComponentLayout.cardRowSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: SettingsComponentLayout.iconCornerRadius, style: .continuous)
                        .fill(iconAccent.opacity(isCandy ? 0.16 : 0.2))

                    Image(systemName: iconName)
                        .font(.system(size: SettingsComponentLayout.iconFontSize, weight: .semibold))
                        .foregroundStyle(iconAccent)
                }
                .frame(width: SettingsComponentLayout.iconSize, height: SettingsComponentLayout.iconSize)

                VStack(alignment: .leading, spacing: SettingsComponentLayout.textSpacing) {
                    Text(title)
                        .font(.system(size: SettingsComponentLayout.titleFontSize, weight: .semibold))
                        .foregroundStyle(RemindersPalette.primaryText)

                    Text(description)
                        .font(.system(size: SettingsComponentLayout.bodyFontSize))
                        .foregroundStyle(RemindersPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                SettingsMiniStateBadgeView(
                    title: isEnabled ? "已启用" : "未启用",
                    accent: isEnabled ? iconAccent : RemindersPalette.tertiaryText
                )
            }

            HStack(alignment: .bottom, spacing: SettingsComponentLayout.compactSpacing) {
                SettingsTextInputFieldView(
                    label: "Webhook 地址",
                    placeholder: placeholder,
                    accent: iconAccent,
                    text: $text
                )

                SettingsActionButtonView(
                    title: "清空",
                    width: SettingsComponentLayout.clearButtonWidth,
                    accent: iconAccent,
                    isProminent: false,
                    isEnabled: !text.isEmpty
                ) {
                    text = ""
                }

                SettingsActionButtonView(
                    title: "保存",
                    width: SettingsComponentLayout.saveButtonWidth,
                    accent: iconAccent,
                    isProminent: hasUnsavedChanges,
                    isEnabled: hasUnsavedChanges,
                    action: onSave
                )
            }

            Text("保存非空地址即启用；清空内容后再点保存，就会停用这一条。")
                .font(.system(size: SettingsComponentLayout.noteFontSize, weight: .medium))
                .foregroundStyle(RemindersPalette.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, SettingsComponentLayout.contentHorizontalPadding)
        .padding(.vertical, SettingsComponentLayout.contentVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: SettingsComponentLayout.nestedCardCornerRadius, style: .continuous)
                .fill(isCandy ? RemindersPalette.card : RemindersPalette.field)
                .overlay {
                    RoundedRectangle(cornerRadius: SettingsComponentLayout.nestedCardCornerRadius, style: .continuous)
                        .stroke(RemindersPalette.border.opacity(0.48), lineWidth: 0.8)
                }
        )
    }
}

private struct SettingsMiniStateBadgeView: View {
    let title: String
    let accent: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(accent)
                .frame(width: SettingsComponentLayout.badgeDotSize, height: SettingsComponentLayout.badgeDotSize)

            Text(title)
                .font(.system(size: SettingsComponentLayout.badgeFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(RemindersPalette.primaryText)
        }
        .padding(.horizontal, SettingsComponentLayout.badgeHorizontalPadding)
        .padding(.vertical, SettingsComponentLayout.badgeVerticalPadding)
        .background(
            Capsule(style: .continuous)
                .fill(RemindersPalette.panel.opacity(0.92))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(RemindersPalette.border.opacity(0.5), lineWidth: 0.8)
                }
        )
    }
}

private struct SettingsStatusBadgeView: View {
    let title: String
    let isEnabled: Bool
    let accent: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isEnabled ? accent : RemindersPalette.border)
                .frame(width: SettingsComponentLayout.badgeDotSize, height: SettingsComponentLayout.badgeDotSize)

            Text("\(title)·\(isEnabled ? "开" : "关")")
                .font(.system(size: SettingsComponentLayout.badgeFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(RemindersPalette.primaryText)
        }
        .padding(.horizontal, SettingsComponentLayout.badgeHorizontalPadding)
        .padding(.vertical, SettingsComponentLayout.badgeVerticalPadding)
        .background(
            Capsule(style: .continuous)
                .fill(RemindersPalette.panel.opacity(0.9))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(RemindersPalette.border.opacity(0.55), lineWidth: 0.8)
                }
        )
    }
}
