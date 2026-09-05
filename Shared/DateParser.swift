import Foundation

enum DateParser {
    private static let expiryKeywords = [
        "exp", "expiry", "expiration", "best before", "best by", "use by",
        "bbe", "bbf", "best before date", "until"
    ]

    private static let productionKeywords = [
        "mfg", "mfd", "packed", "packed on", "manufactured",
        "prod", "pdt", "production"
    ]

    private enum DateClassification {
        case expiry
        case production
    }

    private enum DateFormatKind {
        case yearMonthDay
        case dayMonthYear
        case dayMonthShortYear
        case dayMonthNameYear
        case monthNameDayYear
    }

    static func parseFoodDates(from rawText: String, now: Date = .now, calendar: Calendar = .current) -> FoodDateScan {
        let text = rawText.lowercased()
        let dates = extractDates(from: rawText, calendar: calendar)

        var production: Date?
        var expiry: Date?

        for date in dates {
            switch classify(dateRange: date.range, in: text) {
            case .expiry:
                expiry = later(expiry, date.value)
            case .production:
                production = later(production, date.value)
            case .none:
                break
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

    private static func classify(dateRange: Range<String.Index>, in text: String) -> DateClassification? {
        let lower = text.index(dateRange.lowerBound, offsetBy: -24, limitedBy: text.startIndex) ?? text.startIndex
        let prefixText = String(text[lower..<dateRange.lowerBound])

        let upper = text.index(dateRange.upperBound, offsetBy: 12, limitedBy: text.endIndex) ?? text.endIndex
        let suffixText = String(text[dateRange.upperBound..<upper])

        var bestExpiryDistance: Int?
        for kw in expiryKeywords {
            if let range = prefixText.range(of: kw, options: .backwards) {
                let dist = prefixText.distance(from: range.upperBound, to: prefixText.endIndex)
                bestExpiryDistance = min(bestExpiryDistance ?? Int.max, dist)
            }
        }

        var bestProductionDistance: Int?
        for kw in productionKeywords {
            if let range = prefixText.range(of: kw, options: .backwards) {
                let dist = prefixText.distance(from: range.upperBound, to: prefixText.endIndex)
                bestProductionDistance = min(bestProductionDistance ?? Int.max, dist)
            }
        }

        if let expDist = bestExpiryDistance, let mfgDist = bestProductionDistance {
            return expDist <= mfgDist ? .expiry : .production
        } else if bestExpiryDistance != nil {
            return .expiry
        } else if bestProductionDistance != nil {
            return .production
        }

        let hasExpirySuffix = expiryKeywords.contains(where: { suffixText.contains($0) })
        let hasProductionSuffix = productionKeywords.contains(where: { suffixText.contains($0) })
        if hasExpirySuffix && !hasProductionSuffix {
            return .expiry
        } else if hasProductionSuffix && !hasExpirySuffix {
            return .production
        }
        return nil
    }

    private static func extractDates(from text: String, calendar: Calendar) -> [(value: Date, range: Range<String.Index>)] {
        var found: [(Date, Range<String.Index>)] = []
        let patterns: [(String, DateFormatKind)] = [
            (#"\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\b"#, .yearMonthDay),
            (#"\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})\b"#, .dayMonthYear),
            (#"\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2})\b"#, .dayMonthShortYear),
            (#"\b(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+(\d{4})\b"#, .dayMonthNameYear),
            (#"\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+(\d{1,2}),?\s+(\d{4})\b"#, .monthNameDayYear)
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

    private static func date(from match: NSTextCheckingResult, in text: String, kind: DateFormatKind, calendar: Calendar) -> Date? {
        func group(_ index: Int) -> String? {
            guard match.numberOfRanges > index, let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range])
        }

        var year = 0
        var month = 0
        var day = 0

        switch kind {
        case .yearMonthDay:
            year = Int(group(1) ?? "") ?? 0
            month = Int(group(2) ?? "") ?? 0
            day = Int(group(3) ?? "") ?? 0
        case .dayMonthYear:
            day = Int(group(1) ?? "") ?? 0
            month = Int(group(2) ?? "") ?? 0
            year = Int(group(3) ?? "") ?? 0
        case .dayMonthShortYear:
            day = Int(group(1) ?? "") ?? 0
            month = Int(group(2) ?? "") ?? 0
            let yy = Int(group(3) ?? "") ?? 0
            year = yy < 50 ? 2000 + yy : 1900 + yy
        case .dayMonthNameYear:
            day = Int(group(1) ?? "") ?? 0
            month = monthIndex(group(2) ?? "")
            year = Int(group(3) ?? "") ?? 0
        case .monthNameDayYear:
            month = monthIndex(group(1) ?? "")
            day = Int(group(2) ?? "") ?? 0
            year = Int(group(3) ?? "") ?? 0
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
