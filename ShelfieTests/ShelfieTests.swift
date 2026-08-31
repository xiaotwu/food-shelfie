import XCTest
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
        XCTAssertEqual(day(scan.expiryDate), "2026-09-12")
    }

    func testSingleFutureDateBecomesExpiry() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 30))!
        let scan = DateParser.parseFoodDates(from: "Packed goods 2026-10-04", now: now)
        XCTAssertEqual(day(scan.expiryDate), "2026-10-04")
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
