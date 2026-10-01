import Foundation
import SwiftData

@Model
final class CategoryRecord {
    var id: UUID = UUID()
    var name: String = ""
    var details: String = ""
    var createdAt: Date = Date.now

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
    var id: UUID = UUID()
    var name: String = ""
    var builtInKey: String?
    var symbolName: String = "shippingbox"
    var sortOrder: Int = 100
    var createdAt: Date = Date.now

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
    var id: UUID = UUID()
    var name: String = ""
    var normalizedName: String = ""
    var categoryId: UUID?
    var locationId: UUID?
    var locationRaw: String = "fridge"
    var purchaseDate: Date = Date.now
    var expiryDate: Date?
    var openedDate: Date?
    var openedShelfLifeDays: Int?
    var lowStockThreshold: Double?
    var imageFileName: String?
    @Attribute(.externalStorage) var photoData: Data?
    var notes: String = ""
    var owner: String?
    var quantity: Double = 1
    var unitRaw: String = "piece"
    var statusRaw: String = "active"
    var resolvedDate: Date?
    var createdAt: Date = Date.now

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
        owner: String? = nil,
        quantity: Double = 1,
        unit: FoodUnit = .piece,
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
        self.owner = owner
        self.quantity = quantity
        self.unitRaw = unit.rawValue
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

    var unit: FoodUnit {
        get { FoodUnit(rawValue: unitRaw) ?? .piece }
        set { unitRaw = newValue.rawValue }
    }

    func quantityLabel(locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.maximumFractionDigits = 3
        return "\(formatter.string(from: NSNumber(value: quantity)) ?? String(quantity)) \(unit.title(locale: locale))"
    }

    /// Changes the batch in memory; the caller must commit before showing success.
    func consume(amount: Double, now: Date = .now) throws {
        guard status == .active, FoodQuantity.isValid(amount),
              FoodQuantity.isValid(quantity), amount <= quantity else {
            throw FoodQuantity.Error.invalidAmount
        }
        quantity = max(0, ((quantity - amount) * 1_000).rounded() / 1_000)
        if quantity < 0.000000001 {
            quantity = 0
            status = .consumed
            resolvedDate = now
        }
    }

    var openedExpiryDate: Date? {
        guard let openedDate, let days = openedShelfLifeDays, days > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: days, to: openedDate)
    }

    var effectiveExpiryDate: Date? {
        [expiryDate, openedExpiryDate].compactMap { $0 }.min()
    }

    var remainingDays: Int? {
        FreshnessRules.remainingDays(from: effectiveExpiryDate)
    }

    var freshness: Freshness {
        FreshnessRules.freshness(expiry: effectiveExpiryDate)
    }

    var usedProgress: Double {
        FreshnessRules.usedProgress(purchase: openedDate ?? purchaseDate, expiry: effectiveExpiryDate)
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
    var query: String = ""
    var timestamp: Date = Date.now

    init(query: String, timestamp: Date = .now) {
        self.query = query
        self.timestamp = timestamp
    }
}

@Model
final class ShoppingItemRecord {
    var id: UUID = UUID()
    var name: String = ""
    var quantity: Double = 1
    var unitRaw: String = "piece"
    var isCompleted: Bool = false
    var createdAt: Date = Date.now
    /// Purchase-cycle marker; retained even if the corresponding food is later deleted.
    var inventoryFoodID: UUID? = nil

    init(id: UUID = UUID(), name: String, quantity: Double = 1, unit: FoodUnit = .piece,
         isCompleted: Bool = false, createdAt: Date = .now, inventoryFoodID: UUID? = nil) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unitRaw = unit.rawValue
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.inventoryFoodID = inventoryFoodID
    }
    var unit: FoodUnit {
        get { FoodUnit(rawValue: unitRaw) ?? .piece }
        set { unitRaw = newValue.rawValue }
    }
    func quantityLabel(locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.maximumFractionDigits = 3
        return "\(formatter.string(from: NSNumber(value: quantity)) ?? String(quantity)) \(unit.title(locale: locale))"
    }
}
