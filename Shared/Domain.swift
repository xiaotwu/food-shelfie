import Foundation
import SwiftUI

enum StorageLocation: String, Codable, CaseIterable, Identifiable, Sendable {
    case fridge
    case freezer
    case pantry
    case other

    var id: String { rawValue }

    var storedName: String {
        switch self {
        case .fridge: "Fridge"
        case .freezer: "Freezer"
        case .pantry: "Pantry"
        case .other: "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .fridge: "refrigerator"
        case .freezer: "snowflake"
        case .pantry: "cabinet"
        case .other: "shippingbox"
        }
    }

    func title(locale: Locale) -> String {
        switch self {
        case .fridge: locale.text("location.fridge")
        case .freezer: locale.text("location.freezer")
        case .pantry: locale.text("location.pantry")
        case .other: locale.text("location.other")
        }
    }
}

enum InventoryTab: String, CaseIterable, Identifiable, Sendable {
    case all
    case fridge
    case freezer
    case pantry
    case other

    var id: String { rawValue }

    var location: StorageLocation? {
        switch self {
        case .all: nil
        case .fridge: .fridge
        case .freezer: .freezer
        case .pantry: .pantry
        case .other: .other
        }
    }

    func title(locale: Locale) -> String {
        switch self {
        case .all: locale.text("location.all")
        case .fridge: StorageLocation.fridge.title(locale: locale)
        case .freezer: StorageLocation.freezer.title(locale: locale)
        case .pantry: StorageLocation.pantry.title(locale: locale)
        case .other: StorageLocation.other.title(locale: locale)
        }
    }
}

enum FoodStatus: String, Codable, CaseIterable, Sendable {
    case active
    case wasted
    case consumed
}

enum Freshness: String, Codable, CaseIterable, Sendable {
    case fresh
    case warning
    case urgent
    case expired

    func title(locale: Locale) -> String {
        switch self {
        case .fresh: locale.text("freshness.fresh")
        case .warning: locale.text("freshness.warning")
        case .urgent: locale.text("freshness.urgent")
        case .expired: locale.text("freshness.expired")
        }
    }
}

enum InventorySortMode: String, Codable, CaseIterable, Sendable {
    case none
    case byExpiry
    case byName

    func title(locale: Locale) -> String {
        switch self {
        case .none: locale.text("sort.recent")
        case .byExpiry: locale.text("sort.expiry")
        case .byName: locale.text("sort.name")
        }
    }
}

enum ThemeMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    func title(locale: Locale) -> String {
        switch self {
        case .system: locale.text("theme.system")
        case .light: locale.text("theme.light")
        case .dark: locale.text("theme.dark")
        }
    }
}

enum SeedColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case sapphire
    case ruby
    case topaz
    case emerald
    case amethyst

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .sapphire: Color(red: 0.18, green: 0.44, blue: 0.93)
        case .ruby: Color(red: 0.84, green: 0.27, blue: 0.31)
        case .topaz: Color(red: 0.89, green: 0.63, blue: 0.03)
        case .emerald: Color(red: 0.12, green: 0.62, blue: 0.42)
        case .amethyst: Color(red: 0.48, green: 0.36, blue: 0.86)
        }
    }

    func title(locale: Locale) -> String {
        switch self {
        case .sapphire: locale.text("color.sapphire")
        case .ruby: locale.text("color.ruby")
        case .topaz: locale.text("color.topaz")
        case .emerald: locale.text("color.emerald")
        case .amethyst: locale.text("color.amethyst")
        }
    }
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case englishUS
    case chineseSimplified

    var id: String { rawValue }

    static func persisted(_ raw: String?) -> AppLanguage {
        switch raw {
        case "chineseSimplified", "chinese", "zh", "zh-CN", "zh-Hans": .chineseSimplified
        default: .englishUS
        }
    }

    var locale: Locale {
        switch self {
        case .englishUS: .englishUS
        case .chineseSimplified: .simplifiedChinese
        }
    }

    func title(locale: Locale) -> String {
        switch self {
        case .englishUS: locale.text("language.english")
        case .chineseSimplified: locale.text("language.chinese")
        }
    }
}

enum DefaultFoodCategory: String, CaseIterable, Identifiable, Sendable {
    case vegetables
    case fruits
    case meat
    case seafood
    case dairyEggs
    case others

    var id: String { rawValue }

    var catalogKey: String { "category.\(rawValue)" }

    var storedName: String {
        switch self {
        case .vegetables: "Vegetables"
        case .fruits: "Fruit"
        case .meat: "Meat"
        case .seafood: "Seafood"
        case .dairyEggs: "Dairy & eggs"
        case .others: "Other"
        }
    }

    func title(locale: Locale) -> String {
        locale.text(catalogKey)
    }

    static func matching(_ name: String) -> DefaultFoodCategory? {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        for kind in allCases {
            if folded == kind.storedName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) ||
               folded == kind.rawValue.lowercased() ||
               folded == kind.title(locale: .englishUS).lowercased() ||
               folded == kind.title(locale: .simplifiedChinese).lowercased() {
                return kind
            }
        }
        let englishAliases: [(DefaultFoodCategory, [String])] = [
            (.vegetables, ["vegetables", "vegetable", "veggie", "veggies", "produce"]),
            (.fruits, ["fruit", "fruits", "berries", "berry"]),
            (.meat, ["meat", "poultry", "beef", "pork", "chicken"]),
            (.seafood, ["seafood", "fish", "shellfish", "crustacean"]),
            (.dairyEggs, ["dairy & eggs", "dairy and eggs", "dairy", "milk", "eggs", "egg"]),
            (.others, ["other", "others", "misc", "miscellaneous"])
        ]
        return englishAliases.first(where: { _, aliases in aliases.contains(folded) })?.0
    }
}

enum AnalyticsPeriod: String, CaseIterable, Identifiable, Sendable {
    case week
    case month

    var id: String { rawValue }

    func title(locale: Locale) -> String {
        switch self {
        case .week: locale.text("insights.period.week")
        case .month: locale.text("insights.period.month")
        }
    }
}

enum RemainingDaysCopy {
    static func label(days: Int?, locale: Locale, short: Bool = false) -> String {
        guard let days else { return locale.text("days.none") }
        if days < 0 {
            let count = abs(days) as Int
            return locale.format(short ? "days.expiredAgoShort" : "days.expiredAgo", count)
        }
        if days == 0 { return locale.text("days.today") }
        if days == 1 { return locale.text("days.one") }
        return locale.format("days.other", days)
    }
}

struct FoodDateScan: Equatable, Sendable {
    var productionDate: Date?
    var expiryDate: Date?
}

struct FreshnessRules {
    static let urgentDays = 3
    static let warningDays = 7

    static func remainingDays(from expiry: Date?, now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let expiry else { return nil }
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: expiry)
        return calendar.dateComponents([.day], from: start, to: end).day
    }

    static func freshness(expiry: Date?, now: Date = .now, calendar: Calendar = .current) -> Freshness {
        guard let days = remainingDays(from: expiry, now: now, calendar: calendar) else {
            return .fresh
        }
        if days < 0 { return .expired }
        if days <= urgentDays { return .urgent }
        if days <= warningDays { return .warning }
        return .fresh
    }

    /// 0 at expiry, 1 at purchase, interpolating between.
    static func usedProgress(purchase: Date, expiry: Date?, now: Date = .now) -> Double {
        guard let expiry else { return 0 }
        let purchaseTime = purchase.timeIntervalSince1970
        let expiryTime = expiry.timeIntervalSince1970
        let nowTime = now.timeIntervalSince1970
        if nowTime >= expiryTime { return 1 }
        if nowTime <= purchaseTime { return 0 }
        let total = expiryTime - purchaseTime
        guard total > 0 else { return 1 }
        return ((nowTime - purchaseTime) / total).clamped(to: 0...1)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

struct BackupPayload: Codable, Equatable {
    var version: Int
    var exportedAt: Date
    var categories: [BackupCategory]
    var locations: [BackupLocation]?
    var foods: [BackupFood]
    var searchHistory: [BackupSearch]
}

struct BackupLocation: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var builtInKey: String?
    var symbolName: String
    var sortOrder: Int
}

struct BackupCategory: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var details: String
}

struct BackupFood: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var categoryId: UUID?
    var location: StorageLocation
    var locationId: UUID?
    var locationName: String?
    var purchaseDate: Date
    var expiryDate: Date?
    var imageFileName: String?
    var imageBase64: String?
    var notes: String
    var owner: String? = nil
    var status: FoodStatus
    var resolvedDate: Date?
}

struct BackupSearch: Codable, Equatable {
    var query: String
    var timestamp: Date
}

struct WidgetFoodSnapshot: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var expiryDate: Date
    var remainingDays: Int
    var location: StorageLocation
}

struct WidgetSnapshot: Codable, Equatable {
    var expiredCount: Int
    var expiringSoonCount: Int
    var weeklyCounts: [Int]
    var foodsThisWeek: [WidgetFoodSnapshot]
    var updatedAt: Date
}
