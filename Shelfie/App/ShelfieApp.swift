import SwiftData
import SwiftUI

@main
struct ShelfieApp: App {
    @State private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(\.locale, settings.locale)
                .environment(\.calendar, settings.calendar)
                .tint(settings.tint)
                .preferredColorScheme(settings.preferredColorScheme)
                .animation(Motion.soft, value: settings.language)
                .animation(Motion.soft, value: settings.themeMode)
                .animation(Motion.soft, value: settings.seedColor)
        }
        .modelContainer(Persistence.container)
    }
}
