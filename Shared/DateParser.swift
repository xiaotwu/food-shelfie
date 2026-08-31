import Foundation

enum DateParser {
    private static let expiryKeywords = [
        "exp", "expiry", "expiration", "best before", "best by", "use by",
        "bbe", "bbf", "hsd", "hạn dùng", "han dung", "best before date", "until"
    ]

    private static let productionKeywords = [
        "nsx", "mfg", "mfd", "packed", "packed on", "manufactured",
        "prod", "pdt", "ngày sx", "ngay sx", "production"
    ]

    static func parseFoodDates(from rawText: String, now: Date = .now, calendar: Calendar = .current) -> FoodDateScan {
        let text = rawText.lowercased()
        let dates = extractDates(from: rawText, calendar: calendar)

        var production: Date?
        var expiry: Date?

        for date in dates {
            let marker = contextWindow(around: date.range, in: text)
            if expiryKeywords.contains(where: { marker.contains($0) }) {
                expiry = later(expiry, date.value)
            } else if productionKeywords.contains(where: { marker.contains($0) }) {
                production = later(production, date.value)
            }
        }

        if expiry == nil {
            let future = dates.map(\.value).filter { calendar.startOfDay(for: $0) >= calendar.startOfDay(for: now) }
            expiry = future.min()
        }

        if expiry == nil, dates.count == 1 {
            expiry = dates[0].value
        }

        return FoodDateScan(productionDate: production, expiryDate: expiry)
    }

    private static func later(_ current: Date?, _ candidate: Date) -> Date {
        guard let current else { return candidate }
        return candidate > current ? candidate : current
    }

    private static func contextWindow(around range: Range<String.Index>, in text: String) -> String {
        let lower = text.index(range.lowerBound, offsetBy: -24, limitedBy: text.startIndex) ?? text.startIndex
        let upper = text.index(range.upperBound, offsetBy: 12, limitedBy: text.endIndex) ?? text.endIndex
        return String(text[lower..<upper])
    }

    private static func extractDates(from text: String, calendar: Calendar) -> [(value: Date, range: Range<String.Index>)] {
        var found: [(Date, Range<String.Index>)] = []
        let patterns: [(String, String)] = [
            (#"\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\b"#, "ymd"),
            (#"\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})\b"#, "dmy"),
            (#"\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2})\b"#, "dmy2"),
            (#"\b(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+(\d{4})\b"#, "dMonY"),
            (#"\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+(\d{1,2}),?\s+(\d{4})\b"#, "monDY")
        ]

        for (pattern, kind) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let nsRange = NSRange(text.startIndex..., in: text)
            regex.enumerateMatches(in: text, options: [], range: nsRange) { match, _, _ in
                guard let match, let fullRange = Range(match.range, in: text) else { return }
                if let date = date(from: match, in: text, kind: kind, calendar: calendar) {
                    found.append((date, fullRange))
                }
            }
        }
        return found
    }

    private static func date(from match: NSTextCheckingResult, in text: String, kind: String, calendar: Calendar) -> Date? {
        func group(_ index: Int) -> String? {
            guard match.numberOfRanges > index, let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range])
        }

        var year = 0
        var month = 0
        var day = 0

        switch kind {
        case "ymd":
            year = Int(group(1) ?? "") ?? 0
            month = Int(group(2) ?? "") ?? 0
            day = Int(group(3) ?? "") ?? 0
        case "dmy":
            day = Int(group(1) ?? "") ?? 0
            month = Int(group(2) ?? "") ?? 0
            year = Int(group(3) ?? "") ?? 0
        case "dmy2":
            day = Int(group(1) ?? "") ?? 0
            month = Int(group(2) ?? "") ?? 0
            let yy = Int(group(3) ?? "") ?? 0
            year = yy < 50 ? 2000 + yy : 1900 + yy
        case "dMonY":
            day = Int(group(1) ?? "") ?? 0
            month = monthIndex(group(2) ?? "")
            year = Int(group(3) ?? "") ?? 0
        case "monDY":
            month = monthIndex(group(1) ?? "")
            day = Int(group(2) ?? "") ?? 0
            year = Int(group(3) ?? "") ?? 0
        default:
            return nil
        }

        guard year > 1970, (1...12).contains(month), (1...31).contains(day) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }

    private static func monthIndex(_ raw: String) -> Int {
        let key = String(raw.prefix(3)).lowercased()
        let map = [
            "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
            "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12
        ]
        return map[key] ?? 0
    }
}
