import Foundation

struct OpenFoodFactsProduct: Equatable, Sendable {
    var barcode: String
    var name: String
    var brand: String?
    var categoryHints: [String]
}

enum OpenFoodFactsClient {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

    enum LookupError: Error { case invalidBarcode, serverUnavailable }

    /// Accept GS1 retail codes, including whitespace in the printed digits.
    static func normalizedBarcode(_ input: String) -> String? {
        let code = input.filter { !$0.isWhitespace && $0 != "-" }
        guard [8, 12, 13, 14].contains(code.count), code.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        let digits = code.compactMap(\.wholeNumberValue)
        func validChecksum(_ digits: [Int]) -> Bool {
            let sum = digits.dropLast().reversed().enumerated().reduce(0) { $0 + $1.element * ($1.offset.isMultiple(of: 2) ? 3 : 1) }
            return (10 - sum % 10) % 10 == digits.last
        }
        if validChecksum(digits) { return code }
        // Eight-digit UPC-E has a checksum over its expanded UPC-A representation.
        if digits.count == 8, digits[0] == 0 || digits[0] == 1 {
            let d = digits
            let expanded: [Int]
            switch d[6] {
            case 0...2: expanded = [d[0], d[1], d[2], d[6], 0, 0, 0, 0, d[3], d[4], d[5], d[7]]
            case 3: expanded = [d[0], d[1], d[2], d[3], 0, 0, 0, 0, 0, d[4], d[5], d[7]]
            case 4: expanded = [d[0], d[1], d[2], d[3], d[4], 0, 0, 0, 0, 0, d[5], d[7]]
            default: expanded = [d[0], d[1], d[2], d[3], d[4], d[5], 0, 0, 0, 0, d[6], d[7]]
            }
            if validChecksum(expanded) { return code }
        }
        return nil
    }

    static func fetch(barcode: String, session overrideSession: URLSession? = nil) async throws -> OpenFoodFactsProduct? {
        try Task.checkCancellation()
        guard let trimmed = normalizedBarcode(barcode) else { throw LookupError.invalidBarcode }
        var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(trimmed).json")
        components?.queryItems = [
            URLQueryItem(name: "fields", value: "product_name,brands,categories_tags")
        ]
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Shelfie/1.2 (iOS food tracker)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await (overrideSession ?? session).data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw LookupError.serverUnavailable }
        if http.statusCode == 404 { return nil }
        guard http.statusCode == 200 else { throw LookupError.serverUnavailable }
        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        guard decoded.status == 1, let product = decoded.product else { return nil }
        let name = (product.productName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? product.brands
        guard let name, !name.isEmpty else { return nil }
        return OpenFoodFactsProduct(
            barcode: decoded.code ?? trimmed,
            name: name,
            brand: product.brands,
            categoryHints: product.categoriesTags ?? []
        )
    }

    private struct APIResponse: Decodable {
        var code: String?
        var status: Int
        var product: Product?
    }

    private struct Product: Decodable {
        var productName: String?
        var brands: String?
        var categoriesTags: [String]?

        enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case brands
            case categoriesTags = "categories_tags"
        }
    }
}
