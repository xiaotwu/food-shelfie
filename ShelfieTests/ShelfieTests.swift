import XCTest
import SwiftData
@testable import Shelfie

final class FreshnessRulesTests: XCTestCase {
    let calendar = Calendar(identifier: .gregorian)

    func testRemainingDaysAndBands() {
        let now = date(2026, 8, 30)
        XCTAssertEqual(FreshnessRules.remainingDays(from: date(2026, 8, 29), now: now, calendar: calendar), -1)
        XCTAssertEqual(FreshnessRules.freshness(expiry: date(2026, 8, 29), now: now, calendar: calendar), .expired)
        XCTAssertEqual(FreshnessRules.freshness(expiry: date(2026, 8, 30), now: now, calendar: calendar), .urgent)
        XCTAssertEqual(FreshnessRules.freshness(expiry: date(2026, 9, 2), now: now, calendar: calendar), .urgent)
        XCTAssertEqual(FreshnessRules.freshness(expiry: date(2026, 9, 6), now: now, calendar: calendar), .warning)
        XCTAssertEqual(FreshnessRules.freshness(expiry: date(2026, 10, 1), now: now, calendar: calendar), .fresh)
    }

    func testUsedProgress() {
        let purchase = date(2026, 8, 20)
        let expiry = date(2026, 8, 30)
        XCTAssertEqual(FreshnessRules.usedProgress(purchase: purchase, expiry: expiry, now: purchase), 0, accuracy: 0.001)
        XCTAssertEqual(FreshnessRules.usedProgress(purchase: purchase, expiry: expiry, now: expiry), 1, accuracy: 0.001)
        let mid = date(2026, 8, 25)
        XCTAssertEqual(FreshnessRules.usedProgress(purchase: purchase, expiry: expiry, now: mid), 0.5, accuracy: 0.05)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }
}

final class FoodValidatorTests: XCTestCase {
    func testNameRules() {
        XCTAssertEqual(FoodValidator.validateName(""), .emptyField)
        XCTAssertEqual(FoodValidator.validateName("A"), .textTooShort)
        XCTAssertEqual(FoodValidator.validateName("Milk"), .success)
    }

    func testExpiryRules() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: date(2026, 8, 30))
        XCTAssertEqual(FoodValidator.validateExpiryDate(nil, purchaseDate: today, now: today, calendar: calendar), .emptyField)
        XCTAssertEqual(
            FoodValidator.validateExpiryDate(date(2026, 1, 1), purchaseDate: date(2023, 8, 30), now: today, calendar: calendar),
            .success
        )
        XCTAssertEqual(
            FoodValidator.validateExpiryDate(date(2026, 8, 20), purchaseDate: date(2026, 8, 25), now: date(2026, 8, 10), calendar: calendar),
            .invalidDateRange
        )
        XCTAssertEqual(
            FoodValidator.validatePurchaseDate(date(2026, 9, 1), now: today, calendar: calendar),
            .futureDate
        )
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: y, month: m, day: d))!
    }
}

final class DateParserTests: XCTestCase {
    func testExpiryKeywordAndISODate() {
        let scan = DateParser.parseFoodDates(from: "EXP 2026-09-12 MFG 2026-08-01")
        XCTAssertEqual(day(scan.expiryDate), "2026-09-12")
        XCTAssertEqual(day(scan.productionDate), "2026-08-01")
    }

    func testBestBeforeEuropean() {
        let scan = DateParser.parseFoodDates(from: "Best before 12/09/2026")
        XCTAssertNil(scan.expiryDate)
        XCTAssertEqual(Set(scan.expiryCandidates.map { day($0) }), Set(["2026-09-12", "2026-12-09"]))
        XCTAssertTrue(scan.requiresConfirmation)
    }

    func testSingleFutureDateBecomesExpiry() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 30))!
        let scan = DateParser.parseFoodDates(from: "Packed goods 2026-10-04", now: now)
        XCTAssertNil(scan.expiryDate)
        XCTAssertEqual(day(scan.productionDate), "2026-10-04")
    }

    private func day(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

final class AnalyticsEngineTests: XCTestCase {
    let calendar = Calendar(identifier: .gregorian)

    func testOverviewCountsExpiredAndThisWeek() {
        let now = date(2026, 8, 30) // Sunday
        let items: [AnalyticsEngine.Item] = [
            .init(status: .active, expiryDate: date(2026, 8, 29), resolvedDate: nil, purchaseDate: date(2026, 8, 1)),
            .init(status: .active, expiryDate: date(2026, 8, 30), resolvedDate: nil, purchaseDate: date(2026, 8, 1)),
            .init(status: .consumed, expiryDate: date(2026, 8, 20), resolvedDate: date(2026, 8, 18), purchaseDate: date(2026, 8, 1))
        ]
        let overview = AnalyticsEngine.overview(items: items, now: now, calendar: calendar)
        XCTAssertEqual(overview.expired, 1)
        XCTAssertEqual(overview.expiring, 1)
    }

    func testFreshnessOfResolvedItems() {
        let now = date(2026, 8, 30)
        let items: [AnalyticsEngine.Item] = [
            .init(status: .consumed, expiryDate: date(2026, 9, 10), resolvedDate: date(2026, 8, 20), purchaseDate: date(2026, 8, 1)),
            .init(status: .wasted, expiryDate: date(2026, 8, 10), resolvedDate: date(2026, 8, 20), purchaseDate: date(2026, 8, 1))
        ]
        let freshness = AnalyticsEngine.freshness(items: items, period: .month, now: now, calendar: calendar)
        XCTAssertEqual(freshness.fresh, 1)
        XCTAssertEqual(freshness.expiry, 1)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }
}

final class ICloudSyncSettingsTests: XCTestCase {
    func testSyncDefaultsOffWhenUnset() {
        let defaults = isolatedDefaults()
        XCTAssertFalse(SettingsStore.iCloudSyncEnabled(in: defaults))
        XCTAssertFalse(SettingsStore(defaults: defaults).iCloudSyncEnabled)
    }

    func testSyncPersistsOnAndOff() {
        let defaults = isolatedDefaults()
        let store = SettingsStore(defaults: defaults)
        store.iCloudSyncEnabled = true
        store.persist()
        XCTAssertTrue(SettingsStore(defaults: defaults).iCloudSyncEnabled)

        store.iCloudSyncEnabled = false
        store.persist()
        XCTAssertFalse(SettingsStore(defaults: defaults).iCloudSyncEnabled)
    }

    func testLocalContainerUsesAppGroupStore() throws {
        let container = try Persistence.makeContainer(iCloud: false)
        XCTAssertEqual(container.configurations.first?.url, AppGroup.storeURL)
    }

    private func isolatedDefaults() -> UserDefaults {
        let name = "shelfie.tests.icloud.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: name)
        }
        return defaults
    }
}

@MainActor
final class ReleaseReliabilityTests: XCTestCase {
    func testReminderUsesDeliveryDayAndConfiguredWindow() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 9, day: 29))!
        let expiry = calendar.date(byAdding: .day, value: 5, to: today)!
        let food = FoodItemRecord(name: "Milk", expiryDate: expiry)
        let locale = Locale(identifier: "en-US")
        let initial = NotificationScheduler.dailyContent(foods: [food], warningDays: 3,
                                                         locale: locale, deliveryDate: today, calendar: calendar)
        XCTAssertFalse(initial.body.contains("Milk"))
        let later = NotificationScheduler.dailyContent(foods: [food], warningDays: 3, locale: locale,
                                                       deliveryDate: calendar.date(byAdding: .day, value: 2, to: today)!, calendar: calendar)
        XCTAssertEqual(later.body, "Milk")
        food.status = .consumed
        XCTAssertFalse(NotificationScheduler.dailyContent(foods: [food], warningDays: 3, locale: locale,
                                                          deliveryDate: expiry, calendar: calendar).body.contains("Milk"))
    }

    func testInvalidBackupLeavesExistingInventoryIntact() throws {
        let container = try memoryContainer()
        let context = container.mainContext
        context.insert(FoodItemRecord(name: "Keep me"))
        try context.save()
        var payload = try BackupService.exportPayload(context: context)
        payload.version = 99
        XCTAssertThrowsError(try BackupService.replaceAll(with: payload, context: context))
        XCTAssertEqual(try context.fetch(FetchDescriptor<FoodItemRecord>()).map(\.name), ["Keep me"])
        payload.version = 2
        payload.foods.append(payload.foods[0])
        XCTAssertThrowsError(try BackupService.replaceAll(with: payload, context: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodItemRecord>()), 1)
    }

    func testBackupRoundTripReplacesRecordsAndKeepsCustomLocations() throws {
        let container = try memoryContainer()
        let context = container.mainContext
        let location = LocationRecord(name: "Lunch bag")
        context.insert(location)
        let food = FoodItemRecord(name: "Apple", locationId: location.id, location: .other)
        food.apply(locationRecord: location)
        context.insert(food)
        try context.save()
        let payload = try BackupService.exportPayload(context: context)
        context.insert(FoodItemRecord(name: "Extra"))
        try context.save()
        try BackupService.replaceAll(with: payload, context: context)
        let verification = ModelContext(container)
        let restored = try XCTUnwrap(verification.fetch(FetchDescriptor<FoodItemRecord>()).first)
        XCTAssertEqual(try verification.fetchCount(FetchDescriptor<FoodItemRecord>()), 1)
        XCTAssertEqual(restored.name, "Apple")
        XCTAssertEqual(restored.resolvedLocation(in: try verification.fetch(FetchDescriptor<LocationRecord>()))?.name, "Lunch bag")
    }

    private func memoryContainer() throws -> ModelContainer {
        try ModelContainer(for: Persistence.schema,
                           configurations: ModelConfiguration(schema: Persistence.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }
}

@MainActor
final class QuantityAndRepeatPurchaseTests: XCTestCase {
    func testPartialConsumptionKeepsBatchActiveUntilEmpty() throws {
        let food = FoodItemRecord(name: "Eggs", quantity: 6)
        let now = Date(timeIntervalSince1970: 100)
        try food.consume(amount: 2, now: now)
        XCTAssertEqual(food.quantity, 4)
        XCTAssertEqual(food.status, .active)
        XCTAssertNil(food.resolvedDate)
        try food.consume(amount: 4, now: now)
        XCTAssertEqual(food.quantity, 0)
        XCTAssertEqual(food.status, .consumed)
        XCTAssertEqual(food.resolvedDate, now)
    }

    func testDecimalConsumptionDoesNotLeaveRoundingResidue() throws {
        let food = FoodItemRecord(name: "Milk", quantity: 0.3, unit: .liter)
        try food.consume(amount: 0.1)
        XCTAssertEqual(food.quantity, 0.2)
        try food.consume(amount: 0.2)
        XCTAssertEqual(food.quantity, 0)
        XCTAssertEqual(food.status, .consumed)
        XCTAssertFalse(FoodQuantity.isValid(0.0001))
        XCTAssertFalse(FoodQuantity.isValid(1.2345))
    }

    func testInvalidConsumptionDoesNotMutateBatch() {
        let food = FoodItemRecord(name: "Milk", quantity: 0.5, unit: .liter)
        for amount in [0, -1, 0.6, Double.nan, Double.infinity] {
            XCTAssertThrowsError(try food.consume(amount: amount))
            XCTAssertEqual(food.quantity, 0.5)
            XCTAssertEqual(food.status, .active)
        }
        food.status = .wasted
        XCTAssertThrowsError(try food.consume(amount: 0.1))
        XCTAssertEqual(food.quantity, 0.5)
    }

    func testQuantityBackupRoundTripAndLegacyDefaults() throws {
        let container = try memoryContainer()
        let context = container.mainContext
        context.insert(FoodItemRecord(name: "Rice", quantity: 2.5, unit: .kilogram))
        try context.save()
        var payload = try BackupService.exportPayload(context: context)
        XCTAssertEqual(payload.version, 5)
        try BackupService.replaceAll(with: payload, context: context)
        var verification = ModelContext(container)
        var restored = try XCTUnwrap(verification.fetch(FetchDescriptor<FoodItemRecord>()).first)
        XCTAssertEqual(restored.quantity, 2.5)
        XCTAssertEqual(restored.unit, .kilogram)

        payload.version = 2
        payload.foods[0].quantity = nil
        payload.foods[0].unit = nil
        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(BackupPayload.self, from: encoded)
        try BackupService.replaceAll(with: decoded, context: context)
        verification = ModelContext(container)
        restored = try XCTUnwrap(verification.fetch(FetchDescriptor<FoodItemRecord>()).first)
        XCTAssertEqual(restored.quantity, 1)
        XCTAssertEqual(restored.unit, .piece)
    }

    func testInvalidQuantityBackupPreservesInventory() throws {
        let container = try memoryContainer()
        let context = container.mainContext
        context.insert(FoodItemRecord(name: "Keep", quantity: 6))
        try context.save()
        var payload = try BackupService.exportPayload(context: context)
        for invalid in [-1.0, 0, Double.infinity, Double.nan] {
            payload.foods[0].quantity = invalid
            XCTAssertThrowsError(try BackupService.replaceAll(with: payload, context: context))
            XCTAssertEqual(try context.fetch(FetchDescriptor<FoodItemRecord>()).first?.quantity, 6)
        }
        payload.foods[0].quantity = nil
        XCTAssertThrowsError(try BackupService.validate(payload))
        payload.foods[0].quantity = 0
        payload.foods[0].status = .consumed
        XCTAssertNoThrow(try BackupService.validate(payload))
    }

    func testUndoRestoresQuantityStatusAndResolutionDate() throws {
        let food = FoodItemRecord(name: "Eggs", quantity: 6)
        let original = FoodActionSnapshot(food)
        try food.consume(amount: 2)
        original.restore()
        XCTAssertEqual(food.quantity, 6)
        XCTAssertEqual(food.status, .active)
        XCTAssertNil(food.resolvedDate)
        let next = FoodActionSnapshot(food)
        food.status = .wasted
        food.resolvedDate = .now
        next.restore()
        XCTAssertEqual(food.status, .active)
        XCTAssertNil(food.resolvedDate)
    }

    func testDeleteAllRestoresDefaultsAndClearsFood() throws {
        let container = try memoryContainer()
        let context = container.mainContext
        context.insert(FoodItemRecord(name: "Apple"))
        context.insert(CategoryRecord(name: "Custom"))
        context.insert(LocationRecord(name: "Bag"))
        try context.save()
        try BackupService.deleteAll(context: context)
        let verification = ModelContext(container)
        XCTAssertEqual(try verification.fetchCount(FetchDescriptor<FoodItemRecord>()), 0)
        XCTAssertEqual(try verification.fetchCount(FetchDescriptor<CategoryRecord>()), DefaultFoodCategory.allCases.count)
        XCTAssertEqual(try verification.fetchCount(FetchDescriptor<LocationRecord>()), StorageLocation.allCases.count)
    }

    func testRepeatPurchaseRequiresNewExpiryAndDoesNotChangeOriginal() {
        let original = FoodItemRecord(name: "Eggs", quantity: 4, unit: .pack)
        original.expiryDate = Date(timeIntervalSince1970: 10)
        original.categoryId = UUID()
        original.locationId = UUID()
        original.owner = "Sam"
        original.status = .consumed
        let draft = FoodEntryDraft.repeatPurchase(from: original)
        XCTAssertEqual(draft.name, original.name)
        XCTAssertEqual(draft.categoryID, original.categoryId)
        XCTAssertEqual(draft.locationID, original.locationId)
        XCTAssertEqual(draft.unit, .pack)
        XCTAssertEqual(draft.quantity, 1)
        XCTAssertNil(draft.expiryDate)
        XCTAssertTrue(draft.requiresExpiryConfirmation)
        XCTAssertEqual(original.quantity, 4)
        XCTAssertEqual(original.status, .consumed)
    }

    private func memoryContainer() throws -> ModelContainer {
        try ModelContainer(for: Persistence.schema, configurations:
            ModelConfiguration(schema: Persistence.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }
}

// Freeze the pre-quantity model to exercise an actual on-disk lightweight migration.
private enum LegacyInventory {
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
    var imageFileName: String?
    @Attribute(.externalStorage) var photoData: Data?
    var notes: String = ""
    var owner: String?
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

}

@MainActor
final class QuantityMigrationTests: XCTestCase {
    func testExistingStoreAddsQuantityWithoutLosingFood() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("legacy.store")
        let foodID = UUID()
        let photo = Data([1, 2, 3])
        do {
            let schema = Schema([CategoryRecord.self, LocationRecord.self,
                                 LegacyInventory.FoodItemRecord.self, SearchHistoryRecord.self])
            let container = try ModelContainer(for: schema, configurations:
                ModelConfiguration("Shelfie", schema: schema, url: url, cloudKitDatabase: .none))
            let context = ModelContext(container)
            let food = LegacyInventory.FoodItemRecord(id: foodID, name: "Legacy milk", photoData: photo, notes: "Keep this", owner: "Sam")
            context.insert(food)
            try context.save()
        }
        let schema = Persistence.schema
        let upgraded = try ModelContainer(for: schema, configurations:
            ModelConfiguration("Shelfie", schema: schema, url: url, cloudKitDatabase: .none))
        let context = ModelContext(upgraded)
        let food = try XCTUnwrap(context.fetch(FetchDescriptor<FoodItemRecord>()).first)
        XCTAssertEqual(food.id, foodID)
        XCTAssertEqual(food.name, "Legacy milk")
        XCTAssertEqual(food.photoData, photo)
        XCTAssertEqual(food.notes, "Keep this")
        XCTAssertEqual(food.owner, "Sam")
        XCTAssertEqual(food.quantity, 1)
        XCTAssertEqual(food.unit, .piece)
    }
}
