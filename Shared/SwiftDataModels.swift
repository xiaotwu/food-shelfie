import Foundation
import SwiftData

@Model
final class CategoryRecord {
    var id: UUID
    var name: String
    var details: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        details: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.details = details
        self.createdAt = createdAt
    }
}

@Model
final class LocationRecord {
    var id: UUID
    var name: String
    var builtInKey: String?
    var symbolName: String
    var sortOrder: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        builtInKey: String? = nil,
        symbolName: String = "shippingbox",
        sortOrder: Int = 100,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.builtInKey = builtInKey
        self.symbolName = symbolName
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    func displayName(locale: Locale) -> String {
        if let builtInKey, let kind = StorageLocation(rawValue: builtInKey) {
            return kind.title(locale: locale)
        }
        return name
    }
}

@Model
final class FoodItemRecord {
    var id: UUID
    var name: String
    var normalizedName: String
    var categoryId: UUID?
    var locationId: UUID?
    var locationRaw: String
    var purchaseDate: Date
    var expiryDate: Date?
    var imageFileName: String?
    @Attribute(.externalStorage) var photoData: Data?
    var notes: String
    var statusRaw: String
    var resolvedDate: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        categoryId: UUID? = nil,
        locationId: UUID? = nil,
        location: StorageLocation = .fridge,
        purchaseDate: Date = .now,
        expiryDate: Date? = nil,
        imageFileName: String? = nil,
        photoData: Data? = nil,
        notes: String = "",
        status: FoodStatus = .active,
        resolvedDate: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.normalizedName = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        self.categoryId = categoryId
        self.locationId = locationId
        self.locationRaw = location.rawValue
        self.purchaseDate = purchaseDate
        self.expiryDate = expiryDate
        self.imageFileName = imageFileName
        self.photoData = photoData
        self.notes = notes
        self.statusRaw = status.rawValue
        self.resolvedDate = resolvedDate
        self.createdAt = createdAt
    }

    var location: StorageLocation {
        get { StorageLocation(rawValue: locationRaw) ?? .other }
        set { locationRaw = newValue.rawValue }
    }

    var status: FoodStatus {
        get { FoodStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var remainingDays: Int? {
        FreshnessRules.remainingDays(from: expiryDate)
    }

    var freshness: Freshness {
        FreshnessRules.freshness(expiry: expiryDate)
    }

    var usedProgress: Double {
        FreshnessRules.usedProgress(purchase: purchaseDate, expiry: expiryDate)
    }

    var imageURL: URL? {
        guard let imageFileName else { return nil }
        return AppGroup.imagesDirectory.appendingPathComponent(imageFileName)
    }

    func resolvedLocation(in locations: [LocationRecord]) -> LocationRecord? {
        if let locationId, let match = locations.first(where: { $0.id == locationId }) {
            return match
        }
        if let match = locations.first(where: { $0.builtInKey == locationRaw }) {
            return match
        }
        return locations.first(where: { $0.name.caseInsensitiveCompare(locationRaw) == .orderedSame })
    }

    func apply(locationRecord: LocationRecord) {
        locationId = locationRecord.id
        if let key = locationRecord.builtInKey, let kind = StorageLocation(rawValue: key) {
            location = kind
        } else {
            locationRaw = locationRecord.name
            locationId = locationRecord.id
        }
    }

    func refreshNormalizedName() {
        normalizedName = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}

@Model
final class SearchHistoryRecord {
    var query: String
    var timestamp: Date

    init(query: String, timestamp: Date = .now) {
        self.query = query
        self.timestamp = timestamp
    }
}
