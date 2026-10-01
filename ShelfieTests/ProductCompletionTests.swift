import XCTest
import SwiftData
import UIKit
@testable import Shelfie

@MainActor
final class ProductCompletionTests: XCTestCase {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: Persistence.schema, configurations:
            ModelConfiguration(schema: Persistence.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    func testMissingExpiryStaysMissingForNewAndEditedFood() {
        let today = Date.now
        let blank = FoodEntryExpirySelection(now: today)
        XCTAssertNil(blank.storedDate)
        XCTAssertTrue(blank.canSave)
        let food = FoodItemRecord(name: "Milk", expiryDate: nil)
        let edited = FoodEntryExpirySelection(date: food.expiryDate, now: today)
        XCTAssertNil(edited.storedDate)
        XCTAssertTrue(edited.canSave)
    }

    func testRepeatPurchaseNeedsExplicitDateOrNoDateChoice() {
        let food = FoodItemRecord(name: "Milk", expiryDate: Date.now.addingTimeInterval(86400))
        let draft = FoodEntryDraft.repeatPurchase(from: food)
        XCTAssertNil(draft.expiryDate)
        var selection = FoodEntryExpirySelection(date: draft.expiryDate, requiresConfirmation: draft.requiresExpiryConfirmation)
        XCTAssertFalse(selection.canSave)
        selection.chooseNoDate()
        XCTAssertTrue(selection.canSave)
        XCTAssertNil(selection.storedDate)
        let expiry = Date.now.addingTimeInterval(86400 * 10)
        selection.chooseDate(expiry)
        XCTAssertEqual(selection.storedDate, expiry)
        XCTAssertTrue(selection.canSave)
    }

    func testConfirmedDateScanKeepsTodaysPurchaseAndNoPhoto() {
        let now = Date.now
        let expiry = now.addingTimeInterval(86400 * 30)
        let draft = FoodEntryDraft.confirmedDateScan(expiryDate: expiry, now: now)
        XCTAssertEqual(draft.purchaseDate, now)
        XCTAssertEqual(draft.expiryDate, expiry)
        XCTAssertNil(draft.image)
    }

    func testShoppingConversionIsAtomicAndDuplicateSourceIsRejected() throws {
        let c = try container()
        let shopping = ShoppingItemRecord(name: "Milk")
        c.mainContext.insert(shopping)
        try c.mainContext.save()
        let sourceID = shopping.id
        let context = ModelContext(c)
        context.autosaveEnabled = false
        let first = FoodItemRecord(name: "Milk")
        context.insert(first)
        XCTAssertThrowsError(try FoodEntryShoppingConversion.commit(foodID: first.id, shoppingItemID: sourceID, context: context, save: { _ in
            throw CocoaError(.fileWriteOutOfSpace)
        }))
        let afterFailure = ModelContext(c)
        XCTAssertEqual(try afterFailure.fetchCount(FetchDescriptor<FoodItemRecord>()), 0)
        let unchanged = try XCTUnwrap(afterFailure.fetch(FetchDescriptor<ShoppingItemRecord>()).first)
        XCTAssertFalse(unchanged.isCompleted)
        XCTAssertNil(unchanged.inventoryFoodID)
        let saved = FoodItemRecord(name: "Milk")
        context.insert(saved)
        try FoodEntryShoppingConversion.commit(foodID: saved.id, shoppingItemID: sourceID, context: context)
        let verify = ModelContext(c)
        let linked = try XCTUnwrap(verify.fetch(FetchDescriptor<ShoppingItemRecord>()).first)
        XCTAssertEqual(linked.inventoryFoodID, saved.id)
        XCTAssertTrue(linked.isCompleted)
        XCTAssertThrowsError(try FoodEntryShoppingConversion.link(foodID: UUID(), shoppingItemID: sourceID, context: context))
        XCTAssertThrowsError(try FoodEntryShoppingConversion.link(foodID: UUID(), shoppingItemID: UUID(), context: context))
    }

    func testOpeningNeverExtendsPackageExpiry() {
        let now = Date.now
        let food = FoodItemRecord(name: "Milk", expiryDate: now.addingTimeInterval(86400))
        food.openedDate = now
        food.openedShelfLifeDays = 3
        XCTAssertEqual(food.effectiveExpiryDate, food.expiryDate)
        food.expiryDate = now.addingTimeInterval(86400 * 10)
        XCTAssertEqual(food.effectiveExpiryDate, food.openedExpiryDate)
    }

    func testDuplicateDefaultRecordsAreMergedAndReferencesRetained() throws {
        let c = try container()
        let context = c.mainContext
        let first = CategoryRecord(name: "Fruit")
        let second = CategoryRecord(name: "Fruit")
        let location = LocationRecord(name: "Fridge", builtInKey: "fridge")
        let duplicateLocation = LocationRecord(name: "Fridge", builtInKey: "fridge")
        context.insert(first); context.insert(second); context.insert(location); context.insert(duplicateLocation)
        let food = FoodItemRecord(name: "Apple", categoryId: second.id, locationId: duplicateLocation.id)
        context.insert(food)
        try context.save()
        try SeedData.bootstrap(context: context)
        let verification = ModelContext(c)
        let restored = try XCTUnwrap(verification.fetch(FetchDescriptor<FoodItemRecord>()).first)
        XCTAssertEqual(restored.categoryId, SeedData.categoryID(.fruits))
        XCTAssertEqual(restored.locationId, SeedData.locationID(.fridge))
        XCTAssertEqual(try verification.fetchCount(FetchDescriptor<CategoryRecord>()), DefaultFoodCategory.allCases.count)
        XCTAssertEqual(try verification.fetchCount(FetchDescriptor<LocationRecord>()), StorageLocation.allCases.count)
        try SeedData.bootstrap(context: context)
        XCTAssertFalse(context.hasChanges, "Repeated reconciliation should not create a save/remote-change loop")
    }

    func testBackupOpeningAndShoppingRoundTrip() throws {
        let c = try container()
        let context = c.mainContext
        let food = FoodItemRecord(name: "Milk", purchaseDate: .now.addingTimeInterval(-86400), quantity: 0.5, unit: .liter)
        food.openedDate = .now
        food.openedShelfLifeDays = 3
        food.lowStockThreshold = 0.5
        context.insert(food)
        context.insert(ShoppingItemRecord(name: "Eggs", quantity: 6))
        try context.save()
        let payload = try BackupService.exportPayload(context: context)
        try BackupService.replaceAll(with: payload, context: context)
        let verify = ModelContext(c)
        let restored = try XCTUnwrap(verify.fetch(FetchDescriptor<FoodItemRecord>()).first)
        XCTAssertEqual(restored.openedShelfLifeDays, 3)
        XCTAssertEqual(restored.lowStockThreshold, 0.5)
        XCTAssertNotNil(restored.openedDate)
        XCTAssertEqual(try verify.fetch(FetchDescriptor<ShoppingItemRecord>()).first?.quantity, 6)
    }

    func testImportCommitFailurePreservesInventoryAndShopping() throws {
        let c = try container()
        let context = c.mainContext
        context.insert(FoodItemRecord(name: "Keep"))
        context.insert(ShoppingItemRecord(name: "Keep list"))
        try context.save()
        var payload = try BackupService.exportPayload(context: context)
        payload.foods[0].name = "Replacement"
        payload.shoppingItems = []
        XCTAssertThrowsError(try BackupService.replaceAll(with: payload, context: context, commit: { _ in
            throw CocoaError(.fileWriteOutOfSpace)
        }))
        let verify = ModelContext(c)
        XCTAssertEqual(try verify.fetch(FetchDescriptor<FoodItemRecord>()).map(\.name), ["Keep"])
        XCTAssertEqual(try verify.fetch(FetchDescriptor<ShoppingItemRecord>()).map(\.name), ["Keep list"])
    }

    func testPhotoWriteFailurePreservesInventory() throws {
        let c = try container()
        let context = c.mainContext
        context.insert(FoodItemRecord(name: "Keep"))
        try context.save()
        var payload = try BackupService.exportPayload(context: context)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in UIColor.red.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 2, height: 2)) }
        payload.foods[0].imageBase64 = image.pngData()!.base64EncodedString()
        XCTAssertThrowsError(try BackupService.replaceAll(with: payload, context: context, writeImage: { _ in
            throw CocoaError(.fileWriteOutOfSpace)
        }))
        let verify = ModelContext(c)
        XCTAssertEqual(try verify.fetch(FetchDescriptor<FoodItemRecord>()).map(\.name), ["Keep"])
    }

    func testMissingReferencesAndInvalidOpeningAreRejected() throws {
        let c = try container()
        let context = c.mainContext
        context.insert(FoodItemRecord(name: "Keep"))
        try context.save()
        var payload = try BackupService.exportPayload(context: context)
        payload.foods[0].categoryId = UUID()
        XCTAssertThrowsError(try BackupService.validate(payload))
        payload.foods[0].categoryId = nil
        payload.foods[0].openedShelfLifeDays = 0
        XCTAssertThrowsError(try BackupService.validate(payload))
        payload.foods[0].openedShelfLifeDays = 3
        payload.foods[0].lowStockThreshold = -1
        XCTAssertThrowsError(try BackupService.validate(payload))
    }

    func testMalformedJSONAndOversizedImageLeaveDataIntact() throws {
        let c = try container()
        let context = c.mainContext
        context.insert(FoodItemRecord(name: "Keep"))
        try context.save()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("{invalid".utf8).write(to: url)
        XCTAssertThrowsError(try BackupService.importJSON(from: url, context: context))
        var payload = try BackupService.exportPayload(context: context)
        payload.foods[0].imageBase64 = String(repeating: "A", count: 14 * 1024 * 1024 + 1)
        XCTAssertThrowsError(try BackupService.replaceAll(with: payload, context: context))
        XCTAssertEqual(try context.fetch(FetchDescriptor<FoodItemRecord>()).map(\.name), ["Keep"])
    }
}
