import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale

    var body: some View {
        ZStack {
            TabView {
                InventoryView()
                    .tabItem {
                        Image(systemName: "refrigerator.fill")
                            .accessibilityLabel(locale.text("tab.shelf"))
                    }
                AnalyticsView()
                    .tabItem {
                        Image(systemName: "chart.bar.fill")
                            .accessibilityLabel(locale.text("tab.insights"))
                    }
                SettingsHomeView()
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                            .accessibilityLabel(locale.text("tab.settings"))
                    }
            }

            if settings.biometricLockEnabled && !settings.isUnlocked {
                AppLockView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            }
        }
        .animation(Motion.soft, value: settings.isUnlocked)
        .onAppear {
            SeedData.bootstrap(context: modelContext)
            SeedData.pruneResolved(context: modelContext, afterDays: settings.autoDeleteConsumedAfterDays)
            WidgetSnapshotWriter.refresh(context: modelContext)
            Task {
                await NotificationScheduler.reschedule(settings: settings, context: modelContext)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, settings.biometricLockEnabled {
                withAnimation(Motion.soft) {
                    settings.isUnlocked = false
                }
            }
            if phase == .active {
                WidgetSnapshotWriter.refresh(context: modelContext)
            }
        }
        .onChange(of: settings.language) { _, _ in
            Task { await NotificationScheduler.reschedule(settings: settings, context: modelContext) }
        }
    }
}
