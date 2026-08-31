import Foundation

struct FreshnessStatistic: Equatable, Sendable {
    var fresh: Int = 0
    var urgent: Int = 0
    var warning: Int = 0
    var expiry: Int = 0

    var total: Int { fresh + urgent + warning + expiry }
}

struct SpoilagePoint: Equatable, Identifiable, Sendable {
    var date: Date
    var waste: Int
    var consumed: Int
    var id: Date { date }
}

struct WeeklyExpiryPoint: Equatable, Identifiable, Sendable {
    var date: Date
    var count: Int
    var id: Date { date }
}

struct AnalyticsSnapshot: Equatable, Sendable {
    var expiredCount: Int
    var expiringSoonCount: Int
    var weekly: [WeeklyExpiryPoint]
    var freshness: FreshnessStatistic
    var spoilage: [SpoilagePoint]
}

enum AnalyticsEngine {
    struct Item: Equatable, Sendable {
        var status: FoodStatus
        var expiryDate: Date?
        var resolvedDate: Date?
        var purchaseDate: Date
    }

    static func snapshot(
        items: [Item],
        period: AnalyticsPeriod,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> AnalyticsSnapshot {
        AnalyticsSnapshot(
            expiredCount: overview(items: items, now: now, calendar: calendar).expired,
            expiringSoonCount: overview(items: items, now: now, calendar: calendar).expiring,
            weekly: weeklyExpiry(items: items, now: now, calendar: calendar),
            freshness: freshness(items: items, period: period, now: now, calendar: calendar),
            spoilage: spoilage(items: items, period: period, now: now, calendar: calendar)
        )
    }

    static func overview(
        items: [Item],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (expired: Int, expiring: Int) {
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let daysToSunday = (8 - weekday) % 7
        let endOfWeek = calendar.date(byAdding: .day, value: daysToSunday, to: today) ?? today
        let active = items.filter { $0.status == .active }
        let expired = active.filter { item in
            guard let expiry = item.expiryDate else { return false }
            return calendar.startOfDay(for: expiry) < today
        }.count
        let expiring = active.filter { item in
            guard let expiry = item.expiryDate else { return false }
            let day = calendar.startOfDay(for: expiry)
            return day >= today && day <= endOfWeek
        }.count
        return (expired, expiring)
    }

    static func weeklyExpiry(
        items: [Item],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [WeeklyExpiryPoint] {
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let mondayOffset = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -mondayOffset, to: today) ?? today
        let active = items.filter { $0.status == .active }
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: monday) ?? monday
            let count = active.filter { item in
                guard let expiry = item.expiryDate else { return false }
                return calendar.isDate(expiry, inSameDayAs: date)
            }.count
            return WeeklyExpiryPoint(date: date, count: count)
        }
    }

    static func freshness(
        items: [Item],
        period: AnalyticsPeriod,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> FreshnessStatistic {
        let start = startDate(period: period, now: now, calendar: calendar)
        var result = FreshnessStatistic()
        for item in items where isResolved(item, after: start, calendar: calendar) {
            guard let resolved = item.resolvedDate, let expiry = item.expiryDate else { continue }
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: resolved),
                to: calendar.startOfDay(for: expiry)
            ).day ?? 0
            switch days {
            case ..<0: result.expiry += 1
            case 0...3: result.urgent += 1
            case 4...7: result.warning += 1
            default: result.fresh += 1
            }
        }
        return result
    }

    static func spoilage(
        items: [Item],
        period: AnalyticsPeriod,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [SpoilagePoint] {
        let start = startDate(period: period, now: now, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let resolved = items.filter { isResolved($0, after: start, calendar: calendar) }
        var points: [SpoilagePoint] = []
        var cursor = start
        while cursor <= today {
            let dayItems = resolved.filter { item in
                guard let resolvedDate = item.resolvedDate else { return false }
                return calendar.isDate(resolvedDate, inSameDayAs: cursor)
            }
            points.append(
                SpoilagePoint(
                    date: cursor,
                    waste: dayItems.filter { $0.status == .wasted }.count,
                    consumed: dayItems.filter { $0.status == .consumed }.count
                )
            )
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? today.addingTimeInterval(86_400)
        }
        return points
    }

    private static func startDate(period: AnalyticsPeriod, now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        let days = period == .week ? 6 : 29
        return calendar.date(byAdding: .day, value: -days, to: today) ?? today
    }

    private static func isResolved(_ item: Item, after start: Date, calendar: Calendar) -> Bool {
        guard item.status == .consumed || item.status == .wasted, let resolved = item.resolvedDate else {
            return false
        }
        return calendar.startOfDay(for: resolved) >= start
    }
}
