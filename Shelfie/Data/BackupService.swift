import Foundation
import SwiftData
import UIKit

enum BackupService {
    static func exportPayload(context: ModelContext) throws -> BackupPayload {
        let categories = try context.fetch(FetchDescriptor<CategoryRecord>())
        let locations = try context.fetch(FetchDescriptor<LocationRecord>())
        let foods = try context.fetch(FetchDescriptor<FoodItemRecord>())
        let history = try context.fetch(FetchDescriptor<SearchHistoryRecord>())
        return BackupPayload(
            version: 2,
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
            foods: foods.map { food in
                let imageData = food.photoData ?? food.imageFileName.flatMap {
                    try? Data(contentsOf: AppGroup.imagesDirectory.appendingPathComponent($0))
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
                    status: food.status,
                    resolvedDate: food.resolvedDate
                )
            },
            searchHistory: history.map { BackupSearch(query: $0.query, timestamp: $0.timestamp) }
        )
    }

    static func writeJSON(from payload: BackupPayload) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shelfie-backup-\(Int(Date().timeIntervalSince1970)).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func importJSON(from url: URL, context: ModelContext) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: data)
        try replaceAll(with: payload, context: context)
    }

    static func replaceAll(with payload: BackupPayload, context: ModelContext) throws {
        try deleteAll(context: context)
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
            SeedData.ensureDefaultLocations(context: context)
        }
        let storedLocations = (try? context.fetch(FetchDescriptor<LocationRecord>())) ?? []
        for food in payload.foods {
            var fileName = food.imageFileName
            var photoData: Data?
            if let base64 = food.imageBase64, let data = Data(base64Encoded: base64), let image = UIImage(data: data) {
                fileName = ImageStore.save(image: image) ?? fileName
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
                status: food.status,
                resolvedDate: food.resolvedDate
            )
            if record.locationId == nil {
                record.locationId = storedLocations.first(where: { $0.builtInKey == food.location.rawValue })?.id
            }
            context.insert(record)
        }
        for item in payload.searchHistory {
            context.insert(SearchHistoryRecord(query: item.query, timestamp: item.timestamp))
        }
        SeedData.bootstrap(context: context)
        try context.save()
        WidgetSnapshotWriter.refresh(context: context)
    }

    static func deleteAll(context: ModelContext) throws {
        try context.delete(model: FoodItemRecord.self)
        try context.delete(model: CategoryRecord.self)
        try context.delete(model: LocationRecord.self)
        try context.delete(model: SearchHistoryRecord.self)
        if let contents = try? FileManager.default.contentsOfDirectory(at: AppGroup.imagesDirectory, includingPropertiesForKeys: nil) {
            for url in contents {
                try? FileManager.default.removeItem(at: url)
            }
        }
        try context.save()
        WidgetSnapshotWriter.refresh(context: context)
    }
}
