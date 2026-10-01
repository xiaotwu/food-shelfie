import XCTest
@testable import Shelfie

@MainActor
final class SettingsPreferenceTests: XCTestCase {
    private func withDefaults(_ action: (UserDefaults) async throws -> Void) async throws {
        let name = "ShelfieSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try await action(defaults)
    }

    func testCorruptPersistedReminderValuesRecoverToSafeDefaults() async throws {
        try await withDefaults { defaults in
            defaults.set(45, forKey: "reminderHour")
            defaults.set(-1, forKey: "reminderMinute")
            defaults.set(999, forKey: "warningDays")
            defaults.set(-30, forKey: "autoDelete")
            let settings = SettingsStore(defaults: defaults)
            XCTAssertEqual(settings.reminderHour, 7)
            XCTAssertEqual(settings.reminderMinute, 30)
            XCTAssertEqual(settings.warningDays, 3)
            XCTAssertEqual(settings.autoDeleteConsumedAfterDays, 0)
            settings.persist()
            XCTAssertEqual(defaults.integer(forKey: "reminderHour"), 7)
            XCTAssertEqual(defaults.integer(forKey: "autoDelete"), 0)
        }
    }

    func testValidPreferencesRoundTripIncludingZeroDayWarning() async throws {
        try await withDefaults { defaults in
            let settings = SettingsStore(defaults: defaults)
            settings.reminderHour = 23
            settings.reminderMinute = 59
            settings.warningDays = 0
            settings.autoDeleteConsumedAfterDays = 90
            settings.persist()
            let loaded = SettingsStore(defaults: defaults)
            XCTAssertEqual(loaded.reminderHour, 23)
            XCTAssertEqual(loaded.reminderMinute, 59)
            XCTAssertEqual(loaded.warningDays, 0)
            XCTAssertEqual(loaded.autoDeleteConsumedAfterDays, 90)
        }
    }

    func testFailedAuthenticationNeverPersistsAnEnabledLock() async throws {
        try await withDefaults { defaults in
            let settings = SettingsStore(defaults: defaults)
            let result = await settings.enableAppLock { false }
            XCTAssertFalse(result)
            XCTAssertFalse(settings.biometricLockEnabled)
            XCTAssertFalse(SettingsStore(defaults: defaults).biometricLockEnabled)
        }
    }

    func testCancelledAuthenticationNeverPersistsAnEnabledLock() async throws {
        try await withDefaults { defaults in
            let settings = SettingsStore(defaults: defaults)
            let task = Task { @MainActor in
                await settings.enableAppLock {
                    withUnsafeCurrentTask { $0?.cancel() }
                    return true
                }
            }
            let result = await task.value
            XCTAssertFalse(result)
            XCTAssertFalse(settings.biometricLockEnabled)
            XCTAssertFalse(SettingsStore(defaults: defaults).biometricLockEnabled)
        }
    }

    func testSuccessfulAuthenticationPersistsLockAndKeepsCurrentSessionUnlocked() async throws {
        try await withDefaults { defaults in
            let settings = SettingsStore(defaults: defaults)
            let result = await settings.enableAppLock { true }
            XCTAssertTrue(result)
            XCTAssertTrue(settings.biometricLockEnabled)
            XCTAssertTrue(settings.isUnlocked)
            let loaded = SettingsStore(defaults: defaults)
            XCTAssertTrue(loaded.biometricLockEnabled)
            XCTAssertFalse(loaded.isUnlocked)
        }
    }
    func testInventoryBadgeDefaultAndAllStylesPersist() async throws {
        try await withDefaults { defaults in
            XCTAssertEqual(SettingsStore(defaults: defaults).inventoryBadgeStyle, .number)
            for style in InventoryBadgeStyle.allCases {
                let settings = SettingsStore(defaults: defaults)
                settings.inventoryBadgeStyle = style
                settings.persist()
                XCTAssertEqual(SettingsStore(defaults: defaults).inventoryBadgeStyle, style)
            }
            defaults.set("obsolete-style", forKey: "inventoryBadgeStyle")
            XCTAssertEqual(SettingsStore(defaults: defaults).inventoryBadgeStyle, .number)
        }
    }

    func testGettingStartedDismissalPersistsAcrossLaunches() async throws {
        try await withDefaults { defaults in
            let settings = SettingsStore(defaults: defaults)
            XCTAssertFalse(settings.hasDismissedGettingStarted, "First-use tips are available without a required onboarding flow.")
            settings.dismissGettingStarted()
            XCTAssertTrue(settings.hasDismissedGettingStarted)
            XCTAssertTrue(SettingsStore(defaults: defaults).hasDismissedGettingStarted,
                          "Skipping a tip must stay skipped after restarting the app.")
        }
    }

    func testGettingStartedCanBeRestoredWithoutChangingOtherPreferences() async throws {
        try await withDefaults { defaults in
            let settings = SettingsStore(defaults: defaults)
            settings.language = .chineseSimplified
            settings.warningDays = 0
            settings.inventoryBadgeStyle = .dot
            settings.dismissGettingStarted()
            settings.resetGettingStarted()
            let restored = SettingsStore(defaults: defaults)
            XCTAssertFalse(restored.hasDismissedGettingStarted)
            XCTAssertEqual(restored.language, settings.language)
            XCTAssertEqual(restored.warningDays, 0)
            XCTAssertEqual(restored.inventoryBadgeStyle, .dot)
            XCTAssertFalse(restored.iCloudSyncEnabled, "Re-enabling help must never opt the user into cloud sync.")
        }
    }

}
