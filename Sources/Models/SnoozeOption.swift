import Foundation

enum SnoozeOption: Int, CaseIterable, Identifiable {
    case fifteen = 15
    case thirty = 30
    case sixty = 60

    var id: Int { rawValue }

    var minutes: Int {
        rawValue
    }

    var title: String {
        "\(rawValue) 分钟"
    }
}
