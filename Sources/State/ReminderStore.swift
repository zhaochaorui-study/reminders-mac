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

    @Published var draftTitle: String = ""
    @Published var draftScheduledAt: Date
    @Published var draftRecurrenceRule: RecurrenceRule?
    @Published var listScope: ReminderListScope = .dueToday
    @Published private(set) var pendingItems: [ReminderItem] = []
    @Published private(set) var highlightedReminderID: ReminderItem.ID?
    @Published private(set) var isAIParsing: Bool = false
    @Published private(set) var draftValidationMessage: String?

    private var reminderTimer: DispatchSourceTimer?
    private var presentedReminderIDs: Set<ReminderItem.ID> = []
    private var presentedAdvanceReminderIDs: Set<ReminderItem.ID> = []
    private let windowManager = ReminderWindowManager()
    private let notificationManager = ReminderNotificationManager.shared
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

    init() {
        self.draftScheduledAt = Self.defaultDraftDate()
        setupWindowManagerCallbacks()
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
        if highlightedReminderID == item.id {
            highlightedReminderID = nil
        }

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
        highlightedReminderID = nil
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
        guard let highlightedReminder else { return }
        snoozeReminder(highlightedReminder)
    }

    func snoozeReminder(_ item: ReminderItem) {
        guard let index = index(for: item.id) else { return }

        let currentItem = pendingItems[index]
        let snoozeBaseDate = max(Date(), currentItem.scheduledAt)
        let scheduledAt = snoozeBaseDate.addingTimeInterval(60 * 60)

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
        if highlightedReminderID == item.id {
            highlightedReminderID = nil
        }

        pendingItems = Self.sorted(items: pendingItems)
        syncPendingNotifications()
        dbUpdate(updated)
        scheduleNextTick()
    }

    func deleteReminder(_ item: ReminderItem) {
        pendingItems.removeAll(where: { $0.id == item.id })
        presentedReminderIDs.remove(item.id)
        presentedAdvanceReminderIDs.remove(item.id)
        windowManager.dismissWindow(for: item.id)
        notificationManager.cancelNotification(for: item.id)

        if highlightedReminderID == item.id {
            highlightedReminderID = nil
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
        reconcileHighlightedReminder()
        syncPendingNotifications()
        dbDeleteCompleted()
        scheduleNextTick()
    }

    func clearDraftValidationMessage() {
        draftValidationMessage = nil
    }

    func refreshForPanelPresentation() {
        loadFromDatabase()
    }

    private func loadFromDatabase() {
        let items = db.fetchAll()
        self.pendingItems = Self.sorted(items: items)
        self.syncPendingNotifications()
        self.reconcileHighlightedReminder()
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

        windowManager.onSnooze = { [weak self] uuid in
            guard let self else { return }
            if let item = self.pendingItems.first(where: { $0.id == uuid }) {
                self.snoozeReminder(item)
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

        var earliest: TimeInterval = 60

        for item in activeItems {
            let untilDue = item.scheduledAt.timeIntervalSince(now)

            if untilDue <= 0 {
                // 已到期但未弹窗，立即触发
                if !presentedReminderIDs.contains(item.id) {
                    return 0.5
                }
                continue
            }

            // 提前通知窗口
            let untilAdvance = untilDue - Constants.advanceNoticeLeadTime
            if untilAdvance > 0 && !presentedAdvanceReminderIDs.contains(item.id) {
                earliest = min(earliest, untilAdvance)
            }

            // 到期时间
            earliest = min(earliest, untilDue)

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
        pendingItems
            .filter { !$0.isCompleted && $0.scheduledAt <= referenceDate }
            .forEach { presentedAdvanceReminderIDs.insert($0.id) }

        guard let nextDueReminder = pendingItems.first(where: {
            !$0.isCompleted &&
            $0.scheduledAt <= referenceDate &&
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
        let remainingMinutes = max(1, Int(ceil(item.scheduledAt.timeIntervalSince(referenceDate) / 60)))
        presentedAdvanceReminderIDs.insert(item.id)
        windowManager.showAdvanceNotice(for: item, remainingMinutes: remainingMinutes)
    }

    private func autoPresent(reminderID: ReminderItem.ID) {
        guard !presentedReminderIDs.contains(reminderID) else { return }
        guard let reminder = pendingItems.first(where: { $0.id == reminderID }) else { return }

        presentedReminderIDs.insert(reminderID)
        presentedAdvanceReminderIDs.insert(reminderID)
        highlightedReminderID = reminderID

        NotificationCenter.default.post(name: .reminderDidAutoPresent, object: reminderID)
        windowManager.showReminder(reminder)
    }

    private func reconcileHighlightedReminder() {
        guard let highlightedReminderID else { return }
        if pendingItems.contains(where: { $0.id == highlightedReminderID && !$0.isCompleted }) == false {
            self.highlightedReminderID = nil
        }
    }

    private func presentDraftValidation(_ message: String) {
        draftValidationMessage = message
    }

    private func validateScheduledAt(
        _ scheduledAt: Date,
        referenceDate: Date = Date(),
        failureMessage: String
    ) -> Bool {
        guard scheduledAt > referenceDate else {
            presentDraftValidation(failureMessage)
            return false
        }

        return true
    }

    private func makeDraftReminder(referenceDate: Date = Date()) -> ReminderItem? {
        let trimmedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }

        let resolvedScheduledAt: Date
        if let rule = draftRecurrenceRule {
            // 周期性提醒：如果手选时间已过，自动算下一次
            if draftScheduledAt > referenceDate {
                resolvedScheduledAt = draftScheduledAt
            } else if let next = rule.nextOccurrence(after: referenceDate) {
                resolvedScheduledAt = next
            } else {
                presentDraftValidation("无法计算下一次重复时间，请检查规则")
                return nil
            }
        } else {
            guard validateScheduledAt(
                draftScheduledAt,
                referenceDate: referenceDate,
                failureMessage: "提醒时间必须晚于当前时间"
            ) else { return nil }
            resolvedScheduledAt = draftScheduledAt
        }

        return ReminderItem(
            title: trimmedTitle,
            scheduledAt: resolvedScheduledAt,
            createdAt: referenceDate,
            tone: Self.tone(for: resolvedScheduledAt, referenceDate: referenceDate),
            showsMoreButton: true,
            recurrenceRule: draftRecurrenceRule
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

    private func resetDraft() {
        draftTitle = ""
        draftScheduledAt = Self.defaultDraftDate()
        draftRecurrenceRule = nil
        clearDraftValidationMessage()
    }

    private func applyAIParseResult(_ result: AIParseResult) {
        draftTitle = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
        draftScheduledAt = result.scheduledAt
        draftRecurrenceRule = result.recurrenceRule

        if result.recurrenceRule == nil {
            guard validateScheduledAt(
                result.scheduledAt,
                failureMessage: "AI 解析出的提醒时间必须晚于当前时间，请修改描述后重试"
            ) else { return }
        }

        addReminder()
    }
}

private extension ReminderStore {
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
