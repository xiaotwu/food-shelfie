import Foundation

struct OpenFoodFactsProduct: Equatable, Sendable {
    var barcode: String
    var name: String
    var brand: String?
    var imageURL: URL?
    var categoryHints: [String]
}

enum OpenFoodFactsClient {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        return URLSession(configuration: config)
    }()

    static func fetch(barcode: String) async throws -> OpenFoodFactsProduct? {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(trimmed).json")
        components?.queryItems = [
            URLQueryItem(name: "fields", value: "product_name,brands,image_front_url,categories_tags")
        ]
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Shelfie/1.0 (iOS food tracker)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        guard decoded.status == 1, let product = decoded.product else { return nil }
        let name = (product.productName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? product.brands
        guard let name, !name.isEmpty else { return nil }
        return OpenFoodFactsProduct(
            barcode: decoded.code ?? trimmed,
            name: name,
            brand: product.brands,
            imageURL: product.imageFrontURL.flatMap(URL.init(string:)),
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
        var imageFrontURL: String?
        var categoriesTags: [String]?

        enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case brands
            case imageFrontURL = "image_front_url"
            case categoriesTags = "categories_tags"
        }
    }
}
