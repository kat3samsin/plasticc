import Foundation

/// How long the lab takes once a roll is rewound.
public enum DevelopTime: String, CaseIterable, Codable, Sendable {
    case instant
    case hour
    /// Ready at 9 the next morning, or this morning if it's before 9.
    case nextMorning

    public static let readyHour = 9

    public func readyAt(from now: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .instant:
            return now
        case .hour:
            return now.addingTimeInterval(3600)
        case .nextMorning:
            let nine = DateComponents(hour: Self.readyHour, minute: 0, second: 0)
            return calendar.nextDate(after: now, matching: nine, matchingPolicy: .nextTime) ?? now.addingTimeInterval(12 * 3600)
        }
    }
}
