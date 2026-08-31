import Foundation
import SwiftData

enum SeedData {
    static func bootstrap(context: ModelContext) {
        ensureDefaultCategories(context: context)
        ensureDefaultLocations(context: context)
        migrateFoodLocations(context: context)
        try? context.save()
    }

    static func ensureDefaultCategories(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<CategoryRecord>())) ?? []
        guard existing.isEmpty else { return }
        for kind in DefaultFoodCategory.allCases {
            context.insert(CategoryRecord(name: kind.storedName))
        }
    }

    static func ensureDefaultLocations(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<LocationRecord>())) ?? []
        for (index, kind) in StorageLocation.allCases.enumerated() {
            if existing.contains(where: { $0.builtInKey == kind.rawValue }) { continue }
            context.insert(
                LocationRecord(
                    name: kind.storedName,
                    builtInKey: kind.rawValue,
                    symbolName: kind.symbolName,
                    sortOrder: index
                )
            )
        }
    }

    static func migrateFoodLocations(context: ModelContext) {
        let locations = (try? context.fetch(FetchDescriptor<LocationRecord>())) ?? []
        let foods = (try? context.fetch(FetchDescriptor<FoodItemRecord>())) ?? []
        for food in foods where food.locationId == nil {
            if let match = food.resolvedLocation(in: locations) {
                food.locationId = match.id
            }
        }
    }

    static func pruneResolved(context: ModelContext, afterDays: Int) {
        guard afterDays > 0 else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -afterDays, to: .now) ?? .now
        let foods = (try? context.fetch(FetchDescriptor<FoodItemRecord>())) ?? []
        for food in foods where food.status != .active {
            if let resolved = food.resolvedDate, resolved < cutoff {
                ImageStore.delete(fileName: food.imageFileName)
                context.delete(food)
            }
        }
        try? context.save()
    }
}
