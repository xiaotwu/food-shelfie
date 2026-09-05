import SwiftData
import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case shelf = 0
    case insights = 1
    case settings = 2

    var id: Int { rawValue }

    var icon: String {
        switch self {
        case .shelf: "refrigerator.fill"
        case .insights: "chart.bar.fill"
        case .settings: "gearshape.fill"
        }
    }

    func title(locale: Locale) -> String {
        switch self {
        case .shelf: locale.text("tab.shelf")
        case .insights: locale.text("tab.insights")
        case .settings: locale.text("tab.settings")
        }
    }
}

struct RootView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Query private var foods: [FoodItemRecord]
    @Namespace private var tabNamespace

    @State private var selectedTab: AppTab = .shelf

    private var urgentOrExpiredCount: Int {
        foods.filter { $0.status == .active && ($0.freshness == .urgent || $0.freshness == .expired) }.count
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main tab content, hiding native tab bar
            TabView(selection: $selectedTab) {
                InventoryView()
                    .tag(AppTab.shelf)
                    .toolbar(.hidden, for: .tabBar)

                AnalyticsView()
                    .tag(AppTab.insights)
                    .toolbar(.hidden, for: .tabBar)

                SettingsHomeView()
                    .tag(AppTab.settings)
                    .toolbar(.hidden, for: .tabBar)
            }
            .background {
                // Ambient mesh canvas background
                Glass.ambientBackground(tint: settings.tint)
            }
            .ignoresSafeArea(edges: .bottom)

            // Floating liquid glass island dock
            if !settings.isTabBarHidden {
                floatingTabIsland
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if settings.biometricLockEnabled && !settings.isUnlocked {
                AppLockView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            }
        }
        .animation(Motion.liquidSpring, value: selectedTab)
        .animation(Motion.liquidSpring, value: settings.isTabBarHidden)
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

    private var floatingTabIsland: some View {
        HStack(spacing: 8) {
            ForEach(AppTab.allCases) { tab in
                let isSelected = selectedTab == tab
                Button {
                    if selectedTab != tab {
                        Motion.hapticSelection()
                        withAnimation(Motion.liquidSpring) {
                            selectedTab = tab
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: isSelected ? .bold : .medium))
                                .symbolEffect(.bounce, value: isSelected)

                            if tab == .shelf && urgentOrExpiredCount > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 7, height: 7)
                                    .offset(x: 4, y: -2)
                            }
                        }

                        if isSelected {
                            Text(tab.title(locale: locale))
                                .font(.subheadline.weight(.semibold))
                                .contentTransition(.opacity)
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(isSelected ? settings.tint : .secondary)
                    .padding(.horizontal, isSelected ? 18 : 14)
                    .padding(.vertical, 12)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(settings.tint.opacity(0.15))
                                .overlay {
                                    Capsule()
                                        .strokeBorder(settings.tint.opacity(0.32), lineWidth: 0.75)
                                }
                                .matchedGeometryEffect(id: "tab-island-selection", in: tabNamespace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.45), location: 0),
                                    .init(color: .white.opacity(0.12), location: 0.5),
                                    .init(color: .white.opacity(0.2), location: 1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                }
                .shadow(color: settings.tint.opacity(0.18), radius: 20, x: 0, y: 8)
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
    }
}
