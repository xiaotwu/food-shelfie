import Foundation
import SwiftData
import UserNotifications

@MainActor
enum NotificationScheduler {
    static let dailyIdentifier = "shelfie.daily.expiry"
    static let weeklyIdentifier = "shelfie.weekly.report"

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func reschedule(settings: SettingsStore, context: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyIdentifier, weeklyIdentifier])
        guard settings.notificationsEnabled else { return }
        _ = await requestAuthorization()
        let locale = settings.locale

        let foods = ((try? context.fetch(FetchDescriptor<FoodItemRecord>())) ?? [])
            .filter { $0.status == .active }
        let warningDays = max(settings.warningDays, 0)
        let expired = foods.filter { ($0.remainingDays ?? 1) < 0 }
        let today = foods.filter { ($0.remainingDays ?? 1) == 0 }
        let soon = foods.filter { item in
            let remaining = item.remainingDays ?? 99
            return remaining > 0 && remaining <= max(warningDays, 7)
        }

        let content = UNMutableNotificationContent()
        content.sound = .default
        if !expired.isEmpty || !today.isEmpty {
            content.title = locale.text("notif.expiredTitle")
            content.body = (expired + today).prefix(3).map(\.name).joined(separator: ", ")
        } else if !soon.isEmpty {
            content.title = locale.text("notif.soonTitle")
            content.body = soon.prefix(4).map(\.name).joined(separator: ", ")
        } else {
            content.title = locale.text("notif.checkTitle")
            content.body = locale.text("notif.checkBody")
        }

        var date = DateComponents()
        date.hour = settings.reminderHour
        date.minute = settings.reminderMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: dailyIdentifier, content: content, trigger: trigger)
        try? await center.add(request)

        if settings.weeklyReportEnabled {
            let weekly = UNMutableNotificationContent()
            weekly.sound = .default
            weekly.title = locale.text("notif.weeklyTitle")
            let overview = AnalyticsEngine.overview(items: foods.map {
                .init(status: $0.status, expiryDate: $0.expiryDate, resolvedDate: $0.resolvedDate, purchaseDate: $0.purchaseDate)
            })
            weekly.body = locale.format("notif.weeklyBody", overview.expired, overview.expiring)
            var weeklyDate = DateComponents()
            weeklyDate.weekday = 1
            weeklyDate.hour = settings.reminderHour
            weeklyDate.minute = settings.reminderMinute
            let weeklyTrigger = UNCalendarNotificationTrigger(dateMatching: weeklyDate, repeats: true)
            let weeklyRequest = UNNotificationRequest(identifier: weeklyIdentifier, content: weekly, trigger: weeklyTrigger)
            try? await center.add(weeklyRequest)
        }
    }
}
