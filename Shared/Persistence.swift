import Foundation
import SwiftData

enum Persistence {
    static let cloudKitContainerID = "iCloud.com.xiaotwu.shelfie"

    static let schema = Schema([
        CategoryRecord.self,
        LocationRecord.self,
        FoodItemRecord.self,
        SearchHistoryRecord.self
    ])

    static var iCloudSyncEnabled: Bool {
        (UserDefaults(suiteName: AppGroup.identifier) ?? .standard).object(forKey: "iCloudSync") as? Bool ?? true
    }

    static let container: ModelContainer = {
        makeContainer(iCloud: iCloudSyncEnabled)
    }()

    static func makeContainer(iCloud: Bool) -> ModelContainer {
        if iCloud {
            let cloud = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
            if let container = try? ModelContainer(for: schema, configurations: [cloud]) {
                return container
            }
        }

        let local = ModelConfiguration(
            schema: schema,
            url: AppGroup.storeURL,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [local])
        } catch {
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            do {
                return try ModelContainer(for: schema, configurations: [memory])
            } catch {
                fatalError("Unable to create Shelfie store: \(error)")
            }
        }
    }
}
