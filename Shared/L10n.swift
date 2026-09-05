import Foundation

enum L10n {
    /// Looks up the translation for the given key by explicitly loading the
    /// .lproj bundle for the resolved language. The `locale` parameter of
    /// `String(localized:locale:)` only controls formatting, not which
    /// localization bundle is read — the bundle is chosen from the process
    /// locale. To honor the in-app language setting while the system language
    /// differs, we resolve the bundle ourselves.
    static func tr(_ key: String, locale: Locale) -> String {
        let bundle = localizedBundle(for: resolved(locale))
        let value = bundle.localizedString(forKey: key, value: key, table: "Localizable")
        return value != key ? value : key
    }

    static func format(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        let resolvedLocale = resolved(locale)
        return String(format: tr(key, locale: resolvedLocale), locale: resolvedLocale, arguments: arguments)
    }

    static func resolved(_ locale: Locale) -> Locale {
        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
        if identifier.lowercased().hasPrefix("zh-hans") || identifier == "zh-CN" || identifier == "zh" {
            return .simplifiedChinese
        }
        if identifier.lowercased().hasPrefix("en") {
            return .englishUS
        }
        return locale
    }

    private static func localizedBundle(for locale: Locale) -> Bundle {
        let main = Bundle.main
        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
        let candidates: [String]
        if identifier.lowercased().hasPrefix("zh") {
            candidates = ["zh-Hans", "zh_CN", "zh-CN", "zh"]
        } else {
            candidates = ["en-US", "en", "Base"]
        }
        for candidate in candidates {
            if let path = main.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return main
    }
}

extension Locale {
    static var englishUS: Locale { Locale(identifier: "en-US") }
    static var simplifiedChinese: Locale { Locale(identifier: "zh-Hans") }

    func text(_ key: String) -> String {
        L10n.tr(key, locale: self)
    }

    func format(_ key: String, _ arguments: CVarArg...) -> String {
        let locale = L10n.resolved(self)
        return String(format: L10n.tr(key, locale: locale), locale: locale, arguments: arguments)
    }

    var gregorianCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = L10n.resolved(self)
        calendar.timeZone = .current
        return calendar
    }
}

extension Date {
    func localizedDate(_ locale: Locale, date: Date.FormatStyle.DateStyle = .abbreviated) -> String {
        formatted(Date.FormatStyle(date: date, time: .omitted, locale: L10n.resolved(locale)))
    }
}

