import Foundation
import SwiftData
import UserNotifications

@MainActor
enum NotificationScheduler {
    static let dailyIdentifier = "shelfie.daily.expiry"
    static let weeklyIdentifier = "shelfie.weekly.report"
    static let foodIdentifier = "shelfie.food."
    static let categoryIdentifier = "shelfie.food.actions"
    static let eatenAction = "shelfie.eaten"
    static let discardedAction = "shelfie.discarded"
    static let maximumRequests = 60
    private static var revision = 0
    private static var schedulingTask: Task<Void, Never>?
    private(set) static var schedulingError: String?

    struct PlannedReminder {
        var identifier: String
        var foodID: UUID?
        var priorityDate: Date = .distantFuture
        var deliveryDate: Date
        var content: UNMutableNotificationContent
    }

    static func registerActions(locale: Locale) {
        let actions = [
            UNNotificationAction(identifier: eatenAction, title: locale.text("food.eaten"), options: [.foreground, .authenticationRequired]),
            UNNotificationAction(identifier: discardedAction, title: locale.text("food.discarded"), options: [.foreground, .destructive, .authenticationRequired])
        ]
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: categoryIdentifier, actions: actions, intentIdentifiers: [], options: [])
        ])
    }

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            schedulingError = error.localizedDescription
            return false
        }
    }

    // Retained for preview/testing; empty content is never scheduled.
    static func dailyContent(foods: [FoodItemRecord], warningDays: Int, locale: Locale,
                             deliveryDate: Date, calendar: Calendar) -> UNMutableNotificationContent {
        let relevant = foods.filter {
            $0.status == .active && (FreshnessRules.remainingDays(from: $0.effectiveExpiryDate, now: deliveryDate, calendar: calendar) ?? Int.max) <= max(0, warningDays)
        }.sorted { ($0.effectiveExpiryDate ?? .distantFuture) < ($1.effectiveExpiryDate ?? .distantFuture) }
        let content = UNMutableNotificationContent()
        content.sound = .default
        let expired = relevant.filter {
            (FreshnessRules.remainingDays(from: $0.effectiveExpiryDate, now: deliveryDate, calendar: calendar) ?? Int.max) <= 0
        }
        content.title = locale.text(expired.isEmpty ? "notif.soonTitle" : "notif.expiredTitle")
        content.body = (expired.isEmpty ? relevant : expired).prefix(4).map(\.name).joined(separator: ", ")
        return content
    }

    /// One warning and one expiry request per dated batch, including distant expiry dates.
    /// Dates use the local calendar and next valid wall-clock time across DST transitions.
    static func plannedReminders(foods: [FoodItemRecord], warningDays: Int, hour: Int, minute: Int,
                                 weeklyEnabled: Bool, locale: Locale, now: Date = .now,
                                 calendar: Calendar = .current, limit: Int = 60) -> [PlannedReminder] {
        let active = foods.filter { $0.status == .active && $0.effectiveExpiryDate != nil }
        var plans: [PlannedReminder] = []
        var weeklyDates: Set<Date> = []
        func delivery(on day: Date) -> Date? {
            calendar.date(bySettingHour: max(0, min(23, hour)), minute: max(0, min(59, minute)), second: 0,
                          of: day, matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
        }
        let nextDelivery = delivery(on: now).flatMap { $0 > now ? $0 : nil }
            ?? calendar.date(byAdding: .day, value: 1, to: now).flatMap(delivery)
        for food in active {
            guard let expiry = food.effectiveExpiryDate, let nextDelivery else { continue }
            let expiryDay = calendar.startOfDay(for: expiry)
            let warningDay = calendar.date(byAdding: .day, value: -max(0, warningDays), to: expiryDay) ?? expiryDay
            let expiryDelivery = max(delivery(on: expiryDay) ?? nextDelivery, nextDelivery)
            var dates: [(String, Date)] = [("expiry", expiryDelivery)]
            if warningDays > 0, expiryDay > calendar.startOfDay(for: now),
               let warningDelivery = delivery(on: warningDay), max(warningDelivery, nextDelivery) < expiryDelivery {
                dates.append(("warning", max(warningDelivery, nextDelivery)))
            }
            for (kind, date) in dates {
                let content = dailyContent(foods: [food], warningDays: warningDays, locale: locale, deliveryDate: date, calendar: calendar)
                content.userInfo = ["foodID": food.id.uuidString]
                content.categoryIdentifier = categoryIdentifier
                plans.append(.init(identifier: "\(foodIdentifier)\(food.id.uuidString).\(kind)", foodID: food.id, priorityDate: expiry,
                                   deliveryDate: date, content: content))
                if weeklyEnabled {
                    let weekday = calendar.component(.weekday, from: date)
                    if let sunday = calendar.date(byAdding: .day, value: (8 - weekday) % 7, to: date),
                       let report = delivery(on: sunday), report > now {
                        weeklyDates.insert(report)
                    }
                }
            }
        }
        for date in weeklyDates {
            let relevant = active.filter {
                guard let remaining = FreshnessRules.remainingDays(from: $0.effectiveExpiryDate, now: date, calendar: calendar) else { return false }
                return remaining >= -6 && remaining <= 7
            }
            guard !relevant.isEmpty else { continue }
            let content = UNMutableNotificationContent()
            content.sound = .default
            content.title = locale.text("notif.weeklyTitle")
            let expired = relevant.filter { ($0.effectiveExpiryDate ?? .distantFuture) < calendar.startOfDay(for: date) }.count
            content.body = locale.format("notif.weeklyBody", expired, relevant.count - expired)
            plans.append(.init(identifier: "\(weeklyIdentifier).\(Int(date.timeIntervalSince1970))", foodID: nil, deliveryDate: date, content: content))
        }
        return Array(plans.sorted {
            if $0.deliveryDate != $1.deliveryDate { return $0.deliveryDate < $1.deliveryDate }
            // At the same time, actionable food reminders take precedence over reports.
            if ($0.foodID != nil) != ($1.foodID != nil) { return $0.foodID != nil }
            if $0.priorityDate != $1.priorityDate { return $0.priorityDate < $1.priorityDate }
            return $0.identifier < $1.identifier
        }.prefix(max(0, min(maximumRequests, limit))))
    }

    static func reschedule(settings: SettingsStore, context: ModelContext) async {
        // Serialize system writes; an older async add must never arrive after a newer removal.
        revision += 1
        let requestedRevision = revision
        let previous = schedulingTask
        let task = Task { @MainActor in
            await previous?.value
            guard requestedRevision == revision else { return }
            await performReschedule(settings: settings, context: context)
        }
        schedulingTask = task
        await task.value
    }

    private static func performReschedule(settings: SettingsStore, context: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        schedulingError = nil
        let permission = await center.notificationSettings()
        var plans: [PlannedReminder] = []
        if settings.notificationsEnabled, [.authorized, .provisional, .ephemeral].contains(permission.authorizationStatus) {
            do {
                let foods = try context.fetch(FetchDescriptor<FoodItemRecord>())
                plans = plannedReminders(foods: foods, warningDays: settings.warningDays, hour: settings.reminderHour,
                                         minute: settings.reminderMinute, weeklyEnabled: settings.weeklyReportEnabled,
                                         locale: settings.locale, calendar: settings.calendar)
            } catch {
                // Keep the prior valid schedule when the inventory cannot be read.
                schedulingError = error.localizedDescription
                return
            }
        }
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter {
            $0.hasPrefix(dailyIdentifier) || $0.hasPrefix(weeklyIdentifier) || $0.hasPrefix(foodIdentifier)
        })
        do {
            registerActions(locale: settings.locale)
            for plan in plans {
                var components = settings.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: plan.deliveryDate)
                components.calendar = settings.calendar
                components.timeZone = settings.calendar.timeZone
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                try await center.add(UNNotificationRequest(identifier: plan.identifier, content: plan.content, trigger: trigger))
            }
        } catch {
            schedulingError = error.localizedDescription
        }
    }

    static func resolve(foodID: UUID, status: FoodStatus, context: ModelContext, now: Date = .now) throws {
        guard let food = try context.fetch(FetchDescriptor<FoodItemRecord>()).first(where: { $0.id == foodID }) else {
            throw ActionError.missingFood
        }
        guard food.status == .active else { return } // Repeated responses are idempotent.
        let oldStatus = food.status
        let oldDate = food.resolvedDate
        let oldQuantity = food.quantity
        food.status = status
        food.resolvedDate = now
        if status == .consumed { food.quantity = 0 }
        do { try context.save() }
        catch {
            context.rollback()
            food.status = oldStatus
            food.resolvedDate = oldDate
            food.quantity = oldQuantity
            throw error
        }
    }

    enum ActionError: LocalizedError {
        case missingFood
        var errorDescription: String? { "This food no longer exists. Open Shelfie to check your inventory." }
    }
}
