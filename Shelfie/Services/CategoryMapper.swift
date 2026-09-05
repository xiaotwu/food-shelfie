import Foundation

enum CategoryMapper {
    static func match(hints: [String], categories: [CategoryRecord]) -> UUID? {
        let joined = hints.joined(separator: " ").lowercased()
        let rules: [(DefaultFoodCategory, [String])] = [
            (.vegetables, ["vegetable", "veggie", "salad", "tomato", "lettuce", "carrot"]),
            (.fruits, ["fruit", "apple", "banana", "orange", "berry", "strawberry"]),
            (.meat, ["meat", "chicken", "beef", "pork", "sausage", "steak"]),
            (.seafood, ["seafood", "fish", "salmon", "shrimp", "tuna", "crab"]),
            (.dairyEggs, ["dairy", "milk", "cheese", "yogurt", "egg", "butter"])
        ]
        for (kind, keys) in rules {
            let localizedName = kind.title(locale: .simplifiedChinese).lowercased()
            if keys.contains(where: { joined.contains($0) }) || joined.contains(localizedName) {
                if let match = categories.first(where: { DefaultFoodCategory.matching($0.name) == kind }) {
                    return match.id
                }
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
