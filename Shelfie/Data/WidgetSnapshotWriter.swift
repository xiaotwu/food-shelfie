import Foundation
import SwiftData
import WidgetKit

enum WidgetSnapshotWriter {
    static func refresh(context: ModelContext) {
        let foods = (try? context.fetch(FetchDescriptor<FoodItemRecord>())) ?? []
        let items = foods.map {
            AnalyticsEngine.Item(
                status: $0.status,
                expiryDate: $0.expiryDate,
                resolvedDate: $0.resolvedDate,
                purchaseDate: $0.purchaseDate
            )
        }
        let overview = AnalyticsEngine.overview(items: items)
        let weekly = AnalyticsEngine.weeklyExpiry(items: items)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 7, to: today) ?? today
        let thisWeek = foods
            .filter { $0.status == .active }
            .compactMap { food -> WidgetFoodSnapshot? in
                guard let expiry = food.expiryDate else { return nil }
                let day = calendar.startOfDay(for: expiry)
                guard day >= today && day < end else { return nil }
                return WidgetFoodSnapshot(
                    id: food.id,
                    name: food.name,
                    expiryDate: expiry,
                    remainingDays: food.remainingDays ?? 0,
                    location: food.location
                )
            }
            .sorted { $0.expiryDate < $1.expiryDate }

        let snapshot = WidgetSnapshot(
            expiredCount: overview.expired,
            expiringSoonCount: overview.expiring,
            weeklyCounts: weekly.map(\.count),
            foodsThisWeek: thisWeek,
            updatedAt: .now
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: AppGroup.snapshotURL, options: .atomic)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func load() -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: AppGroup.snapshotURL) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
