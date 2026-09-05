import Foundation
import SwiftData

enum SeedData {
    static func bootstrap(context: ModelContext) {
        ensureDefaultCategories(context: context)
        ensureDefaultLocations(context: context)
        migrateFoodLocations(context: context)
        ensureSampleFoods(context: context)
        try? context.save()
    }

    static func ensureSampleFoods(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<FoodItemRecord>())) ?? []
        guard existing.isEmpty else { return }

        let categories = (try? context.fetch(FetchDescriptor<CategoryRecord>())) ?? []
        let locations = (try? context.fetch(FetchDescriptor<LocationRecord>())) ?? []

        func categoryId(named name: String) -> UUID? {
            categories.first(where: { $0.name.localizedCaseInsensitiveContains(name) })?.id
        }

        func locationInfo(for key: String) -> (UUID?, StorageLocation) {
            let loc = locations.first(where: { $0.builtInKey == key })
            let fallback: StorageLocation = {
                switch key {
                case "fridge": return .fridge
                case "freezer": return .freezer
                case "pantry": return .pantry
                default: return .other
                }
            }()
            return (loc?.id, fallback)
        }

        let now = Date()
        let cal = Calendar.current

        let samples: [(name: String, cat: String, locKey: String, buyDays: Int, expDays: Int, owner: String, notes: String)] = [
            ("Whole Milk", "Dairy", "fridge", -2, 2, "Alice", "Organic whole milk"),
            ("Greek Yogurt", "Dairy", "fridge", -3, 6, "Bob", "Unsweetened high protein"),
            ("Fresh Strawberries", "Fruit", "fridge", -1, 1, "Alice", "Sweet farm fresh"),
            ("Ribeye Steak", "Meat", "freezer", -5, 25, "Alice", "Grass-fed USDA prime"),
            ("Wild Salmon Fillet", "Seafood", "freezer", -4, 18, "Charlie", "Alaskan wild caught"),
            ("Sourdough Bread", "Other", "pantry", -7, -1, "Charlie", "Artisan sourdough loaf"),
            ("Dark Chocolate", "Other", "pantry", -10, 50, "Bob", "72% single origin cacao")
        ]

        for s in samples {
            let (locId, fallbackLoc) = locationInfo(for: s.locKey)
            let buyDate = cal.date(byAdding: .day, value: s.buyDays, to: now) ?? now
            let expDate = cal.date(byAdding: .day, value: s.expDays, to: now)
            let item = FoodItemRecord(
                name: s.name,
                categoryId: categoryId(named: s.cat),
                locationId: locId,
                location: fallbackLoc,
                purchaseDate: buyDate,
                expiryDate: expDate,
                notes: s.notes,
                owner: s.owner
            )
            context.insert(item)
        }
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
