import Foundation
import SwiftUI

struct ReminderItem: Identifiable, Hashable {
    enum ScheduleTone: Hashable {
        case neutral
        case warning
        case completed
    }

    let id: UUID
    let title: String
    let scheduledAt: Date
    let createdAt: Date
    let tone: ScheduleTone
    let isCompleted: Bool
    let isHighlighted: Bool
    let showsMoreButton: Bool

    var scheduleText: String {
        Self.scheduleText(for: scheduledAt)
    }

    init(
        id: UUID = UUID(),
        title: String,
        scheduledAt: Date,
        createdAt: Date = Date(),
        tone: ScheduleTone = .neutral,
        isCompleted: Bool = false,
        isHighlighted: Bool = false,
        showsMoreButton: Bool = true
    ) {
        self.id = id
        self.title = title
        self.scheduledAt = scheduledAt
        self.createdAt = createdAt
        self.tone = tone
        self.isCompleted = isCompleted
        self.isHighlighted = isHighlighted
        self.showsMoreButton = showsMoreButton
    }

    static func scheduleText(for date: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let timeText = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return "今天 \(timeText)"
        }

        if calendar.isDateInTomorrow(date) {
            return "明天 \(timeText)"
        }

        return "\(weekdayFormatter.string(from: date)) \(timeText)"
    }
}

private extension ReminderItem {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEE HH:mm"
        return formatter
    }()
}

enum ReminderListScope: String, CaseIterable, Identifiable {
    case createdToday
    case dueToday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .createdToday:
            return "今天创建"
        case .dueToday:
            return "今天执行"
        }
    }

    var emptyTitle: String {
        switch self {
        case .createdToday:
            return "今天还没有新建待办"
        case .dueToday:
            return "今天没有待执行的事项"
        }
    }

    var emptySubtitle: String {
        switch self {
        case .createdToday:
            return "新建的待办会出现在这里，方便快速回看今天录入了什么。"
        case .dueToday:
            return "只有计划在今天执行的待办会显示在这里。"
        }
    }
}
