import Foundation
import SwiftData
import UIKit

enum BackupService {
    static let maximumFileBytes = 100 * 1024 * 1024
    static func exportPayload(context: ModelContext) throws -> BackupPayload {
        let categories = try context.fetch(FetchDescriptor<CategoryRecord>())
        let locations = try context.fetch(FetchDescriptor<LocationRecord>())
        let foods = try context.fetch(FetchDescriptor<FoodItemRecord>())
        let history = try context.fetch(FetchDescriptor<SearchHistoryRecord>())
        let shopping = try context.fetch(FetchDescriptor<ShoppingItemRecord>())
        let payload = BackupPayload(
            version: 5,
            exportedAt: .now,
            categories: categories.map {
                BackupCategory(id: $0.id, name: $0.name, details: $0.details)
            },
            locations: locations.map {
                BackupLocation(
                    id: $0.id,
                    name: $0.name,
                    builtInKey: $0.builtInKey,
                    symbolName: $0.symbolName,
                    sortOrder: $0.sortOrder
                )
            },
            foods: try foods.map { food in
                let imageData: Data?
                if let stored = food.photoData {
                    imageData = stored
                } else if let fileName = food.imageFileName {
                    do { imageData = try Data(contentsOf: AppGroup.imagesDirectory.appendingPathComponent(fileName)) }
                    catch { throw BackupError.imageReadFailed }
                } else {
                    imageData = nil
                }
                return BackupFood(
                    id: food.id,
                    name: food.name,
                    categoryId: food.categoryId,
                    location: food.location,
                    locationId: food.locationId,
                    locationName: food.resolvedLocation(in: locations)?.name,
                    purchaseDate: food.purchaseDate,
                    expiryDate: food.expiryDate,
                    imageFileName: food.imageFileName,
                    imageBase64: imageData?.base64EncodedString(),
                    notes: food.notes,
                    owner: food.owner,
                    status: food.status,
                    resolvedDate: food.resolvedDate,
                    quantity: food.quantity,
                    unit: food.unit,
                    openedDate: food.openedDate,
                    openedShelfLifeDays: food.openedShelfLifeDays,
                    lowStockThreshold: food.lowStockThreshold
                )
            },
            searchHistory: history.map { BackupSearch(query: $0.query, timestamp: $0.timestamp) },
            shoppingItems: shopping.map { BackupShoppingItem(id: $0.id, name: $0.name, quantity: $0.quantity, unit: $0.unit, isCompleted: $0.isCompleted, createdAt: $0.createdAt, inventoryFoodID: $0.inventoryFoodID) }
        )
        // Never offer a backup that this same app would reject on restore.
        try validate(payload)
        return payload
    }

    static func encodedData(from payload: BackupPayload, sizeLimit: Int = 100 * 1024 * 1024) throws -> Data {
        try validate(payload)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        guard data.count <= max(0, min(sizeLimit, maximumFileBytes)) else { throw BackupError.tooLarge }
        return data
    }

    static func writeJSON(from payload: BackupPayload) throws -> URL {
        let data = try encodedData(from: payload)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shelfie-backup-\(UUID().uuidString).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func importJSON(from url: URL, context: ModelContext) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= maximumFileBytes else { throw BackupError.tooLarge }
        let data = try Data(contentsOf: url)
        guard data.count <= maximumFileBytes else { throw BackupError.tooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: data)
        try replaceAll(with: payload, context: context)
    }

    enum BackupError: LocalizedError, Equatable {
        case unsupportedVersion, duplicateIDs, invalidImage, invalidQuantity, invalidReference, invalidOpening, tooLarge, imageWriteFailed, imageReadFailed
        var errorDescription: String? {
            switch self {
            case .imageReadFailed: "A food photo could not be read. No incomplete backup was created."
            case .invalidReference: "This backup refers to a missing category or location. Your inventory was not changed."
            case .invalidOpening: "This backup contains invalid opening dates or stock thresholds. Your inventory was not changed."
            case .tooLarge: "This backup exceeds the supported size. Your inventory was not changed."
            case .imageWriteFailed: "A backup photo could not be written. Your inventory was not changed."
            case .unsupportedVersion: "Unsupported backup version. Your inventory was not changed."
            case .duplicateIDs: "This backup contains duplicate records. Your inventory was not changed."
            case .invalidQuantity: "This backup contains an invalid quantity. Your inventory was not changed."
            case .invalidImage: "This backup contains an invalid photo. Your inventory was not changed."
            }
        }

        func message(locale: Locale) -> String {
            let key: String
            switch self {
            case .unsupportedVersion: key = "backup.error.unsupportedVersion"
            case .duplicateIDs: key = "backup.error.duplicateIDs"
            case .invalidImage: key = "backup.error.invalidImage"
            case .invalidQuantity: key = "backup.error.invalidQuantity"
            case .invalidReference: key = "backup.error.invalidReference"
            case .invalidOpening: key = "backup.error.invalidOpening"
            case .tooLarge: key = "backup.error.tooLarge"
            case .imageWriteFailed: key = "backup.error.imageWriteFailed"
            case .imageReadFailed: key = "backup.error.imageReadFailed"
            }
            return locale.text(key)
        }
    }

    static func errorMessage(_ error: Error, locale: Locale) -> String {
        if let error = error as? BackupError { return error.message(locale: locale) }
        if error is DecodingError { return locale.text("backup.error.invalidFile") }
        return error.localizedDescription
    }

    static func validate(_ payload: BackupPayload) throws {
        guard (1...5).contains(payload.version) else { throw BackupError.unsupportedVersion }
        guard Set(payload.foods.map(\.id)).count == payload.foods.count,
              Set(payload.categories.map(\.id)).count == payload.categories.count,
              Set((payload.locations ?? []).map(\.id)).count == (payload.locations ?? []).count else {
            throw BackupError.duplicateIDs
        }
        let shopping = payload.shoppingItems ?? []
        guard payload.foods.count <= 10_000, shopping.count <= 10_000 else { throw BackupError.tooLarge }
        guard Set(shopping.map(\.id)).count == shopping.count else { throw BackupError.duplicateIDs }
        for item in shopping {
            guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, FoodQuantity.isValid(item.quantity) else { throw BackupError.invalidQuantity }
        }
        let categoryIDs = Set(payload.categories.map(\.id))
        let locationIDs = Set((payload.locations ?? []).map(\.id))
        var totalImageBytes = 0
        for food in payload.foods {
            if let id = food.categoryId, !categoryIDs.contains(id) { throw BackupError.invalidReference }
            if let id = food.locationId, payload.locations != nil, !locationIDs.contains(id) { throw BackupError.invalidReference }
            if let days = food.openedShelfLifeDays, !(1...365).contains(days) { throw BackupError.invalidOpening }
            if let date = food.openedDate, Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: food.purchaseDate) || Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: .now) || food.openedShelfLifeDays == nil { throw BackupError.invalidOpening }
            if let threshold = food.lowStockThreshold, threshold != 0 && !FoodQuantity.isValid(threshold) { throw BackupError.invalidOpening }
            let quantity = food.quantity ?? 1
            guard FoodQuantity.isValid(quantity) || (quantity == 0 && food.status != .active) else {
                throw BackupError.invalidQuantity
            }
            if payload.version >= 3 && (food.quantity == nil || food.unit == nil) {
                throw BackupError.invalidQuantity
            }
            if let image = food.imageBase64 {
                guard image.utf8.count <= 14 * 1024 * 1024 else { throw BackupError.tooLarge }
                guard let data = Data(base64Encoded: image), data.count <= 10 * 1024 * 1024, UIImage(data: data) != nil else {
                    throw BackupError.invalidImage
                }
                totalImageBytes += data.count
                guard totalImageBytes <= 50 * 1024 * 1024 else { throw BackupError.tooLarge }
            }
        }
    }

    static func replaceAll(with payload: BackupPayload, context: ModelContext,
                           commit: (ModelContext) throws -> Void = { try $0.save() },
                           writeImage: (UIImage) throws -> String = { image in
                               guard let name = ImageStore.save(image: image) else { throw BackupError.imageWriteFailed }
                               return name
                           }) throws {
        try validate(payload)
        // Use an isolated context so an import failure cannot roll back unrelated edits.
        try context.save()
        let originalContext = context
        let context = ModelContext(context.container)
        context.autosaveEnabled = false
        let oldFoods = try context.fetch(FetchDescriptor<FoodItemRecord>())
        let oldImages = Set(oldFoods.compactMap(\.imageFileName))
        var newImages: [String] = []
        var committed = false
        defer {
            if !committed {
                context.rollback()
                for fileName in newImages { ImageStore.delete(fileName: fileName) }
            }
        }
        for food in oldFoods { context.delete(food) }
        for item in try context.fetch(FetchDescriptor<CategoryRecord>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<LocationRecord>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<SearchHistoryRecord>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<ShoppingItemRecord>()) { context.delete(item) }
        for category in payload.categories {
            context.insert(CategoryRecord(id: category.id, name: category.name, details: category.details))
        }
        if let locations = payload.locations, !locations.isEmpty {
            for location in locations {
                context.insert(
                    LocationRecord(
                        id: location.id,
                        name: location.name,
                        builtInKey: location.builtInKey,
                        symbolName: location.symbolName,
                        sortOrder: location.sortOrder
                    )
                )
            }
        } else {
            try SeedData.ensureDefaultLocations(context: context)
        }
        let storedLocations = try context.fetch(FetchDescriptor<LocationRecord>())
        for food in payload.foods {
            var fileName: String?
            var photoData: Data?
            if let base64 = food.imageBase64, let data = Data(base64Encoded: base64), let image = UIImage(data: data) {
                fileName = try writeImage(image)
                if let fileName { newImages.append(fileName) }
                photoData = data
            }
            let record = FoodItemRecord(
                id: food.id,
                name: food.name,
                categoryId: food.categoryId,
                locationId: food.locationId,
                location: food.location,
                purchaseDate: food.purchaseDate,
                expiryDate: food.expiryDate,
                imageFileName: fileName,
                photoData: photoData,
                notes: food.notes,
                owner: food.owner,
                quantity: food.quantity ?? 1,
                unit: food.unit ?? .piece,
                status: food.status,
                resolvedDate: food.resolvedDate
            )
            record.openedDate = food.openedDate
            record.openedShelfLifeDays = food.openedShelfLifeDays
            record.lowStockThreshold = food.lowStockThreshold
            if record.locationId == nil {
                record.locationId = storedLocations.first(where: { $0.builtInKey == food.location.rawValue })?.id
            }
            context.insert(record)
        }
        for item in payload.searchHistory {
            context.insert(SearchHistoryRecord(query: item.query, timestamp: item.timestamp))
        }
        for item in payload.shoppingItems ?? [] {
            context.insert(ShoppingItemRecord(id: item.id, name: item.name, quantity: item.quantity, unit: item.unit, isCompleted: item.isCompleted, createdAt: item.createdAt, inventoryFoodID: item.inventoryFoodID))
        }
        try SeedData.ensureDefaultCategories(context: context)
        try SeedData.ensureDefaultLocations(context: context)
        try SeedData.migrateFoodLocations(context: context)
        try commit(context)
        committed = true
        for fileName in oldImages { ImageStore.delete(fileName: fileName) }
        WidgetSnapshotWriter.refresh(context: originalContext)
    }

    static func deleteAll(context originalContext: ModelContext) throws {
        try originalContext.save()
        let context = ModelContext(originalContext.container)
        context.autosaveEnabled = false
        do {
            let oldFoods = try context.fetch(FetchDescriptor<FoodItemRecord>())
            let oldImages = Set(oldFoods.compactMap(\.imageFileName))
            for food in oldFoods { context.delete(food) }
            for item in try context.fetch(FetchDescriptor<CategoryRecord>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<LocationRecord>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<SearchHistoryRecord>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<ShoppingItemRecord>()) { context.delete(item) }
            // Seed once the deletions have been registered, in the same transaction.
            try SeedData.ensureDefaultCategories(context: context)
            try SeedData.ensureDefaultLocations(context: context)
            try context.save()
            for fileName in oldImages { ImageStore.delete(fileName: fileName) }
            WidgetSnapshotWriter.refresh(context: originalContext)
        } catch {
            context.rollback()
            throw error
        }
    }
}
