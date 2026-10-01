import Foundation

/// Packaging dates are suggestions for review, never an instruction to save a date.
enum DateParser {
    private static let expiryKeywords = ["best before date", "best before", "expiration", "expiry", "best by", "use by", "exp", "bbe", "bbf", "until", "有效期至", "有效日期", "保质期至", "保質期至", "到期日", "有效期", "截止日期", "赏味期限", "賞味期限", "食用期限"]
    private static let productionKeywords = ["manufactured", "production", "packed on", "packed", "mfg", "mfd", "prod", "pdt", "生产日期", "生產日期", "制造日期", "製造日期", "包装日期", "包裝日期", "生产", "生產"]

    private enum Classification { case expiry, production }
    private struct Match {
        let values: [Date]
        let range: Range<String.Index>
    }

    static func parseFoodDates(from rawText: String, now: Date = .now, calendar: Calendar = .current, locale: Locale = .current) -> FoodDateScan {
        let matches = extractDates(from: rawText, calendar: calendar)
        var production: Date?
        var labelledExpiry: [Date] = []
        var unlabelled: [Date] = []
        for match in matches {
            switch classify(dateRange: match.range, in: rawText) {
            case .production:
                // An ambiguous production date must not be silently used as a purchase date.
                if match.values.count == 1 { production = max(production ?? match.values[0], match.values[0]) }
            case .expiry:
                labelledExpiry.append(contentsOf: match.values)
            case nil:
                unlabelled.append(contentsOf: match.values)
            }
        }
        var candidates = labelledExpiry
        if candidates.isEmpty {
            // Keep both interpretations of ambiguous dates, even if only one is in the future.
            let future = unlabelled.filter { calendar.startOfDay(for: $0) >= calendar.startOfDay(for: now) }
            candidates = future.isEmpty ? unlabelled : matches
                .filter { classify(dateRange: $0.range, in: rawText) == nil && $0.values.contains(where: { future.contains($0) }) }
                .flatMap(\.values)
        }
        candidates = Array(Set(candidates)).sorted()
        return FoodDateScan(
            productionDate: production,
            expiryDate: candidates.count == 1 ? candidates.first : nil,
            rawText: rawText,
            expiryCandidates: candidates,
            requiresConfirmation: !candidates.isEmpty
        )
    }

    private static func classify(dateRange: Range<String.Index>, in text: String) -> Classification? {
        let lineStart = text[..<dateRange.lowerBound].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
        let prefix = String(text[lineStart..<dateRange.lowerBound].suffix(48))
        func distance(_ keywords: [String]) -> Int? {
            keywords.compactMap { keyword in
                prefix.range(of: keyword, options: [.caseInsensitive, .backwards]).map {
                    prefix.distance(from: $0.upperBound, to: prefix.endIndex)
                }
            }.min()
        }
        let expiryDistance = distance(expiryKeywords)
        let productionDistance = distance(productionKeywords)
        if let expiryDistance { return expiryDistance <= (productionDistance ?? Int.max) ? .expiry : .production }
        if productionDistance != nil { return .production }
        let lineEnd = text[dateRange.upperBound...].firstIndex(of: "\n") ?? text.endIndex
        let suffix = String(text[dateRange.upperBound..<lineEnd].prefix(18))
        let expiry = expiryKeywords.contains { suffix.range(of: $0, options: .caseInsensitive) != nil }
        let production = productionKeywords.contains { suffix.range(of: $0, options: .caseInsensitive) != nil }
        return expiry && !production ? .expiry : production && !expiry ? .production : nil
    }

    private static func extractDates(from text: String, calendar: Calendar) -> [Match] {
        let patterns = [
            (#"(?<!\d)(\d{4})[-/.年]\s*(\d{1,2})[-/.月]\s*(\d{1,2})日?(?!\d)"#, 0),
            (#"(?<!\d)(\d{1,2})([-/.])(\d{1,2})\2(\d{4}|\d{2})(?!\d)"#, 1),
            (#"\b(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+(\d{4})\b"#, 2),
            (#"\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+(\d{1,2}),?\s+(\d{4})\b"#, 3)
        ]
        var result: [Match] = []
        for (pattern, kind) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let range = Range(match.range, in: text), !result.contains(where: { $0.range.overlaps(range) }) else { continue }
                func group(_ index: Int) -> String {
                    Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
                }
                func integer(_ index: Int) -> Int { Int(group(index)) ?? 0 }
                var triples: [(Int, Int, Int)] = []
                switch kind {
                case 0: triples = [(integer(1), integer(2), integer(3))]
                case 1:
                    let yearValue = integer(4)
                    let year = group(4).count == 2 ? (yearValue < 50 ? 2000 : 1900) + yearValue : yearValue
                    triples = [(year, integer(3), integer(1))]
                    // Slashes commonly mean either DD/MM or MM/DD. Never infer from locale.
                    if group(2) == "/" { triples.append((year, integer(1), integer(3))) }
                case 2: triples = [(integer(3), monthIndex(group(2)), integer(1))]
                default: triples = [(integer(3), monthIndex(group(1)), integer(2))]
                }
                let values = Array(Set(triples.compactMap { strictDate(year: $0.0, month: $0.1, day: $0.2, calendar: calendar) })).sorted()
                if !values.isEmpty { result.append(Match(values: values, range: range)) }
            }
        }
        return result.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    private static func strictDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        guard (1971...9999).contains(year), (1...12).contains(month), (1...31).contains(day),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        let roundTrip = calendar.dateComponents([.year, .month, .day], from: date)
        guard roundTrip.year == year, roundTrip.month == month, roundTrip.day == day else { return nil }
        return date
    }

    private static func monthIndex(_ text: String) -> Int {
        ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"].firstIndex(of: String(text.prefix(3)).lowercased()).map { $0 + 1 } ?? 0
    }
}
