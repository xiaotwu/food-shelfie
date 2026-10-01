import Foundation
import SwiftData

enum SeedData {
    static func categoryID(_ kind: DefaultFoodCategory) -> UUID {
        let index = DefaultFoodCategory.allCases.firstIndex(of: kind)! + 1
        return UUID(uuidString: String(format: "5E1F0000-0000-4000-8000-%012d", index))!
    }

    static func locationID(_ kind: StorageLocation) -> UUID {
        let index = StorageLocation.allCases.firstIndex(of: kind)! + 1
        return UUID(uuidString: String(format: "5E1F0001-0000-4000-8000-%012d", index))!
    }

    static func bootstrap(context original: ModelContext) throws {
        let context = ModelContext(original.container)
        context.autosaveEnabled = false
        do {
        try ensureDefaultCategories(context: context)
        try ensureDefaultLocations(context: context)
        try migrateFoodLocations(context: context)
        if context.hasChanges { try context.save() }
        } catch { context.rollback(); throw error }
    }

    static func ensureDefaultCategories(context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<CategoryRecord>())
        let foods = try context.fetch(FetchDescriptor<FoodItemRecord>())
        for kind in DefaultFoodCategory.allCases {
            let stableID = categoryID(kind)
            let matches = existing.filter { !$0.isDeleted && ($0.id == stableID || DefaultFoodCategory.matching($0.name) == kind) }
                .sorted { $0.createdAt < $1.createdAt }
            guard let primary = matches.first(where: { $0.id == stableID }) ?? matches.first else {
                context.insert(CategoryRecord(id: stableID, name: kind.storedName))
                continue
            }
            let oldIDs = Set(matches.map(\.id))
            if primary.id != stableID { primary.id = stableID }
            for food in foods where food.categoryId.map({ oldIDs.contains($0) }) == true {
                if food.categoryId != stableID { food.categoryId = stableID }
            }
            for duplicate in matches where duplicate !== primary { context.delete(duplicate) }
        }
    }

    static func ensureDefaultLocations(context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<LocationRecord>())
        let foods = try context.fetch(FetchDescriptor<FoodItemRecord>())
        for (index, kind) in StorageLocation.allCases.enumerated() {
            let stableID = locationID(kind)
            let matches = existing.filter { !$0.isDeleted && ($0.id == stableID || $0.builtInKey == kind.rawValue) }
                .sorted { $0.createdAt < $1.createdAt }
            guard let primary = matches.first(where: { $0.id == stableID }) ?? matches.first else {
                context.insert(LocationRecord(id: stableID, name: kind.storedName,
                    builtInKey: kind.rawValue, symbolName: kind.symbolName, sortOrder: index))
                continue
            }
            let oldIDs = Set(matches.map(\.id))
            if primary.id != stableID { primary.id = stableID }
            for food in foods where food.locationId.map({ oldIDs.contains($0) }) == true {
                if food.locationId != stableID { food.locationId = stableID }
            }
            for duplicate in matches where duplicate !== primary { context.delete(duplicate) }
        }
    }

    static func migrateFoodLocations(context: ModelContext) throws {
        let locations = try context.fetch(FetchDescriptor<LocationRecord>())
        let foods = try context.fetch(FetchDescriptor<FoodItemRecord>())
        for food in foods where food.locationId == nil {
            if let match = food.resolvedLocation(in: locations) { food.locationId = match.id }
        }
    }

    static func pruneResolved(context original: ModelContext, afterDays: Int) throws {
        guard afterDays > 0 else { return }
        let context = ModelContext(original.container)
        context.autosaveEnabled = false
        let cutoff = Calendar.current.date(byAdding: .day, value: -afterDays, to: .now) ?? .now
        let foods = try context.fetch(FetchDescriptor<FoodItemRecord>())
        let targets = foods.filter { $0.status != .active && ($0.resolvedDate ?? .distantFuture) < cutoff }
        let images = targets.compactMap(\.imageFileName)
        for food in targets { context.delete(food) }
        do {
            if context.hasChanges { try context.save() }
            for fileName in images { ImageStore.delete(fileName: fileName) }
        } catch { context.rollback(); throw error }
    }
}
