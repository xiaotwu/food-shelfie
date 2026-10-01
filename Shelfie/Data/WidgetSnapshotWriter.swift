import Foundation
import SwiftData
import WidgetKit

enum WidgetSnapshotWriter {
    static func refresh(context: ModelContext) {
        // A read failure must not replace the last valid snapshot with an empty shelf.
        guard let foods = try? context.fetch(FetchDescriptor<FoodItemRecord>()) else { return }
        let items = foods.map {
            AnalyticsEngine.Item(status: $0.status, expiryDate: $0.effectiveExpiryDate,
                                 resolvedDate: $0.resolvedDate, purchaseDate: $0.purchaseDate)
        }
        let overview = AnalyticsEngine.overview(items: items)
        let weekly = AnalyticsEngine.weeklyExpiry(items: items)
        // Persist all active dated foods so the widget can age dates without opening the app.
        let datedFoods = foods.filter { $0.status == .active }.compactMap { food -> WidgetFoodSnapshot? in
            guard let expiry = food.effectiveExpiryDate else { return nil }
            return WidgetFoodSnapshot(id: food.id, name: food.name, expiryDate: expiry,
                                      remainingDays: FreshnessRules.remainingDays(from: expiry) ?? 0, location: food.location)
        }.sorted {
            $0.expiryDate == $1.expiryDate ? $0.id.uuidString < $1.id.uuidString : $0.expiryDate < $1.expiryDate
        }
        let snapshot = WidgetSnapshot(expiredCount: overview.expired, expiringSoonCount: overview.expiring,
                                      weeklyCounts: weekly.map(\.count), foodsThisWeek: datedFoods, updatedAt: .now)
        do {
            let data = try JSONEncoder().encode(snapshot)
            if let old = load(), old.foodsThisWeek == snapshot.foodsThisWeek,
               old.expiredCount == snapshot.expiredCount, old.expiringSoonCount == snapshot.expiringSoonCount,
               old.weeklyCounts == snapshot.weeklyCounts { return }
            try data.write(to: AppGroup.snapshotURL, options: .atomic)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Preserve the previous valid file and timeline on write failure.
        }
    }

    static func load() -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: AppGroup.snapshotURL) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
