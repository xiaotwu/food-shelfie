import Foundation

enum ValidationResult: Equatable, Sendable {
    case success
    case idle
    case emptyField
    case textTooShort
    case futureDate
    case pastDate
    case invalidDateRange

    var isValid: Bool {
        self == .success || self == .idle
    }

    func message(locale: Locale) -> String? {
        switch self {
        case .success, .idle:
            return nil
        case .emptyField:
            return locale.text("validation.required")
        case .textTooShort:
            return locale.text("validation.tooShort")
        case .futureDate:
            return locale.text("validation.purchaseFuture")
        case .pastDate:
            return locale.text("validation.expiryPast")
        case .invalidDateRange:
            return locale.text("validation.expiryBeforePurchase")
        }
    }
}

enum FoodValidator {
    static func validateName(_ name: String) -> ValidationResult {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .emptyField }
        if trimmed.count < 2 { return .textTooShort }
        return .success
    }

    static func validatePurchaseDate(_ purchaseDate: Date?, now: Date = .now, calendar: Calendar = .current) -> ValidationResult {
        guard let purchaseDate else { return .emptyField }
        if calendar.startOfDay(for: purchaseDate) > calendar.startOfDay(for: now) {
            return .futureDate
        }
        return .success
    }

    static func validateExpiryDate(
        _ expiryDate: Date?,
        purchaseDate: Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> ValidationResult {
        guard let expiryDate else { return .emptyField }
        if let purchaseDate, calendar.startOfDay(for: expiryDate) < calendar.startOfDay(for: purchaseDate) {
            return .invalidDateRange
        }
        return .success
    }
}
