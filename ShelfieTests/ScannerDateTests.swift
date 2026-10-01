import XCTest
import Foundation
@testable import Shelfie

final class ScannerDateTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testInvalidCalendarDatesAreRejectedRatherThanNormalized() {
        for text in ["EXP 2026-02-30", "EXP 2025-02-29", "EXP 2026年4月31日", "EXP 31/04/2026"] {
            let result = DateParser.parseFoodDates(from: text, calendar: calendar)
            XCTAssertNil(result.expiryDate, text)
            XCTAssertTrue(result.expiryCandidates.isEmpty, text)
        }
        XCTAssertEqual(DateParser.parseFoodDates(from: "EXP 2028-02-29", calendar: calendar).expiryDate, date(2028, 2, 29))
    }

    func testSlashDatesExposeBothInterpretationsRegardlessOfLocaleOrFutureFilter() {
        for locale in [Locale(identifier: "en-US"), Locale(identifier: "en-GB"), Locale(identifier: "zh-Hans")] {
            let result = DateParser.parseFoodDates(from: "Best before 12/09/2026", now: date(2026, 10, 1), calendar: calendar, locale: locale)
            XCTAssertNil(result.expiryDate)
            XCTAssertEqual(Set(result.expiryCandidates), Set([date(2026, 9, 12), date(2026, 12, 9)]))
            XCTAssertTrue(result.requiresConfirmation)
        }
    }

    func testChinesePackagingLabelsAndSourceTextArePreserved() {
        let text = "生产日期 2026年8月1日\n有效期至 2026年12月31日"
        let result = DateParser.parseFoodDates(from: text, calendar: calendar)
        XCTAssertEqual(result.productionDate, date(2026, 8, 1))
        XCTAssertEqual(result.expiryDate, date(2026, 12, 31))
        XCTAssertEqual(result.rawText, text)
        XCTAssertTrue(result.requiresConfirmation)
    }

    func testProductionOnlyIsNeverUsedAsExpiry() {
        let result = DateParser.parseFoodDates(from: "MFG 2027-01-01", now: date(2026, 1, 1), calendar: calendar)
        XCTAssertEqual(result.productionDate, date(2027, 1, 1))
        XCTAssertNil(result.expiryDate)
        XCTAssertTrue(result.expiryCandidates.isEmpty)
    }

    func testUnambiguousSlashAndNamedMonth() {
        XCTAssertEqual(DateParser.parseFoodDates(from: "EXP 31/12/2026", calendar: calendar).expiryDate, date(2026, 12, 31))
        XCTAssertEqual(DateParser.parseFoodDates(from: "Use by December 31, 2026", calendar: calendar).expiryDate, date(2026, 12, 31))
    }

    func testBarcodeWhitespaceAndChecksumValidation() {
        XCTAssertEqual(OpenFoodFactsClient.normalizedBarcode("9638 5074"), "96385074")
        XCTAssertEqual(OpenFoodFactsClient.normalizedBarcode("0 425261 4"), "04252614")
        XCTAssertEqual(OpenFoodFactsClient.normalizedBarcode("04963406"), "04963406")
        XCTAssertEqual(OpenFoodFactsClient.normalizedBarcode("5449000000996"), "5449000000996")
        XCTAssertNil(OpenFoodFactsClient.normalizedBarcode("5449000000997"))
        XCTAssertNil(OpenFoodFactsClient.normalizedBarcode("https://example.com"))
        XCTAssertNil(OpenFoodFactsClient.normalizedBarcode("123"))
    }

    func testLookupRequestsOnlyTextAndIgnoresReturnedPhotoURL() async throws {
        ScannerFixtureProtocol.requests.reset()
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let product = try await OpenFoodFactsClient.fetch(barcode: "5449000000996", session: session)
        XCTAssertEqual(product?.name, "Coca-Cola")
        XCTAssertEqual(product?.brand, "Coca-Cola Company")
        XCTAssertEqual(product?.categoryHints, ["en:sodas"])
        let requests = ScannerFixtureProtocol.requests.snapshot()
        XCTAssertEqual(requests.count, 1, "Lookup must not download a returned product photo")
        let request = try XCTUnwrap(requests.first)
        let url = try XCTUnwrap(request.url)
        XCTAssertEqual(url.host, "world.openfoodfacts.org")
        let fields = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "fields" }?.value
        XCTAssertEqual(fields, "product_name,brands,categories_tags")
        XCTAssertEqual(request.timeoutInterval, 12)
    }

    func testAlreadyCancelledLookupDoesNotStartNetworkRequest() async {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let task = Task {
            // Cancellation is explicit before fetch regardless of executor scheduling.
            withUnsafeCurrentTask { $0?.cancel() }
            return try await OpenFoodFactsClient.fetch(barcode: "5449000000996", session: session)
        }
        do {
            _ = try await task.value
            XCTFail("Cancelled lookup must throw")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testInFlightLookupCanBeCancelled() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let task = Task { try await OpenFoodFactsClient.fetch(barcode: "96385074", session: session) }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("A pending network request must cancel")
        } catch {
            XCTAssertTrue(error is CancellationError || (error as? URLError)?.code == .cancelled)
        }
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ScannerFixtureProtocol.self]
        return URLSession(configuration: config)
    }
}

private final class ScannerRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [URLRequest] = []

    func append(_ request: URLRequest) {
        lock.lock()
        defer { lock.unlock() }
        recorded.append(request)
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        recorded.removeAll()
    }

    func snapshot() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }
}

private final class ScannerFixtureProtocol: URLProtocol {
    static let requests = ScannerRequestRecorder()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { return }
        Self.requests.append(request)
        if url.path.contains("96385074") {
            // Deliberately remain pending until URLSession cancels the request.
            return
        }
        if url.host != "world.openfoodfacts.org" {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
        } else {
            let data = Data(#"{"status":1,"code":"5449000000996","product":{"product_name":"Coca-Cola","brands":"Coca-Cola Company","categories_tags":["en:sodas"],"image_front_url":"https://images.example/photo.jpg"}}"#.utf8)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}
