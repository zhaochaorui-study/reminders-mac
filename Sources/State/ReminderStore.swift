import Combine
import Foundation

extension Notification.Name {
    static let reminderDidAutoPresent = Notification.Name("reminderDidAutoPresent")
}

@MainActor
final class ReminderStore: ObservableObject {
    private enum Constants {
        static let advanceNoticeLeadTime: TimeInterval = 3 * 60
    }

    static let maxDraftTitleLength = 100

    @Published var draftTitle: String = "" {
        didSet {
            let limitedTitle = Self.truncatedDraftTitle(draftTitle)
            guard limitedTitle != draftTitle else { return }
            draftTitle = limitedTitle
        }
    }
    @Published var draftScheduledAt: Date
    @Published var draftRecurrenceRule: RecurrenceRule?
    @Published var editingTitle: String = "" {
        didSet {
            let limitedTitle = Self.truncatedDraftTitle(editingTitle)
            guard limitedTitle != editingTitle else { return }
            editingTitle = limitedTitle
        }
    }
    @Published var editingScheduledAt: Date
    @Published var editingRecurrenceRule: RecurrenceRule?
    @Published var listScope: ReminderListScope = .dueToday
    @Published private(set) var pendingItems: [ReminderItem] = []
    @Published private(set) var highlightedReminderID: ReminderItem.ID?
    @Published private(set) var isAIParsing: Bool = false
    @Published private(set) var draftValidationMessage: String?
    @Published private(set) var editingReminderID: ReminderItem.ID?
    @Published private(set) var editingValidationMessage: String?

    private var cancellables: Set<AnyCancellable> = []
    private var reminderTimer: DispatchSourceTimer?
    private var presentedReminderIDs: Set<ReminderItem.ID> = []
    private var presentedAdvanceReminderIDs: Set<ReminderItem.ID> = []
    private var webhookAttemptedReminderIDs: Set<ReminderItem.ID> = []
    private let windowManager = ReminderWindowManager()
    private let notificationManager = ReminderNotificationManager.shared
    private let webhookNotifier = ReminderWebhookNotifier.shared
    private let preferences = ReminderPreferences.shared
    private let db = DatabaseManager.shared
    private let ai = AIService.shared

    var completedCount: Int {
        pendingItems.filter(\.isCompleted).count
    }

    var pendingCount: Int {
        pendingItems.filter { !$0.isCompleted }.count
    }

    var completedHistoryItems: [ReminderItem] {
        let startOfToday = Calendar.autoupdatingCurrent.startOfDay(for: Date())
        let historyItems = pendingItems.filter { item in
            item.isCompleted && item.scheduledAt < startOfToday
        }

        return historyItems.sorted { lhs, rhs in
            if lhs.scheduledAt != rhs.scheduledAt {
                return lhs.scheduledAt > rhs.scheduledAt
            }

            return lhs.title.localizedCompare(rhs.title) == .orderedAscending
        }
    }

    var displayedItems: [ReminderItem] {
        let calendar = Calendar.autoupdatingCurrent
        let filteredItems = pendingItems.filter { item in
            switch listScope {
            case .createdToday:
                return calendar.isDateInToday(item.createdAt)
            case .dueToday:
                return calendar.isDateInToday(item.scheduledAt)
            }
        }

        return Self.sorted(items: filteredItems)
    }

    var highlightedReminder: ReminderItem? {
        guard let highlightedReminderID else { return nil }
        return pendingItems.first(where: { $0.id == highlightedReminderID })
    }

    var editingReminder: ReminderItem? {
        guard let editingReminderID else { return nil }
        return pendingItems.first(where: { $0.id == editingReminderID })
    }

    init() {
        let defaultDate = Self.defaultDraftDate()
        self.draftScheduledAt = defaultDate
        self.editingScheduledAt = defaultDate
        setupWindowManagerCallbacks()
        bindPreferences()
        notificationManager.requestAuthorizationIfNeeded()
        startReminderTicker()
        loadFromDatabase()
    }

    func setListScope(_ scope: ReminderListScope) {
        listScope = scope
    }

    func addReminder() {
        clearDraftValidationMessage()
        guard let reminder = makeDraftReminder() else { return }
        persistReminder(reminder)
        resetDraft()
    }

    func startEditing(_ item: ReminderItem) {
        guard !item.isCompleted else { return }
        editingReminderID = item.id
        editingTitle = item.title
        editingScheduledAt = item.scheduledAt
        editingRecurrenceRule = item.recurrenceRule
        clearEditingValidationMessage()

        if highlightedReminderID == item.id {
            highlightedReminderID = nil
        }
    }

    func cancelEditing() {
        resetEditingState()
    }

    func saveEditingReminder() {
        clearEditingValidationMessage()
        guard let currentItem = editingReminder,
              let updatedItem = makeEditedReminder(from: currentItem)
        else { return }

        applyUpdatedReminder(updatedItem, resettingPresentationFor: currentItem.id)
        resetEditingState()
    }

    func aiParseAndAdd() {
        let input = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        guard !isAIParsing else { return }

        clearDraftValidationMessage()
        isAIParsing = true
        Task {
            do {
                let result = try await ai.parse(input)
                await MainActor.run {
                    self.isAIParsing = false
                    self.applyAIParseResult(result)
                }
            } catch {
                await MainActor.run {
                    self.isAIParsing = false
                    self.presentDraftValidation(error.localizedDescription)
                    NSLog("[AI] 解析失败: %@", error.localizedDescription)
                }
            }
        }
    }

    func toggleCompletion(for item: ReminderItem) {
        guard let index = index(for: item.id) else { return }

        let currentItem = pendingItems[index]
        let isCompleting = !currentItem.isCompleted

        let updated = makeItem(
            from: currentItem,
            tone: isCompleting ? .completed : Self.tone(for: currentItem.scheduledAt),
            isCompleted: isCompleting,
            isHighlighted: false,
            showsMoreButton: !isCompleting
        )
        pendingItems[index] = updated

        if isCompleting {
            windowManager.dismissWindow(for: item.id)
            notificationManager.cancelNotification(for: item.id)
            scheduleNextRecurrence(for: currentItem)
        }

        presentedReminderIDs.remove(item.id)
        presentedAdvanceReminderIDs.remove(item.id)
        webhookAttemptedReminderIDs.remove(item.id)
        if highlightedReminderID == item.id {
            highlightedReminderID = nil
        }
        reconcileEditingReminder()

        pendingItems = Self.sorted(items: pendingItems)
        syncPendingNotifications()
        dbUpdate(updated)
        scheduleNextTick()
    }

    func markCompleted(_ item: ReminderItem) {
        guard let index = index(for: item.id) else { return }
        let currentItem = pendingItems[index]
        guard !currentItem.isCompleted else { return }

        let updated = makeItem(
            from: currentItem,
            tone: .completed,
            isCompleted: true,
            isHighlighted: false,
            showsMoreButton: false
        )
        pendingItems[index] = updated

        windowManager.dismissWindow(for: item.id)
        notificationManager.cancelNotification(for: item.id)
        presentedReminderIDs.remove(item.id)
        presentedAdvanceReminderIDs.remove(item.id)
        webhookAttemptedReminderIDs.remove(item.id)
        highlightedReminderID = nil
        reconcileEditingReminder()
        scheduleNextRecurrence(for: currentItem)
        pendingItems = Self.sorted(items: pendingItems)
        syncPendingNotifications()
        dbUpdate(updated)
        scheduleNextTick()
    }

    func focusReminder(_ item: ReminderItem) {
        guard !item.isCompleted else {
            highlightedReminderID = nil
            return
        }
        highlightedReminderID = highlightedReminderID == item.id ? nil : item.id
    }

    func dismissHighlightedReminder() {
        if let highlightedReminder, highlightedReminder.scheduledAt <= Date() {
            presentedReminderIDs.insert(highlightedReminder.id)
        }
        highlightedReminderID = nil
    }

    func snoozeHighlightedReminder() {
        snoozeHighlightedReminder(after: .sixty)
    }

    func snoozeHighlightedReminder(after option: SnoozeOption) {
        guard let highlightedReminder else { return }
        snoozeReminder(highlightedReminder, after: option)
    }

    func snoozeReminder(_ item: ReminderItem) {
        snoozeReminder(item, after: .sixty)
    }

    func snoozeReminder(_ item: ReminderItem, after option: SnoozeOption) {
        guard let index = index(for: item.id) else { return }

        let currentItem = pendingItems[index]
        let snoozeBaseDate = max(Date(), currentItem.scheduledAt)
        let scheduledAt = snoozeBaseDate.addingTimeInterval(TimeInterval(option.minutes * 60))

        let updated = makeItem(
            from: currentItem,
            scheduledAt: scheduledAt,
            tone: Self.tone(for: scheduledAt),
            isHighlighted: false,
            showsMoreButton: true
        )
        pendingItems[index] = updated

        windowManager.dismissWindow(for: item.id)
        notificationManager.cancelNotification(for: item.id)
        presentedReminderIDs.remove(item.id)
        presentedAdvanceReminderIDs.remove(item.id)
        webhookAttemptedReminderIDs.remove(item.id)
        if highlightedReminderID == item.id {
            highlightedReminderID = nil
        }
        reconcileEditingReminder()

        pendingItems = Self.sorted(items: pendingItems)
        syncPendingNotifications()
        dbUpdate(updated)
        scheduleNextTick()
    }

    func deleteReminder(_ item: ReminderItem) {
        pendingItems.removeAll(where: { $0.id == item.id })
        presentedReminderIDs.remove(item.id)
        presentedAdvanceReminderIDs.remove(item.id)
        webhookAttemptedReminderIDs.remove(item.id)
        windowManager.dismissWindow(for: item.id)
        notificationManager.cancelNotification(for: item.id)

        if highlightedReminderID == item.id {
            highlightedReminderID = nil
        }

        if editingReminderID == item.id {
            resetEditingState()
        }

        syncPendingNotifications()
        dbDelete(item.id)
        scheduleNextTick()
    }

    func clearCompleted() {
        let completedIDs = Set(pendingItems.filter(\.isCompleted).map(\.id))
        for id in completedIDs {
            windowManager.dismissWindow(for: id)
            notificationManager.cancelNotification(for: id)
        }
        pendingItems.removeAll(where: \.isCompleted)
        presentedReminderIDs.subtract(completedIDs)
        presentedAdvanceReminderIDs.subtract(completedIDs)
        webhookAttemptedReminderIDs.subtract(completedIDs)
        reconcileHighlightedReminder()
        reconcileEditingReminder()
        syncPendingNotifications()
        dbDeleteCompleted()
        scheduleNextTick()
    }

    func clearDraftValidationMessage() {
        draftValidationMessage = nil
    }

    func clearEditingValidationMessage() {
        editingValidationMessage = nil
    }

    func refreshForPanelPresentation() {
        loadFromDatabase()
    }

    private func loadFromDatabase() {
        let items = db.fetchAll()
        self.pendingItems = Self.sorted(items: items)
        self.syncPendingNotifications()
        self.reconcileHighlightedReminder()
        self.reconcileEditingReminder()
        self.evaluateReminderPresentation()
    }

    private func dbInsert(_ item: ReminderItem) {
        db.insert(item)
    }

    private func dbUpdate(_ item: ReminderItem) {
        db.update(item)
    }

    private func dbDelete(_ id: UUID) {
        db.delete(id: id)
    }

    private func dbDeleteCompleted() {
        db.deleteCompleted()
    }

    private func setupWindowManagerCallbacks() {
        windowManager.onComplete = { [weak self] uuid in
            guard let self else { return }
            if let item = self.pendingItems.first(where: { $0.id == uuid }) {
                self.markCompleted(item)
            }
        }

        windowManager.onSnooze = { [weak self] uuid, option in
            guard let self else { return }
            if let item = self.pendingItems.first(where: { $0.id == uuid }) {
                self.snoozeReminder(item, after: option)
            }
        }

        windowManager.onDismiss = { [weak self] uuid in
            guard let self else { return }
            self.presentedReminderIDs.insert(uuid)
            if self.highlightedReminderID == uuid {
                self.highlightedReminderID = nil
            }
        }
    }

    private func bindPreferences() {
        preferences.$systemNotificationsEnabled
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                guard let self else { return }
                if isEnabled {
                    self.notificationManager.requestAuthorizationIfNeeded()
                }
                self.syncPendingNotifications()
            }
            .store(in: &cancellables)

        preferences.$inAppAlertsEnabled
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                self?.handleInAppAlertsEnabledChange(isEnabled)
            }
            .store(in: &cancellables)

        Publishers.Merge(
            preferences.$weComWebhookURL.removeDuplicates(),
            preferences.$feishuWebhookURL.removeDuplicates()
        )
        .sink { [weak self] _ in
            self?.handleWebhookSettingsChange()
        }
        .store(in: &cancellables)
    }

    private func startReminderTicker() {
        scheduleNextTick()
    }

    private func scheduleNextTick() {
        reminderTimer?.cancel()

        let now = Date()
        let interval = nextTickInterval(from: now)

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval)
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.evaluateReminderPresentation()
                self.scheduleNextTick()
            }
        }
        timer.resume()
        reminderTimer = timer
    }

    private func nextTickInterval(from now: Date) -> TimeInterval {
        let activeItems = pendingItems.filter { !$0.isCompleted }
        guard !activeItems.isEmpty else { return 60 }

        let inAppAlertsEnabled = preferences.inAppAlertsEnabled
        let webhookEnabled = preferences.hasConfiguredWebhook
        var earliest: TimeInterval = 60

        for item in activeItems {
            let untilDue = item.scheduledAt.timeIntervalSince(now)

            if untilDue <= 0 {
                // 已到期但未弹窗，立即触发
                if inAppAlertsEnabled && !presentedReminderIDs.contains(item.id) {
                    return 0.5
                }
                if webhookEnabled && !webhookAttemptedReminderIDs.contains(item.id) {
                    return 0.5
                }
                continue
            }

            // 提前通知窗口
            let untilAdvance = untilDue - Constants.advanceNoticeLeadTime
            if inAppAlertsEnabled && untilAdvance > 0 && !presentedAdvanceReminderIDs.contains(item.id) {
                earliest = min(earliest, untilAdvance)
            }

            if inAppAlertsEnabled || webhookEnabled {
                // 到期时间
                earliest = min(earliest, untilDue)
            }

            // tone 切换点（1 小时前 neutral → warning）
            let untilToneChange = untilDue - 60 * 60
            if untilToneChange > 0 && item.tone == .neutral {
                earliest = min(earliest, untilToneChange)
            }
        }

        // 至少 0.5s，最多 60s，加 0.1s 余量确保时间点已过
        return max(0.5, min(earliest + 0.1, 60))
    }

    private func syncPendingNotifications() {
        notificationManager.syncNotifications(for: pendingItems)
    }

    private func evaluateReminderPresentation(referenceDate: Date = Date()) {
        refreshReminderTones(referenceDate: referenceDate)
        presentAdvanceNoticesIfNeeded(referenceDate: referenceDate)
        checkDueReminders(referenceDate: referenceDate)
    }

    private func presentAdvanceNoticesIfNeeded(referenceDate: Date) {
        guard preferences.inAppAlertsEnabled else {
            return
        }

        let eligibleItems = pendingItems.filter { item in
            guard !item.isCompleted else { return false }
            guard !presentedAdvanceReminderIDs.contains(item.id) else { return false }

            let timeInterval = item.scheduledAt.timeIntervalSince(referenceDate)
            return timeInterval > 0 && timeInterval <= Constants.advanceNoticeLeadTime
        }

        for item in eligibleItems {
            autoPresentAdvanceNotice(for: item, referenceDate: referenceDate)
        }
    }

    private func checkDueReminders(referenceDate: Date) {
        let dueItems = pendingItems.filter { !$0.isCompleted && $0.scheduledAt <= referenceDate }
        guard !dueItems.isEmpty else {
            return
        }

        sendDueReminderWebhooksIfNeeded(for: dueItems)

        guard preferences.inAppAlertsEnabled else {
            return
        }

        dueItems.forEach { presentedAdvanceReminderIDs.insert($0.id) }

        guard let nextDueReminder = dueItems.first(where: {
            !presentedReminderIDs.contains($0.id)
        }) else { return }

        autoPresent(reminderID: nextDueReminder.id)
    }

    private func refreshReminderTones(referenceDate: Date) {
        let updatedItems = pendingItems.map { item in
            guard !item.isCompleted else { return item }
            let nextTone = Self.tone(for: item.scheduledAt, referenceDate: referenceDate)
            guard nextTone != item.tone else { return item }
            return makeItem(from: item, tone: nextTone)
        }

        guard updatedItems != pendingItems else { return }
        pendingItems = Self.sorted(items: updatedItems)
    }

    private func autoPresentAdvanceNotice(for item: ReminderItem, referenceDate: Date) {
        guard preferences.inAppAlertsEnabled else {
            return
        }

        let remainingMinutes = max(1, Int(ceil(item.scheduledAt.timeIntervalSince(referenceDate) / 60)))
        presentedAdvanceReminderIDs.insert(item.id)
        windowManager.showAdvanceNotice(for: item, remainingMinutes: remainingMinutes)
    }

    private func autoPresent(reminderID: ReminderItem.ID) {
        guard preferences.inAppAlertsEnabled else {
            return
        }

        guard !presentedReminderIDs.contains(reminderID) else { return }
        guard let reminder = pendingItems.first(where: { $0.id == reminderID }) else { return }

        presentedReminderIDs.insert(reminderID)
        presentedAdvanceReminderIDs.insert(reminderID)
        highlightedReminderID = reminderID

        NotificationCenter.default.post(name: .reminderDidAutoPresent, object: reminderID)
        windowManager.showReminder(reminder)
    }

    private func handleInAppAlertsEnabledChange(_ isEnabled: Bool) {
        if isEnabled == false {
            highlightedReminderID = nil
            windowManager.dismissAll()
        }

        evaluateReminderPresentation()
        scheduleNextTick()
    }

    private func handleWebhookSettingsChange() {
        webhookAttemptedReminderIDs.removeAll()
        evaluateReminderPresentation()
        scheduleNextTick()
    }

    private func sendDueReminderWebhooksIfNeeded(for dueItems: [ReminderItem]) {
        guard preferences.hasConfiguredWebhook else {
            return
        }

        for item in dueItems where !webhookAttemptedReminderIDs.contains(item.id) {
            webhookAttemptedReminderIDs.insert(item.id)

            let title = item.title
            let scheduleText = item.scheduleText
            Task {
                await webhookNotifier.sendDueReminder(title: title, scheduleText: scheduleText)
            }
        }
    }

    private func reconcileHighlightedReminder() {
        guard let highlightedReminderID else { return }
        if pendingItems.contains(where: { $0.id == highlightedReminderID && !$0.isCompleted }) == false {
            self.highlightedReminderID = nil
        }
    }

    private func reconcileEditingReminder() {
        guard let editingReminderID else { return }
        guard pendingItems.contains(where: { $0.id == editingReminderID && !$0.isCompleted }) else {
            resetEditingState()
            return
        }
    }

    private func presentDraftValidation(_ message: String) {
        draftValidationMessage = message
    }

    private func presentEditingValidation(_ message: String) {
        editingValidationMessage = message
    }

    private func validateScheduledAt(
        _ scheduledAt: Date,
        referenceDate: Date = Date(),
        failureMessage: String,
        presentValidation: (String) -> Void
    ) -> Bool {
        guard scheduledAt > referenceDate else {
            presentValidation(failureMessage)
            return false
        }

        return true
    }

    private func makeDraftReminder(referenceDate: Date = Date()) -> ReminderItem? {
        guard let resolvedDraft = resolveDraftInput(
            title: draftTitle,
            scheduledAt: draftScheduledAt,
            recurrenceRule: draftRecurrenceRule,
            referenceDate: referenceDate,
            presentValidation: presentDraftValidation
        ) else { return nil }

        return ReminderItem(
            title: resolvedDraft.title,
            scheduledAt: resolvedDraft.scheduledAt,
            createdAt: referenceDate,
            tone: Self.tone(for: resolvedDraft.scheduledAt, referenceDate: referenceDate),
            showsMoreButton: true,
            recurrenceRule: resolvedDraft.recurrenceRule
        )
    }

    private func makeEditedReminder(from item: ReminderItem, referenceDate: Date = Date()) -> ReminderItem? {
        guard let resolvedDraft = resolveDraftInput(
            title: editingTitle,
            scheduledAt: editingScheduledAt,
            recurrenceRule: editingRecurrenceRule,
            referenceDate: referenceDate,
            presentValidation: presentEditingValidation
        ) else { return nil }

        return makeItem(
            from: item,
            title: resolvedDraft.title,
            scheduledAt: resolvedDraft.scheduledAt,
            tone: Self.tone(for: resolvedDraft.scheduledAt, referenceDate: referenceDate),
            isCompleted: false,
            isHighlighted: false,
            showsMoreButton: true,
            recurrenceRule: .some(resolvedDraft.recurrenceRule)
        )
    }

    private func persistReminder(_ reminder: ReminderItem) {
        pendingItems.append(reminder)
        pendingItems = Self.sorted(items: pendingItems)
        syncPendingNotifications()
        dbInsert(reminder)
        evaluateReminderPresentation()
        scheduleNextTick()
    }

    private func applyUpdatedReminder(_ item: ReminderItem, resettingPresentationFor reminderID: ReminderItem.ID) {
        guard let itemIndex = index(for: reminderID) else { return }

        pendingItems[itemIndex] = item
        presentedReminderIDs.remove(reminderID)
        presentedAdvanceReminderIDs.remove(reminderID)
        webhookAttemptedReminderIDs.remove(reminderID)

        if highlightedReminderID == reminderID {
            highlightedReminderID = nil
        }

        windowManager.dismissWindow(for: reminderID)
        notificationManager.cancelNotification(for: reminderID)

        pendingItems = Self.sorted(items: pendingItems)
        syncPendingNotifications()
        dbUpdate(item)
        evaluateReminderPresentation()
        scheduleNextTick()
    }

    private func resetDraft() {
        draftTitle = ""
        draftScheduledAt = Self.defaultDraftDate()
        draftRecurrenceRule = nil
        clearDraftValidationMessage()
    }

    private func resetEditingState() {
        editingReminderID = nil
        editingTitle = ""
        editingScheduledAt = Self.defaultDraftDate()
        editingRecurrenceRule = nil
        clearEditingValidationMessage()
    }

    private func applyAIParseResult(_ result: AIParseResult) {
        draftTitle = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
        draftScheduledAt = result.scheduledAt
        draftRecurrenceRule = result.recurrenceRule

        if result.recurrenceRule == nil {
            guard validateScheduledAt(
                result.scheduledAt,
                failureMessage: "AI 解析出的提醒时间必须晚于当前时间，请修改描述后重试",
                presentValidation: presentDraftValidation
            ) else { return }
        }

        addReminder()
    }
}

private extension ReminderStore {
    struct ResolvedDraftInput {
        let title: String
        let scheduledAt: Date
        let recurrenceRule: RecurrenceRule?
    }

    static func defaultDraftDate(from date: Date = Date()) -> Date {
        let interval: TimeInterval = 5 * 60
        let nextTime = ceil(date.timeIntervalSince1970 / interval) * interval
        let roundedDate = Date(timeIntervalSince1970: nextTime)
        return roundedDate <= date ? roundedDate.addingTimeInterval(interval) : roundedDate
    }

    static func sorted(items: [ReminderItem]) -> [ReminderItem] {
        items.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted && rhs.isCompleted
            }
            if lhs.scheduledAt != rhs.scheduledAt {
                return lhs.scheduledAt < rhs.scheduledAt
            }
            return lhs.title.localizedCompare(rhs.title) == .orderedAscending
        }
    }

    static func tone(for date: Date, referenceDate: Date = Date()) -> ReminderItem.ScheduleTone {
        date.timeIntervalSince(referenceDate) <= 60 * 60 ? .warning : .neutral
    }

    static func truncatedDraftTitle(_ title: String) -> String {
        String(title.prefix(maxDraftTitleLength))
    }

    func resolveDraftInput(
        title: String,
        scheduledAt: Date,
        recurrenceRule: RecurrenceRule?,
        referenceDate: Date,
        presentValidation: (String) -> Void
    ) -> ResolvedDraftInput? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }
        guard trimmedTitle.count <= Self.maxDraftTitleLength else {
            presentValidation("待办标题最多 100 个字")
            return nil
        }

        let resolvedScheduledAt: Date
        if let recurrenceRule {
            if scheduledAt > referenceDate {
                resolvedScheduledAt = scheduledAt
            } else if let next = recurrenceRule.nextOccurrence(after: referenceDate) {
                resolvedScheduledAt = next
            } else {
                presentValidation("无法计算下一次重复时间，请检查规则")
                return nil
            }
        } else {
            guard validateScheduledAt(
                scheduledAt,
                referenceDate: referenceDate,
                failureMessage: "提醒时间必须晚于当前时间",
                presentValidation: presentValidation
            ) else { return nil }
            resolvedScheduledAt = scheduledAt
        }

        return ResolvedDraftInput(
            title: trimmedTitle,
            scheduledAt: resolvedScheduledAt,
            recurrenceRule: recurrenceRule
        )
    }

    func index(for id: ReminderItem.ID) -> Int? {
        pendingItems.firstIndex(where: { $0.id == id })
    }

    func makeItem(
        from item: ReminderItem,
        title: String? = nil,
        scheduledAt: Date? = nil,
        createdAt: Date? = nil,
        tone: ReminderItem.ScheduleTone? = nil,
        isCompleted: Bool? = nil,
        isHighlighted: Bool? = nil,
        showsMoreButton: Bool? = nil,
        recurrenceRule: RecurrenceRule?? = nil
    ) -> ReminderItem {
        ReminderItem(
            id: item.id,
            title: title ?? item.title,
            scheduledAt: scheduledAt ?? item.scheduledAt,
            createdAt: createdAt ?? item.createdAt,
            tone: tone ?? item.tone,
            isCompleted: isCompleted ?? item.isCompleted,
            isHighlighted: isHighlighted ?? item.isHighlighted,
            showsMoreButton: showsMoreButton ?? item.showsMoreButton,
            recurrenceRule: recurrenceRule ?? item.recurrenceRule
        )
    }

    func scheduleNextRecurrence(for item: ReminderItem) {
        guard let rule = item.recurrenceRule else { return }
        let baseDate = max(item.scheduledAt, Date())
        guard let nextDate = rule.nextOccurrence(after: baseDate) else { return }

        let nextItem = ReminderItem(
            title: item.title,
            scheduledAt: nextDate,
            createdAt: Date(),
            tone: Self.tone(for: nextDate),
            showsMoreButton: true,
            recurrenceRule: rule
        )
        pendingItems.append(nextItem)
        dbInsert(nextItem)
    }
}
