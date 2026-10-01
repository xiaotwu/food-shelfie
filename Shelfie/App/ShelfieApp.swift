import SwiftData
import SwiftUI
import UserNotifications
#if DEBUG
import CoreData
#endif

@main
struct ShelfieApp: App {
    @UIApplicationDelegateAdaptor(ShelfieNotificationDelegate.self) private var notificationDelegate
    @State private var navigation = AppNavigationState()
    @State private var settings: SettingsStore
    @State private var container: ModelContainer?
    @State private var storeGeneration = 0
    @State private var iCloudError: String?

    init() {
        let settings = SettingsStore()
        _settings = State(initialValue: settings)
        if Self.schemaMaintenanceRequested {
            _container = State(initialValue: nil)
            return
        }
        do {
            _container = State(initialValue: try Persistence.makeContainer(iCloud: settings.iCloudSyncEnabled))
        } catch {
            _container = State(initialValue: nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if Self.schemaMaintenanceRequested {
                    Text("Preparing development CloudKit schema…")
#if DEBUG
                        .task {
                            if #available(iOS 26.0, *) { CloudSchemaSetup.run() }
                        }
#endif
                } else if let container {
                    RootView()
                        .modelContainer(container)
                } else {
                    ContentUnavailableView {
                        Label(settings.locale.text("storage.errorTitle"), systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text(settings.locale.text("storage.errorBody"))
                    } actions: {
                        Button(settings.locale.text("storage.retry")) {
                            applyiCloudSync(settings.iCloudSyncEnabled)
                        }
                    }
                }
            }
                .id(storeGeneration)
                .environment(settings)
                .environment(navigation)
                .environment(\.locale, settings.locale)
                .environment(\.calendar, settings.calendar)
                .tint(settings.tint)
                .preferredColorScheme(settings.preferredColorScheme)
                .animation(Motion.soft, value: settings.language)
                .animation(Motion.soft, value: settings.themeMode)
                .animation(Motion.soft, value: settings.seedColor)
                .onAppear { configureNotificationDelegate() }
                .onChange(of: storeGeneration) { _, _ in configureNotificationDelegate() }
                .onOpenURL { url in
                    if let route = ShelfieRoute(url: url) { navigation.open(route) }
                }
                .onChange(of: settings.iCloudSyncEnabled) { _, enabled in
                    applyiCloudSync(enabled)
                }
                .alert(settings.locale.text("settings.iCloudErrorTitle"), isPresented: iCloudErrorBinding) {
                    Button(settings.locale.text("common.ok"), role: .cancel) {}
                } message: {
                    Text(iCloudError ?? "")
                }
        }
    }

    private static var schemaMaintenanceRequested: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--initialize-cloudkit-schema")
#else
        false
#endif
    }

    private func configureNotificationDelegate() {
        guard !Self.schemaMaintenanceRequested else { return }
        notificationDelegate.configure(container: container, settings: settings, navigation: navigation)
    }

    private var iCloudErrorBinding: Binding<Bool> {
        Binding(
            get: { iCloudError != nil },
            set: { if !$0 { iCloudError = nil } }
        )
    }

    private func applyiCloudSync(_ enabled: Bool) {
        settings.persist()
        do {
            container = try Persistence.makeContainer(iCloud: enabled)
            storeGeneration += 1
        } catch {
            if enabled {
                settings.iCloudSyncEnabled = false
                settings.persist()
                iCloudError = settings.locale.text("settings.iCloudError")
            }
            container = try? Persistence.makeContainer(iCloud: false)
            storeGeneration += 1
        }
    }
}

/// Notifications use foreground actions so a failed write can be reported to the user.
final class ShelfieNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    @MainActor private var container: ModelContainer?
    @MainActor private var settings: SettingsStore?
    @MainActor private var navigation: AppNavigationState?
    @MainActor private var deferredResponses: [UNNotificationResponse] = []

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    @MainActor
    func configure(container: ModelContainer?, settings: SettingsStore, navigation: AppNavigationState) {
        self.container = container
        self.settings = settings
        self.navigation = navigation
        NotificationScheduler.registerActions(locale: settings.locale)
        guard container != nil else { return }
        let responses = deferredResponses
        deferredResponses.removeAll()
        for response in responses { handle(response) }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            handle(response)
            completionHandler()
        }
    }

    @MainActor
    private func handle(_ response: UNNotificationResponse) {
        guard response.actionIdentifier != UNNotificationDismissActionIdentifier else { return }
        guard let container, let settings, let navigation else {
            deferredResponses.append(response)
            return
        }
        guard let rawID = response.notification.request.content.userInfo["foodID"] as? String,
              let foodID = UUID(uuidString: rawID) else {
            navigation.open(.shelf)
            return
        }
        let status: FoodStatus?
        switch response.actionIdentifier {
        case NotificationScheduler.eatenAction: status = .consumed
        case NotificationScheduler.discardedAction: status = .wasted
        default: status = nil
        }
        guard let status else { navigation.open(.food(foodID)); return }
        do {
            try NotificationScheduler.resolve(foodID: foodID, status: status, context: container.mainContext)
            navigation.open(.shelf)
            WidgetSnapshotWriter.refresh(context: container.mainContext)
            Task { await NotificationScheduler.reschedule(settings: settings, context: container.mainContext) }
        } catch {
            if error is NotificationScheduler.ActionError {
                navigation.actionError = settings.locale.text("notif.missingFood")
            } else {
                navigation.actionError = error.localizedDescription
            }
        }
    }
}

#if DEBUG
// Explicit developer maintenance command. Uses an isolated empty store, never inventory.
@available(iOS 26.0, *)
private enum CloudSchemaSetup {
    static func run() {
        DispatchQueue.global(qos: .utility).async {
            do {
                try autoreleasepool {
                    guard let model = NSManagedObjectModel.makeManagedObjectModel(for: Persistence.schema) else {
                        throw CocoaError(.persistentStoreInvalidType)
                    }
                    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    defer { try? FileManager.default.removeItem(at: directory) }
                    let description = NSPersistentStoreDescription(url: directory.appendingPathComponent("Schema.sqlite"))
                    description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: Persistence.cloudKitContainerID)
                    description.shouldAddStoreAsynchronously = false
                    let container = NSPersistentCloudKitContainer(name: "ShelfieSchema", managedObjectModel: model)
                    container.persistentStoreDescriptions = [description]
                    var loadError: Error?
                    container.loadPersistentStores { _, error in loadError = error }
                    if let loadError { throw loadError }
                    try container.initializeCloudKitSchema()
                    for store in container.persistentStoreCoordinator.persistentStores {
                        try container.persistentStoreCoordinator.remove(store)
                    }
                    print("SHELFIE_SCHEMA_INITIALIZED")
                }
            } catch {
                print("SHELFIE_SCHEMA_FAILED: \(error)")
            }
        }
    }
}
#endif
