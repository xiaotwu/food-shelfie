import XCTest
import SwiftData
@testable import Shelfie

@MainActor
final class ReminderRoutingTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/New_York")!
        return value
    }
    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
    private func plan(_ foods: [FoodItemRecord], now: Date, hour: Int = 9, minute: Int = 0,
                      warning: Int = 3, weekly: Bool = false) -> [NotificationScheduler.PlannedReminder] {
        NotificationScheduler.plannedReminders(foods: foods, warningDays: warning, hour: hour, minute: minute,
                                               weeklyEnabled: weekly, locale: .englishUS, now: now, calendar: calendar)
    }

    func testEmptyAndResolvedFoodsDoNotCreateCheckInNotifications() {
        XCTAssertTrue(plan([], now: date(2026, 9, 30), weekly: true).isEmpty)
        let food = FoodItemRecord(name: "Milk", expiryDate: date(2026, 10, 1), status: .consumed)
        XCTAssertTrue(plan([food], now: date(2026, 9, 30), weekly: true).isEmpty)
        XCTAssertTrue(plan([FoodItemRecord(name: "Undated")], now: date(2026, 9, 30), weekly: true).isEmpty)
    }

    func testDistantExpiryIsScheduledWithout28DayHorizon() {
        let food = FoodItemRecord(name: "Frozen peas", expiryDate: date(2027, 2, 1))
        let requests = plan([food], now: date(2026, 9, 30))
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first?.deliveryDate, date(2027, 1, 29, hour: 9))
        XCTAssertEqual(requests.last?.deliveryDate, date(2027, 2, 1, hour: 9))
        XCTAssertEqual(requests.last?.content.userInfo["foodID"] as? String, food.id.uuidString)
    }

    func testZeroWarningSchedulesOnlyExpiryAndPastTimeMovesForward() {
        let food = FoodItemRecord(name: "Milk", expiryDate: date(2026, 9, 30))
        let requests = plan([food], now: date(2026, 9, 30, hour: 10), warning: 0)
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.deliveryDate, date(2026, 10, 1, hour: 9))
    }

    func testSpringDSTUsesNextValidWallTimeAndFallUsesFirstOccurrence() {
        let spring = FoodItemRecord(name: "Spring", expiryDate: date(2027, 3, 14))
        let springRequests = plan([spring], now: date(2027, 3, 13), hour: 2, minute: 30, warning: 0)
        let springDelivery = springRequests.first!.deliveryDate
        XCTAssertEqual(calendar.component(.day, from: springDelivery), 14)
        XCTAssertEqual(calendar.component(.hour, from: springDelivery), 3)
        let fall = FoodItemRecord(name: "Fall", expiryDate: date(2026, 11, 1))
        let fallDelivery = plan([fall], now: date(2026, 10, 31), hour: 1, minute: 30, warning: 0).first!.deliveryDate
        XCTAssertEqual(calendar.component(.hour, from: fallDelivery), 1)
        XCTAssertTrue(calendar.timeZone.isDaylightSavingTime(for: fallDelivery))
    }

    func testPendingLimitIsDeterministicAndPrioritizesEarlierDates() {
        let foods = (0..<80).map { index in
            FoodItemRecord(name: "Food \(index)", expiryDate: calendar.date(byAdding: .day, value: index + 1, to: date(2026, 9, 30)))
        }
        let first = plan(foods, now: date(2026, 9, 30))
        let reverse = plan(Array(foods.reversed()), now: date(2026, 9, 30))
        XCTAssertEqual(first.count, 60)
        XCTAssertEqual(first.map(\.identifier), reverse.map(\.identifier))
        XCTAssertEqual(first.first?.foodID, foods.first?.id)
        XCTAssertFalse(first.contains { $0.foodID == foods.last?.id })
    }

    func testOpenedShelfLifeUsesEarlierEffectiveExpiry() {
        let food = FoodItemRecord(name: "Juice", expiryDate: date(2026, 12, 1))
        food.openedDate = date(2026, 9, 30)
        food.openedShelfLifeDays = 2
        let requests = plan([food], now: date(2026, 9, 30), warning: 0)
        XCTAssertEqual(requests.first?.deliveryDate, date(2026, 10, 2, hour: 9))
    }

    func testRoutesValidateSchemeAndExactFoodID() {
        let id = UUID()
        XCTAssertEqual(ShelfieRoute(url: URL(string: "shelfie://food/\(id)")!), .food(id))
        XCTAssertEqual(ShelfieRoute(url: URL(string: "shelfie://shelf")!), .shelf)
        for raw in ["https://food/\(id)", "shelfie://food/not-a-uuid", "shelfie://food/\(id)/extra",
                    "shelfie://food/\(id)?delete=true", "shelfie://food/\(id)#fragment", "shelfie://other/\(id)"] {
            XCTAssertNil(ShelfieRoute(url: URL(string: raw)!))
        }
    }

    func testShelfRouteClearsPriorFoodSelectionAfterNotificationAction() {
        let navigation = AppNavigationState()
        let oldRequest = navigation.shelfRequest
        navigation.open(.food(UUID()))
        XCTAssertNotNil(navigation.foodID)
        navigation.open(.shelf)
        XCTAssertNil(navigation.foodID)
        XCTAssertNotEqual(navigation.shelfRequest, oldRequest)
    }

    func testGlobalSearchSwitchesTabsAndRepeatedRequestsRemainDistinct() throws {
        let navigation = AppNavigationState()
        navigation.selectedTab = .settings
        navigation.open(.food(UUID()))
        navigation.selectedTab = .settings
        navigation.requestShelfAction(.search)
        let first = try XCTUnwrap(navigation.shelfActionRequest)
        XCTAssertEqual(first.action, .search)
        XCTAssertEqual(navigation.selectedTab, .shelf)
        XCTAssertNil(navigation.foodID)
        navigation.requestShelfAction(.search)
        let second = try XCTUnwrap(navigation.shelfActionRequest)
        XCTAssertNotEqual(first.id, second.id, "Pressing Search again must issue a new command even when the action is unchanged.")
    }

    func testCompletingAnOldGlobalRequestCannotDiscardANewerAction() throws {
        let navigation = AppNavigationState()
        navigation.requestShelfAction(.search)
        let first = try XCTUnwrap(navigation.shelfActionRequest)
        navigation.requestShelfAction(.add)
        let second = try XCTUnwrap(navigation.shelfActionRequest)
        navigation.completeShelfAction(first.id)
        XCTAssertEqual(navigation.shelfActionRequest, second, "A disappearing page must not clear the command sent by a newer toolbar interaction.")
        navigation.completeShelfAction(second.id)
        XCTAssertNil(navigation.shelfActionRequest)
        navigation.completeShelfAction(second.id)
        XCTAssertNil(navigation.shelfActionRequest, "A command must not become pending again after a duplicate completion.")
    }

    func testGlobalSortAndExpiredFilterReturnToShelfAndKeepEachOther() throws {
        let navigation = AppNavigationState()
        navigation.selectedTab = .insights
        navigation.setExpiredOnly(true)
        XCTAssertTrue(navigation.showExpiredOnly)
        XCTAssertEqual(navigation.selectedTab, .shelf)
        XCTAssertEqual(navigation.shelfActionRequest?.action, .revealShelf)
        let filterRequest = try XCTUnwrap(navigation.shelfActionRequest)
        navigation.selectedTab = .settings
        navigation.chooseSort(.byName)
        XCTAssertEqual(navigation.sortMode, .byName)
        XCTAssertTrue(navigation.showExpiredOnly, "Changing sort must preserve the chosen expired filter.")
        XCTAssertEqual(navigation.selectedTab, .shelf)
        let sortRequest = try XCTUnwrap(navigation.shelfActionRequest)
        XCTAssertEqual(sortRequest.action, .revealShelf)
        XCTAssertNotEqual(sortRequest.id, filterRequest.id)
        navigation.setExpiredOnly(false)
        XCTAssertEqual(navigation.sortMode, .byName, "Changing the filter must preserve the chosen sort.")
        XCTAssertFalse(navigation.showExpiredOnly)
    }

    func testFoodAndShelfDeepLinksReplacePendingGlobalPresentation() {
        let navigation = AppNavigationState()
        let id = UUID()
        navigation.requestShelfAction(.scan)
        navigation.open(.food(id))
        XCTAssertNil(navigation.shelfActionRequest, "A food deep link must not accidentally open a pending scanner after navigation.")
        XCTAssertEqual(navigation.foodID, id)
        XCTAssertEqual(navigation.selectedTab, .shelf)
        navigation.requestShelfAction(.repeatPurchase(id))
        XCTAssertNil(navigation.foodID)
        XCTAssertEqual(navigation.shelfActionRequest?.action, .repeatPurchase(id))
        navigation.open(.shelf)
        XCTAssertNil(navigation.shelfActionRequest)
        XCTAssertNil(navigation.foodID)
        XCTAssertEqual(navigation.selectedTab, .shelf)
    }

    func testNotificationActionPersistsAndIsIdempotentAndMissingFoodFails() throws {
        let container = try ModelContainer(for: Persistence.schema, configurations: ModelConfiguration(schema: Persistence.schema, isStoredInMemoryOnly: true))
        let context = container.mainContext
        let food = FoodItemRecord(name: "Milk", quantity: 2)
        context.insert(food)
        try context.save()
        let now = date(2026, 9, 30)
        try NotificationScheduler.resolve(foodID: food.id, status: .consumed, context: context, now: now)
        XCTAssertEqual(food.status, .consumed)
        XCTAssertEqual(food.quantity, 0)
        try NotificationScheduler.resolve(foodID: food.id, status: .wasted, context: context)
        XCTAssertEqual(food.status, .consumed)
        XCTAssertEqual(food.resolvedDate, now)
        XCTAssertThrowsError(try NotificationScheduler.resolve(foodID: UUID(), status: .wasted, context: context))
    }
}
