import Foundation
import PlasticcCore
import UserNotifications

/// The three things you can set. Stored in UserDefaults, read with `@AppStorage` keys below.
enum Settings {
    static let developTimeKey = "developTime"
    static let dateStampKey = "dateStamp"
    static let soundsKey = Feel.soundsKey

    static var developTime: DevelopTime {
        UserDefaults.standard.string(forKey: developTimeKey).flatMap(DevelopTime.init) ?? .hour
    }

    static var dateStamp: Bool {
        UserDefaults.standard.object(forKey: dateStampKey) as? Bool ?? true
    }
}

extension DevelopTime {
    var title: String {
        switch self {
        case .instant: "Instant"
        case .hour: "1 hour"
        case .nextMorning: "Next morning"
        }
    }

    var detail: String {
        switch self {
        case .instant: "Prints come out as soon as you rewind."
        case .hour: "Drop it at the lab, come back in an hour."
        case .nextMorning: "Ready at 9 AM, like the one-hour place that wasn't."
        }
    }
}

/// The local notification that says the prints are ready.
enum LabNotice {
    private static let id = "roll-ready"

    /// Asks once; returns whether notices may be shown.
    @discardableResult
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func schedule(at date: Date, film: String, exposures: Int) async {
        guard await requestPermission() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Your prints are ready"
        content.body = "\(exposures) exposures of \(film), back from the lab."
        content.sound = .default
        let seconds = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
