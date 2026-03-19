import Foundation
import SwiftUI

// MARK: - Recurrence Rule

enum RecurrenceRule: Hashable, Codable {
    case daily(hour: Int, minute: Int)
    case weekly(weekday: Int, hour: Int, minute: Int)
    case cron(String)

    var displayText: String {
        switch self {
        case .daily(let hour, let minute):
            return "每天 \(String(format: "%02d:%02d", hour, minute))"
        case .weekly(let weekday, let hour, let minute):
            let name = Self.weekdayName(weekday)
            return "每\(name) \(String(format: "%02d:%02d", hour, minute))"
        case .cron(let expr):
            return "Cron: \(expr)"
        }
    }

    var shortLabel: String {
        switch self {
        case .daily: return "每天"
        case .weekly(let weekday, _, _): return "每\(Self.weekdayName(weekday))"
        case .cron: return "Cron"
        }
    }

    func nextOccurrence(after date: Date) -> Date? {
        let calendar = Calendar.autoupdatingCurrent
        switch self {
        case .daily(let hour, let minute):
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = minute
            components.second = 0
            guard let candidate = calendar.date(from: components) else { return nil }
            return candidate > date ? candidate : calendar.date(byAdding: .day, value: 1, to: candidate)

        case .weekly(let weekday, let hour, let minute):
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear, .weekday], from: date)
            components.weekday = weekday
            components.hour = hour
            components.minute = minute
            components.second = 0
            guard let candidate = calendar.date(from: components) else { return nil }
            return candidate > date ? candidate : calendar.date(byAdding: .weekOfYear, value: 1, to: candidate)

        case .cron(let expression):
            return CronExpression.parse(expression)?.nextDate(after: date)
        }
    }

    private static func weekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "周日"
        case 2: return "周一"
        case 3: return "周二"
        case 4: return "周三"
        case 5: return "周四"
        case 6: return "周五"
        case 7: return "周六"
        default: return "周?"
        }
    }
}

// MARK: - Cron Expression Parser

struct CronExpression {
    let minutes: Set<Int>
    let hours: Set<Int>
    let daysOfMonth: Set<Int>
    let months: Set<Int>
    let daysOfWeek: Set<Int>

    static func parse(_ expression: String) -> CronExpression? {
        let parts = expression.trimmingCharacters(in: .whitespaces).split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count == 5 else { return nil }

        guard let minutes = parseField(String(parts[0]), range: 0...59),
              let hours = parseField(String(parts[1]), range: 0...23),
              let daysOfMonth = parseField(String(parts[2]), range: 1...31),
              let months = parseField(String(parts[3]), range: 1...12),
              let daysOfWeek = parseField(String(parts[4]), range: 0...6)
        else { return nil }

        return CronExpression(minutes: minutes, hours: hours, daysOfMonth: daysOfMonth, months: months, daysOfWeek: daysOfWeek)
    }

    func nextDate(after date: Date) -> Date? {
        let calendar = Calendar.autoupdatingCurrent
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        comps.second = 0

        guard var current = calendar.date(from: comps) else { return nil }
        if current <= date {
            current = calendar.date(byAdding: .minute, value: 1, to: current) ?? current
        }

        let sortedMonths = months.sorted()
        let sortedDays = daysOfMonth.sorted()
        let sortedHours = hours.sorted()
        let sortedMinutes = minutes.sorted()

        // 最多扫 4 年（覆盖闰年周期）
        let maxYear = comps.year! + 4

        comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: current)

        while comps.year! <= maxYear {
            // 月
            guard let month = nextMatch(in: sortedMonths, from: comps.month!) else {
                comps.year! += 1; comps.month = sortedMonths.first!; comps.day = sortedDays.first!
                comps.hour = sortedHours.first!; comps.minute = sortedMinutes.first!
                continue
            }
            if month != comps.month { comps.month = month; comps.day = sortedDays.first!; comps.hour = sortedHours.first!; comps.minute = sortedMinutes.first! }

            // 日 + 星期
            guard let validDay = nextValidDay(year: comps.year!, month: comps.month!, from: comps.day!, sortedDays: sortedDays, calendar: calendar) else {
                comps.month! += 1; comps.day = 1; comps.hour = sortedHours.first!; comps.minute = sortedMinutes.first!
                continue
            }
            if validDay != comps.day { comps.day = validDay; comps.hour = sortedHours.first!; comps.minute = sortedMinutes.first! }

            // 时
            guard let hour = nextMatch(in: sortedHours, from: comps.hour!) else {
                comps.day! += 1; comps.hour = sortedHours.first!; comps.minute = sortedMinutes.first!
                continue
            }
            if hour != comps.hour { comps.hour = hour; comps.minute = sortedMinutes.first! }

            // 分
            guard let minute = nextMatch(in: sortedMinutes, from: comps.minute!) else {
                comps.hour! += 1; comps.minute = sortedMinutes.first!
                continue
            }
            comps.minute = minute

            if let result = calendar.date(from: comps), result > date {
                return result
            }

            // 推进一分钟
            comps.minute! += 1
        }

        return nil
    }

    private func nextMatch(in sorted: [Int], from value: Int) -> Int? {
        sorted.first { $0 >= value }
    }

    private func nextValidDay(year: Int, month: Int, from startDay: Int, sortedDays: [Int], calendar: Calendar) -> Int? {
        var dateComps = DateComponents(year: year, month: month, day: 1)
        guard let monthDate = calendar.date(from: dateComps),
              let daysInMonth = calendar.range(of: .day, in: .month, for: monthDate)?.count
        else { return nil }

        for day in sortedDays where day >= startDay && day <= daysInMonth {
            dateComps.day = day
            guard let d = calendar.date(from: dateComps) else { continue }
            let weekday = calendar.component(.weekday, from: d)
            let cronWeekday = weekday == 1 ? 0 : weekday - 1
            if daysOfWeek.contains(cronWeekday) {
                return day
            }
        }
        return nil
    }

    private static func parseField(_ field: String, range: ClosedRange<Int>) -> Set<Int>? {
        if field == "*" {
            return Set(range)
        }

        var result = Set<Int>()
        let segments = field.split(separator: ",")

        for segment in segments {
            let str = String(segment)

            if str.contains("/") {
                let stepParts = str.split(separator: "/")
                guard stepParts.count == 2, let step = Int(stepParts[1]), step > 0 else { return nil }
                let basePart = String(stepParts[0])
                let start: Int
                if basePart == "*" {
                    start = range.lowerBound
                } else if let s = Int(basePart), range.contains(s) {
                    start = s
                } else {
                    return nil
                }
                var v = start
                while v <= range.upperBound {
                    result.insert(v)
                    v += step
                }
            } else if str.contains("-") {
                let rangeParts = str.split(separator: "-")
                guard rangeParts.count == 2,
                      let lo = Int(rangeParts[0]), let hi = Int(rangeParts[1]),
                      range.contains(lo), range.contains(hi), lo <= hi
                else { return nil }
                for v in lo...hi { result.insert(v) }
            } else if let value = Int(str), range.contains(value) {
                result.insert(value)
            } else {
                return nil
            }
        }

        return result.isEmpty ? nil : result
    }
}

// MARK: - Reminder Item

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
    let recurrenceRule: RecurrenceRule?

    var scheduleSummaryText: String {
        Self.scheduleText(for: scheduledAt)
    }

    var scheduleText: String {
        var text = scheduleSummaryText
        if let rule = recurrenceRule {
            text += "  ↻ \(rule.shortLabel)"
        }
        return text
    }

    init(
        id: UUID = UUID(),
        title: String,
        scheduledAt: Date,
        createdAt: Date = Date(),
        tone: ScheduleTone = .neutral,
        isCompleted: Bool = false,
        isHighlighted: Bool = false,
        showsMoreButton: Bool = true,
        recurrenceRule: RecurrenceRule? = nil
    ) {
        self.id = id
        self.title = title
        self.scheduledAt = scheduledAt
        self.createdAt = createdAt
        self.tone = tone
        self.isCompleted = isCompleted
        self.isHighlighted = isHighlighted
        self.showsMoreButton = showsMoreButton
        self.recurrenceRule = recurrenceRule
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
