import XCTest
import SwiftData
@testable import Shelfie

@MainActor
final class BackupFixtureTests: XCTestCase {
    private let categoryID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    private let foodID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    private let locationID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
    private let shoppingID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!

    private func fixture(_ version: Int) -> URL {
        Bundle(for: Self.self).url(forResource: "backup-v\(version)", withExtension: "json")!
    }

    private func payload(_ version: Int) throws -> BackupPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupPayload.self, from: Data(contentsOf: fixture(version)))
    }

    private func container() throws -> ModelContainer {
        try ModelContainer(for: Persistence.schema,
                           configurations: ModelConfiguration(schema: Persistence.schema, isStoredInMemoryOnly: true))
    }

    func testV1RealJSONRestoresLegacyQuantityAndMigratesLocation() throws {
        let store = try container()
        let raw = try payload(1)
        XCTAssertNil(raw.locations)
        XCTAssertNil(raw.foods.first?.quantity)
        XCTAssertNil(raw.foods.first?.unit)
        try BackupService.importJSON(from: fixture(1), context: store.mainContext)
        let read = ModelContext(store)
        let food = try XCTUnwrap(read.fetch(FetchDescriptor<FoodItemRecord>()).first)
        XCTAssertEqual(food.id, foodID)
        XCTAssertEqual(food.categoryId, categoryID)
        XCTAssertEqual(food.quantity, 1)
        XCTAssertEqual(food.unit, .piece)
        XCTAssertNil(food.openedDate)
        XCTAssertNil(food.lowStockThreshold)
        XCTAssertEqual(food.locationId, SeedData.locationID(.pantry))
        XCTAssertEqual(try read.fetch(FetchDescriptor<SearchHistoryRecord>()).first?.query, "oat milk")
        XCTAssertTrue(try read.fetch(FetchDescriptor<ShoppingItemRecord>()).isEmpty)
        XCTAssertNoThrow(try BackupService.encodedData(from: BackupService.exportPayload(context: read)))
    }

    func testV2RealJSONPreservesCustomLocationAndLegacyDefaults() throws {
        let store = try container()
        try BackupService.importJSON(from: fixture(2), context: store.mainContext)
        let read = ModelContext(store)
        let food = try XCTUnwrap(read.fetch(FetchDescriptor<FoodItemRecord>()).first)
        let locations = try read.fetch(FetchDescriptor<LocationRecord>())
        XCTAssertEqual(food.locationId, locationID)
        XCTAssertEqual(food.resolvedLocation(in: locations)?.name, "Upper cupboard")
        XCTAssertEqual(food.quantity, 1)
        XCTAssertEqual(food.unit, .piece)
        XCTAssertEqual(food.notes, "Historical backup fixture")
    }

    func testV3RealJSONPreservesQuantityAndOwner() throws {
        let store = try container()
        try BackupService.importJSON(from: fixture(3), context: store.mainContext)
        let read = ModelContext(store)
        let food = try XCTUnwrap(read.fetch(FetchDescriptor<FoodItemRecord>()).first)
        XCTAssertEqual(food.quantity, 2.5)
        XCTAssertEqual(food.unit, .liter)
        XCTAssertEqual(food.owner, "Fixture owner")
        XCTAssertNil(food.openedDate)
        XCTAssertNil(food.openedShelfLifeDays)
    }

    func testV4RealJSONPreservesOpenedStockAndShoppingAndRoundTrips() throws {
        let store = try container()
        let raw = try payload(4)
        try BackupService.importJSON(from: fixture(4), context: store.mainContext)
        let read = ModelContext(store)
        let food = try XCTUnwrap(read.fetch(FetchDescriptor<FoodItemRecord>()).first)
        let shopping = try XCTUnwrap(read.fetch(FetchDescriptor<ShoppingItemRecord>()).first)
        XCTAssertEqual(food.openedDate, raw.foods.first?.openedDate)
        XCTAssertEqual(food.openedShelfLifeDays, 3)
        XCTAssertEqual(food.lowStockThreshold, 1)
        XCTAssertEqual(shopping.id, shoppingID)
        XCTAssertEqual(shopping.name, "Oat milk")
        XCTAssertEqual(shopping.quantity, 2)
        XCTAssertEqual(shopping.unit, .bottle)
        XCTAssertTrue(shopping.isCompleted)
        XCTAssertNil(shopping.inventoryFoodID, "Legacy backups must not invent a previous inventory conversion.")
        let exported = try BackupService.exportPayload(context: read)
        let data = try BackupService.encodedData(from: exported)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BackupPayload.self, from: data)
        let otherStore = try container()
        try BackupService.replaceAll(with: decoded, context: otherStore.mainContext)
        let restoredContext = ModelContext(otherStore)
        let restored = try XCTUnwrap(restoredContext.fetch(FetchDescriptor<FoodItemRecord>()).first)
        XCTAssertEqual(restored.quantity, 2.5)
        XCTAssertEqual(restored.unit, .liter)
        XCTAssertEqual(restored.openedDate, food.openedDate)
        XCTAssertEqual(restored.lowStockThreshold, 1)
    }

    func testV5RoundTripPreservesShoppingConversionAfterFoodDeletion() throws {
        let store = try container()
        try BackupService.importJSON(from: fixture(4), context: store.mainContext)
        let shopping = try XCTUnwrap(store.mainContext.fetch(FetchDescriptor<ShoppingItemRecord>()).first)
        shopping.inventoryFoodID = foodID
        try store.mainContext.save()
        for food in try store.mainContext.fetch(FetchDescriptor<FoodItemRecord>()) {
            store.mainContext.delete(food)
        }
        try store.mainContext.save()
        let exported = try BackupService.exportPayload(context: store.mainContext)
        XCTAssertEqual(exported.version, 5)
        XCTAssertTrue(exported.foods.isEmpty)
        let data = try BackupService.encodedData(from: exported)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BackupPayload.self, from: data)
        let other = try container()
        try BackupService.replaceAll(with: decoded, context: other.mainContext)
        let restored = try XCTUnwrap(ModelContext(other).fetch(FetchDescriptor<ShoppingItemRecord>()).first)
        XCTAssertEqual(restored.inventoryFoodID, foodID,
                       "The conversion marker must survive cleanup and restore to prevent duplicate additions.")
        XCTAssertTrue(restored.isCompleted)
    }

    func testExportRejectsInvalidInventoryRatherThanCreatingUnrestorableBackup() throws {
        let store = try container()
        store.mainContext.insert(FoodItemRecord(name: "Invalid active batch", quantity: 0))
        try store.mainContext.save()
        XCTAssertThrowsError(try BackupService.exportPayload(context: store.mainContext)) { error in
            XCTAssertEqual(error as? BackupService.BackupError, .invalidQuantity)
        }
        var invalid = try payload(4)
        invalid.foods[0].locationId = UUID()
        XCTAssertThrowsError(try BackupService.writeJSON(from: invalid)) { error in
            XCTAssertEqual(error as? BackupService.BackupError, .invalidReference)
        }
    }

    func testEncodingChecksActualSerializedSize() throws {
        var large = try payload(4)
        large.foods[0].notes = String(repeating: "x", count: 4096)
        // Exercise the actual serialized-byte guard without allocating a 100 MB test string.
        XCTAssertThrowsError(try BackupService.encodedData(from: large, sizeLimit: 1024)) { error in
            XCTAssertEqual(error as? BackupService.BackupError, .tooLarge)
        }
        XCTAssertNoThrow(try BackupService.encodedData(from: large))
    }

    func testOversizedFileMetadataRejectsImportBeforeMutatingInventory() throws {
        let store = try container()
        store.mainContext.insert(FoodItemRecord(name: "Keep me"))
        try store.mainContext.save()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("oversize-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(FileManager.default.createFile(atPath: url.path, contents: Data()))
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(BackupService.maximumFileBytes + 1))
        try handle.close()
        XCTAssertThrowsError(try BackupService.importJSON(from: url, context: store.mainContext)) { error in
            XCTAssertEqual(error as? BackupService.BackupError, .tooLarge)
        }
        XCTAssertEqual(try ModelContext(store).fetch(FetchDescriptor<FoodItemRecord>()).map(\.name), ["Keep me"])
    }

    func testMissingReferencedPhotoStopsExport() throws {
        let store = try container()
        store.mainContext.insert(FoodItemRecord(name: "Photo batch", imageFileName: "missing-\(UUID()).jpg"))
        try store.mainContext.save()
        XCTAssertThrowsError(try BackupService.exportPayload(context: store.mainContext)) { error in
            XCTAssertEqual(error as? BackupService.BackupError, .imageReadFailed)
        }
    }
}
