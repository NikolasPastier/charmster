import Foundation
import UserNotifications

/// Local-notification scheduler for the daily practice reminder.
/// Honors the per-category flags + quiet hours saved on `PersonalizationProfile`.
/// Push categories that don't have a backend (email digest, product, marketing,
/// daily challenge, new content, re-engagement) only persist a preference here
/// for future use — they are not scheduled locally because they would require
/// a server.
enum NotificationManager {

    private static let dailyReminderId = "charmster.daily-reminder"
    private static let askedKey = "charmster.notif.askedOnce.v1"

    /// Has the user been asked at least once? Used to gate the in-context OS prompt.
    static var hasAskedOnce: Bool {
        UserDefaults.standard.bool(forKey: askedKey)
    }

    static func markAsked() {
        UserDefaults.standard.set(true, forKey: askedKey)
    }

    /// Request OS permission. Safe to call multiple times — iOS no-ops after grant/deny.
    static func requestAuthorization() async -> Bool {
        markAsked()
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Re-apply scheduling based on the current profile. Idempotent: removes the
    /// existing daily reminder request and reschedules only if all of:
    /// - `dailyReminderTime` is set,
    /// - `notificationsStreak` is true,
    /// - the reminder hour isn't inside the quiet-hours window.
    /// Always cancels the existing daily reminder first so toggling OFF works.
    static func applyDailyReminder(profile: PersonalizationProfile) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderId])

        guard profile.notificationsStreak,
              let time = profile.dailyReminderTime else { return }

        if isInsideQuietHours(time, profile: profile) { return }

        var comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        comps.second = 0

        let content = UNMutableNotificationContent()
        content.title = "Keep your streak"
        content.body = "Two minutes of practice keeps the rhythm alive."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: dailyReminderId, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    /// True when `time` falls inside [quietStart, quietEnd), wrapping past midnight.
    private static func isInsideQuietHours(_ time: Date, profile: PersonalizationProfile) -> Bool {
        guard let qs = profile.quietHoursStart, let qe = profile.quietHoursEnd else { return false }
        let cal = Calendar.current
        let mins: (Date) -> Int = { d in
            let c = cal.dateComponents([.hour, .minute], from: d)
            return (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
        let t = mins(time), s = mins(qs), e = mins(qe)
        if s == e { return false }
        if s < e { return t >= s && t < e }
        // wraps midnight, e.g. 22:00 -> 07:00
        return t >= s || t < e
    }
}
