import XCTest
import SwiftData
@testable import Shelfie

@MainActor
final class ShoppingInventoryTests: XCTestCase {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: Persistence.schema, configurations:
            ModelConfiguration(schema: Persistence.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    func testAnotherFullBatchPreventsFalseLowStockSuggestion() {
        let almostEmpty = FoodItemRecord(name: "Milk", quantity: 0.1, unit: .liter)
        almostEmpty.lowStockThreshold = 0.5
        let unopenedBatch = FoodItemRecord(name: "Milk", quantity: 2, unit: .liter)
        XCTAssertTrue(LowStockSuggestion.suggestions(from: [almostEmpty, unopenedBatch]).isEmpty,
                      "A nearly empty batch must not cause a refill prompt while another batch supplies the same food.")
    }

    func testUsingBatchTriggersLowStockOnlyWhenCombinedInventoryFallsBelowThreshold() throws {
        let first = FoodItemRecord(name: "Eggs", quantity: 5)
        first.lowStockThreshold = 2
        let second = FoodItemRecord(name: "Eggs", quantity: 1)
        XCTAssertTrue(LowStockSuggestion.suggestions(from: [first, second]).isEmpty)
        try first.consume(amount: 4)
        let atBoundary = try XCTUnwrap(LowStockSuggestion.suggestions(from: [first, second]).first)
        XCTAssertEqual(atBoundary.remaining, 2)
        try first.consume(amount: 1)
        XCTAssertEqual(first.status, .consumed)
        let depleted = try XCTUnwrap(LowStockSuggestion.suggestions(from: [first, second]).first)
        XCTAssertEqual(depleted.remaining, 1)
    }

    func testLowStockNormalizesNamesButDoesNotCombineDifferentUnits() throws {
        let liter = FoodItemRecord(name: "  MILK ", quantity: 0.5, unit: .liter)
        liter.lowStockThreshold = 1
        let bottle = FoodItemRecord(name: "milk", quantity: 20, unit: .bottle)
        let anotherLiter = FoodItemRecord(name: "Milk", quantity: 0.25, unit: .liter)
        let suggestions = LowStockSuggestion.suggestions(from: [liter, bottle, anotherLiter])
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(try XCTUnwrap(suggestions.first).remaining, 0.75)
        XCTAssertEqual(suggestions.first?.food.unitRaw, FoodUnit.liter.rawValue)
    }

    func testDecimalAggregationDoesNotMissExactThresholdDueToFloatingPoint() throws {
        let first = FoodItemRecord(name: "Milk", quantity: 0.1, unit: .liter)
        first.lowStockThreshold = 0.3
        let second = FoodItemRecord(name: "Milk", quantity: 0.2, unit: .liter)
        let suggestion = try XCTUnwrap(LowStockSuggestion.suggestions(from: [first, second]).first)
        XCTAssertEqual(suggestion.remaining, 0.3)
    }

    func testResolvedBatchRetainsRefillPreferenceButNotAvailableQuantity() throws {
        let discarded = FoodItemRecord(name: "Rice", quantity: 500, unit: .gram, status: .wasted)
        discarded.lowStockThreshold = 0
        let suggestion = try XCTUnwrap(LowStockSuggestion.suggestions(from: [discarded]).first)
        XCTAssertEqual(suggestion.remaining, 0)
        XCTAssertEqual(suggestion.threshold, 0)
        let active = FoodItemRecord(name: "Rice", quantity: 1, unit: .gram)
        XCTAssertTrue(LowStockSuggestion.suggestions(from: [discarded, active]).isEmpty)
    }

    func testCrossBatchThresholdUsesHighestPreference() throws {
        let first = FoodItemRecord(name: "Apples", quantity: 1)
        first.lowStockThreshold = 1
        let second = FoodItemRecord(name: "apples", quantity: 1)
        second.lowStockThreshold = 3
        let suggestion = try XCTUnwrap(LowStockSuggestion.suggestions(from: [first, second]).first)
        XCTAssertEqual(suggestion.remaining, 2)
        XCTAssertEqual(suggestion.threshold, 3)
    }

    func testRepeatedShoppingAddDoesNotDuplicateIncompleteItem() throws {
        let c = try container()
        let context = c.mainContext
        let first = FoodItemRecord(name: " Café ", unit: .pack)
        let second = FoodItemRecord(name: "CAFE", unit: .pack)
        try ShoppingListOperations.add(food: first, context: context, quantity: 2)
        try ShoppingListOperations.add(food: second, context: context, quantity: 5)
        let persisted = try ModelContext(c).fetch(FetchDescriptor<ShoppingItemRecord>())
        XCTAssertEqual(persisted.count, 1)
        XCTAssertEqual(persisted.first?.quantity, 2, "Adding the same suggestion must preserve the user's shopping quantity.")
    }

    func testDifferentUnitsAndCompletedShoppingItemsRemainSeparate() throws {
        let c = try container()
        let context = c.mainContext
        let completed = ShoppingItemRecord(name: "Milk", unit: .liter, isCompleted: true)
        context.insert(completed)
        try context.save()
        try ShoppingListOperations.add(food: FoodItemRecord(name: "Milk", unit: .liter), context: context)
        try ShoppingListOperations.add(food: FoodItemRecord(name: "Milk", unit: .bottle), context: context)
        let persisted = try ModelContext(c).fetch(FetchDescriptor<ShoppingItemRecord>())
        XCTAssertEqual(persisted.count, 3)
        XCTAssertEqual(persisted.filter { !$0.isCompleted }.count, 2)
        XCTAssertEqual(Set(persisted.filter { !$0.isCompleted }.map(\.unitRaw)), Set(["liter", "bottle"]))
    }

    func testShoppingCommitFailurePreservesSavedInventoryAndPendingEdits() throws {
        let c = try container()
        let context = c.mainContext
        context.autosaveEnabled = false
        let food = FoodItemRecord(name: "Keep", quantity: 6)
        context.insert(food)
        context.insert(ShoppingItemRecord(name: "Existing"))
        try context.save()
        food.quantity = 4
        XCTAssertThrowsError(try ShoppingListOperations.add(food: FoodItemRecord(name: "New"), context: context,
                                                           commit: { _ in throw CocoaError(.fileWriteOutOfSpace) }))
        XCTAssertEqual(food.quantity, 4, "A failed shopping save must not roll back another pending inventory edit.")
        XCTAssertEqual(try context.fetch(FetchDescriptor<ShoppingItemRecord>()).map(\.name), ["Existing"])
        let verification = ModelContext(c)
        XCTAssertEqual(try verification.fetch(FetchDescriptor<ShoppingItemRecord>()).map(\.name), ["Existing"])
        XCTAssertEqual(try verification.fetch(FetchDescriptor<FoodItemRecord>()).first?.quantity, 6)
    }

    func testShoppingRejectsInvalidQuantityBeforePersisting() throws {
        let c = try container()
        for amount in [0, -1, Double.nan, Double.infinity, 0.0001] {
            XCTAssertThrowsError(try ShoppingListOperations.add(food: FoodItemRecord(name: "Eggs"), context: c.mainContext, quantity: amount))
        }
        XCTAssertEqual(try c.mainContext.fetchCount(FetchDescriptor<ShoppingItemRecord>()), 0)
    }

    func testDecimalInputRespectsLocaleAndRejectsMalformedSuffixes() {
        XCTAssertEqual(InventoryNumber.parse("0,25", locale: Locale(identifier: "fr_FR")), 0.25)
        XCTAssertEqual(InventoryNumber.parse("0.25", locale: Locale(identifier: "en_US")), 0.25)
        for input in ["1abc", "1.2.3", ".", "1e3", "1,000"] {
            XCTAssertNil(InventoryNumber.parse(input, locale: Locale(identifier: "en_US")))
        }
    }
}
