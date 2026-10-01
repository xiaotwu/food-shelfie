import Foundation
import SwiftData

enum Persistence {
    static let cloudKitContainerID = "iCloud.com.xiaotwu.shelfie"
    static let storeConfigurationName = "Shelfie"

    static let schema = Schema([
        CategoryRecord.self,
        LocationRecord.self,
        FoodItemRecord.self,
        SearchHistoryRecord.self,
        ShoppingItemRecord.self
    ])

    static var iCloudSyncEnabled: Bool {
        SettingsStore.iCloudSyncEnabled(
            in: UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        )
    }

    static func makeContainer(iCloud: Bool) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            storeConfigurationName,
            schema: schema,
            url: AppGroup.storeURL,
            cloudKitDatabase: iCloud ? .private(cloudKitContainerID) : .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    // Never replace a failed persistent store with a temporary, writable inventory.
    // The app presents recovery UI and leaves the on-disk store untouched.
}
