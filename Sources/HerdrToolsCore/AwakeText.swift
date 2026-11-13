import Foundation

public enum AwakeText {
    /// Countdown such as "2h 12m" or "45m". Rounds up so a running timer never reads "0m".
    public static func remaining(_ seconds: TimeInterval) -> String {
        let minutes = Int((max(0, seconds) / 60).rounded(.up))
        let hours = minutes / 60
        return hours > 0 ? "\(hours)h \(minutes % 60)m" : "\(minutes)m"
    }

    /// Menu label for a keep-awake duration: "30m", "2h" or "1 day".
    public static func choice(minutes: Int) -> String {
        if minutes == 1440 { return "1 day" }
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h"
    }
}
