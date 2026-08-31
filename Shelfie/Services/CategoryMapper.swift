import Foundation

enum CategoryMapper {
    static func match(hints: [String], categories: [CategoryRecord]) -> UUID? {
        let joined = hints.joined(separator: " ").lowercased()
        let rules: [(DefaultFoodCategory, [String])] = [
            (.vegetables, ["vegetable", "salad", "tomato", "lettuce", "carrot", "蔬菜", "青菜"]),
            (.fruits, ["fruit", "apple", "banana", "orange", "berry", "水果"]),
            (.meat, ["meat", "chicken", "beef", "pork", "sausage", "肉"]),
            (.seafood, ["seafood", "fish", "salmon", "shrimp", "tuna", "海鲜", "海产"]),
            (.dairyEggs, ["dairy", "milk", "cheese", "yogurt", "egg", "butter", "乳", "奶", "蛋"])
        ]
        for (kind, keys) in rules where keys.contains(where: { joined.contains($0) }) {
            if let match = categories.first(where: { DefaultFoodCategory.matching($0.name) == kind }) {
                return match.id
            }
        }
        return categories.first(where: { DefaultFoodCategory.matching($0.name) == .others })?.id
    }
}

extension CategoryRecord {
    func displayName(locale: Locale) -> String {
        DefaultFoodCategory.matching(name)?.title(locale: locale) ?? name
    }
}
