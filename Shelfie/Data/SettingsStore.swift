import Foundation
import SwiftUI

enum InventoryBadgeStyle: String, CaseIterable, Identifiable {
    case number, dot, off
    var id: String { rawValue }
    func title(locale: Locale) -> String { locale.text("settings.inventoryBadge." + rawValue) }
}

@Observable
final class SettingsStore {
    var themeMode: ThemeMode
    var seedColor: SeedColor
    var language: AppLanguage
    var inventoryBadgeStyle: InventoryBadgeStyle
    var groupByCategory: Bool
    var biometricLockEnabled: Bool
    var notificationsEnabled: Bool
    var weeklyReportEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var warningDays: Int
    var autoDeleteConsumedAfterDays: Int
    var isUnlocked: Bool
    var cameraPolicyAccepted: Bool
    var hasDismissedGettingStarted: Bool
    var iCloudSyncEnabled: Bool
    var isTabBarHidden: Bool = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard) {
        self.defaults = defaults
        self.themeMode = ThemeMode(rawValue: defaults.string(forKey: Keys.themeMode) ?? "") ?? .system
        self.seedColor = SeedColor(rawValue: defaults.string(forKey: Keys.seedColor) ?? "") ?? .emerald
        self.language = AppLanguage.persisted(defaults.string(forKey: Keys.language))
        self.inventoryBadgeStyle = InventoryBadgeStyle(rawValue: defaults.string(forKey: Keys.inventoryBadge) ?? "") ?? .number
        self.groupByCategory = defaults.bool(forKey: Keys.groupByCategory)
        self.biometricLockEnabled = defaults.bool(forKey: Keys.biometric)
        self.notificationsEnabled = defaults.object(forKey: Keys.notifications) as? Bool ?? true
        self.weeklyReportEnabled = defaults.object(forKey: Keys.weeklyReport) as? Bool ?? true
        self.reminderHour = Self.valid(defaults.object(forKey: Keys.hour) as? Int, in: 0...23, fallback: 7)
        self.reminderMinute = Self.valid(defaults.object(forKey: Keys.minute) as? Int, in: 0...59, fallback: 30)
        self.warningDays = Self.valid(defaults.object(forKey: Keys.warningDays) as? Int, in: 0...14, fallback: 3)
        self.autoDeleteConsumedAfterDays = Self.valid(defaults.object(forKey: Keys.autoDelete) as? Int, in: 0...90, fallback: 0)
        self.cameraPolicyAccepted = defaults.bool(forKey: Keys.cameraPolicy)
        self.hasDismissedGettingStarted = defaults.object(forKey: Keys.gettingStartedDismissed) as? Bool ?? false
        self.iCloudSyncEnabled = Self.iCloudSyncEnabled(in: defaults)
        self.isUnlocked = !(defaults.bool(forKey: Keys.biometric))
    }

    static func iCloudSyncEnabled(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: Keys.iCloudSync) as? Bool ?? false
    }

    var preferredColorScheme: ColorScheme? { themeMode.colorScheme }
    var tint: Color { seedColor.color }
    var locale: Locale { language.locale }
    var calendar: Calendar { locale.gregorianCalendar }

    var reminderDate: Date {
        get {
            Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? Date()
        }
        set {
            reminderHour = Calendar.current.component(.hour, from: newValue)
            reminderMinute = Calendar.current.component(.minute, from: newValue)
            persist()
        }
    }

    /// Authentication failure or cancellation must never persist an enabled lock.
    @MainActor
    func enableAppLock(authorize: () async -> Bool) async -> Bool {
        let authorized = await authorize()
        guard authorized, !Task.isCancelled else { return false }
        biometricLockEnabled = true
        isUnlocked = true
        persist()
        return true
    }

    /// A local preference only; skipping tips never blocks a feature or asks for permission.
    func dismissGettingStarted() {
        hasDismissedGettingStarted = true
        persist()
    }

    func resetGettingStarted() {
        hasDismissedGettingStarted = false
        persist()
    }

    private static func valid(_ value: Int?, in range: ClosedRange<Int>, fallback: Int) -> Int {
        guard let value, range.contains(value) else { return fallback }
        return value
    }

    func persist() {
        reminderHour = Self.valid(reminderHour, in: 0...23, fallback: 7)
        reminderMinute = Self.valid(reminderMinute, in: 0...59, fallback: 30)
        warningDays = Self.valid(warningDays, in: 0...14, fallback: 3)
        autoDeleteConsumedAfterDays = Self.valid(autoDeleteConsumedAfterDays, in: 0...90, fallback: 0)
        defaults.set(themeMode.rawValue, forKey: Keys.themeMode)
        defaults.set(seedColor.rawValue, forKey: Keys.seedColor)
        defaults.set(language.rawValue, forKey: Keys.language)
        defaults.set(inventoryBadgeStyle.rawValue, forKey: Keys.inventoryBadge)
        defaults.set(groupByCategory, forKey: Keys.groupByCategory)
        defaults.set(biometricLockEnabled, forKey: Keys.biometric)
        defaults.set(notificationsEnabled, forKey: Keys.notifications)
        defaults.set(weeklyReportEnabled, forKey: Keys.weeklyReport)
        defaults.set(reminderHour, forKey: Keys.hour)
        defaults.set(reminderMinute, forKey: Keys.minute)
        defaults.set(warningDays, forKey: Keys.warningDays)
        defaults.set(autoDeleteConsumedAfterDays, forKey: Keys.autoDelete)
        defaults.set(cameraPolicyAccepted, forKey: Keys.cameraPolicy)
        defaults.set(hasDismissedGettingStarted, forKey: Keys.gettingStartedDismissed)
        defaults.set(iCloudSyncEnabled, forKey: Keys.iCloudSync)
    }

    private enum Keys {
        static let themeMode = "themeMode"
        static let seedColor = "seedColor"
        static let language = "language"
        static let inventoryBadge = "inventoryBadgeStyle"
        static let groupByCategory = "groupByCategory"
        static let biometric = "biometric"
        static let notifications = "notifications"
        static let weeklyReport = "weeklyReport"
        static let hour = "reminderHour"
        static let minute = "reminderMinute"
        static let warningDays = "warningDays"
        static let autoDelete = "autoDelete"
        static let cameraPolicy = "cameraPolicy"
        static let gettingStartedDismissed = "hasDismissedGettingStarted"
        static let iCloudSync = "iCloudSync"
    }
}
