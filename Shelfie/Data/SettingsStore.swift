import Foundation
import SwiftUI

@Observable
final class SettingsStore {
    var themeMode: ThemeMode
    var seedColor: SeedColor
    var language: AppLanguage
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
    var iCloudSyncEnabled: Bool
    var isTabBarHidden: Bool = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard) {
        self.defaults = defaults
        self.themeMode = ThemeMode(rawValue: defaults.string(forKey: Keys.themeMode) ?? "") ?? .system
        self.seedColor = SeedColor(rawValue: defaults.string(forKey: Keys.seedColor) ?? "") ?? .emerald
        self.language = AppLanguage.persisted(defaults.string(forKey: Keys.language))
        self.groupByCategory = defaults.bool(forKey: Keys.groupByCategory)
        self.biometricLockEnabled = defaults.bool(forKey: Keys.biometric)
        self.notificationsEnabled = defaults.object(forKey: Keys.notifications) as? Bool ?? true
        self.weeklyReportEnabled = defaults.object(forKey: Keys.weeklyReport) as? Bool ?? true
        self.reminderHour = defaults.object(forKey: Keys.hour) as? Int ?? 7
        self.reminderMinute = defaults.object(forKey: Keys.minute) as? Int ?? 30
        self.warningDays = defaults.object(forKey: Keys.warningDays) as? Int ?? 3
        self.autoDeleteConsumedAfterDays = defaults.object(forKey: Keys.autoDelete) as? Int ?? 0
        self.cameraPolicyAccepted = defaults.bool(forKey: Keys.cameraPolicy)
        self.iCloudSyncEnabled = defaults.object(forKey: Keys.iCloudSync) as? Bool ?? true
        self.isUnlocked = !(defaults.bool(forKey: Keys.biometric))
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

    func persist() {
        defaults.set(themeMode.rawValue, forKey: Keys.themeMode)
        defaults.set(seedColor.rawValue, forKey: Keys.seedColor)
        defaults.set(language.rawValue, forKey: Keys.language)
        defaults.set(groupByCategory, forKey: Keys.groupByCategory)
        defaults.set(biometricLockEnabled, forKey: Keys.biometric)
        defaults.set(notificationsEnabled, forKey: Keys.notifications)
        defaults.set(weeklyReportEnabled, forKey: Keys.weeklyReport)
        defaults.set(reminderHour, forKey: Keys.hour)
        defaults.set(reminderMinute, forKey: Keys.minute)
        defaults.set(warningDays, forKey: Keys.warningDays)
        defaults.set(autoDeleteConsumedAfterDays, forKey: Keys.autoDelete)
        defaults.set(cameraPolicyAccepted, forKey: Keys.cameraPolicy)
        defaults.set(iCloudSyncEnabled, forKey: Keys.iCloudSync)
    }

    private enum Keys {
        static let themeMode = "themeMode"
        static let seedColor = "seedColor"
        static let language = "language"
        static let groupByCategory = "groupByCategory"
        static let biometric = "biometric"
        static let notifications = "notifications"
        static let weeklyReport = "weeklyReport"
        static let hour = "reminderHour"
        static let minute = "reminderMinute"
        static let warningDays = "warningDays"
        static let autoDelete = "autoDelete"
        static let cameraPolicy = "cameraPolicy"
        static let iCloudSync = "iCloudSync"
    }
}
