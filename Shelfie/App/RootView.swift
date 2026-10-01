import Combine
import CoreData
import Observation
import SwiftData
import SwiftUI
import UIKit


/// Only Shelfie's documented food and shelf routes are accepted.
enum ShelfieRoute: Equatable {
    case food(UUID)
    case shelf

    init?(url: URL) {
        guard url.scheme?.lowercased() == "shelfie", url.user == nil, url.password == nil,
              url.port == nil, url.query == nil, url.fragment == nil else { return nil }
        let parts = url.path.split(separator: "/", omittingEmptySubsequences: true)
        if url.host?.lowercased() == "food", parts.count == 1, let id = UUID(uuidString: String(parts[0])) {
            self = .food(id)
        } else if url.host?.lowercased() == "shelf", parts.isEmpty {
            self = .shelf
        } else { return nil }
    }
}

enum GlobalShelfAction: Equatable {
    case search
    case add
    case scan
    case repeatPurchase(UUID)
    case revealShelf
}

struct GlobalShelfActionRequest: Identifiable, Equatable {
    let id: UUID
    let action: GlobalShelfAction
}

@Observable
final class AppNavigationState {
    var foodID: UUID?
    var actionError: String?
    var shelfRequest = UUID()
    var selectedTab: AppTab = .shelf
    var shelfActionRequest: GlobalShelfActionRequest?
    var sortMode: InventorySortMode = .byExpiry
    var showExpiredOnly = false

    func requestShelfAction(_ action: GlobalShelfAction) {
        foodID = nil
        selectedTab = .shelf
        shelfActionRequest = GlobalShelfActionRequest(id: UUID(), action: action)
    }

    func completeShelfAction(_ id: UUID) {
        guard shelfActionRequest?.id == id else { return }
        shelfActionRequest = nil
    }

    func chooseSort(_ mode: InventorySortMode) {
        sortMode = mode
        requestShelfAction(.revealShelf)
    }

    func setExpiredOnly(_ enabled: Bool) {
        showExpiredOnly = enabled
        requestShelfAction(.revealShelf)
    }

    func open(_ route: ShelfieRoute) {
        shelfActionRequest = nil
        selectedTab = .shelf
        switch route {
        case .food(let id): foodID = id
        case .shelf: foodID = nil; shelfRequest = UUID()
        }
    }
}

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

@MainActor
struct RootView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(AppNavigationState.self) private var navigation
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var foods: [FoodItemRecord]
    @Namespace private var tabNamespace


    private var activeFoodCount: Int {
        foods.filter { $0.status == .active }.count
    }

    var body: some View {
        @Bindable var navigation = navigation
        ZStack(alignment: .bottom) {
            // Main tab content, hiding native tab bar
            TabView(selection: $navigation.selectedTab) {
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
        .animation(Motion.liquidSpring, value: navigation.selectedTab)
        .animation(Motion.liquidSpring, value: settings.isTabBarHidden)
        .animation(Motion.soft, value: settings.isUnlocked)
        .transaction { transaction in
            if reduceMotion { transaction.animation = nil }
        }
        .onAppear {
            do {
                try SeedData.bootstrap(context: modelContext)
                try SeedData.pruneResolved(context: modelContext, afterDays: settings.autoDeleteConsumedAfterDays)
            } catch {
                navigation.actionError = error.localizedDescription
            }
        }
        .task(id: refreshFingerprint) { await refreshRemindersAndWidgets() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, settings.biometricLockEnabled {
                withAnimation(Motion.soft) { settings.isUnlocked = false }
            }
            if phase == .active {
                Task { @MainActor in await refreshRemindersAndWidgets() }
            }
        }
        .onChange(of: navigation.foodID) { _, id in
            if id != nil { navigation.selectedTab = .shelf }
        }
        .onChange(of: navigation.shelfRequest) { _, _ in navigation.selectedTab = .shelf }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification).receive(on: RunLoop.main)) { _ in
            Task { @MainActor in await refreshRemindersAndWidgets() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange).receive(on: RunLoop.main)) { _ in
            Task { @MainActor in await refreshRemindersAndWidgets() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: RunLoop.main)) { _ in
            Task { @MainActor in
                do { try SeedData.bootstrap(context: modelContext) }
                catch { navigation.actionError = error.localizedDescription }
                await refreshRemindersAndWidgets()
            }
        }
        .alert(locale.text("operation.errorTitle"), isPresented: Binding(
            get: { navigation.actionError != nil }, set: { if !$0 { navigation.actionError = nil } }
        )) {
            Button(locale.text("common.ok"), role: .cancel) { navigation.actionError = nil }
        } message: { Text(navigation.actionError ?? "") }
    }

    private var refreshFingerprint: String {
        let records = foods.sorted { $0.id.uuidString < $1.id.uuidString }.map {
            "\($0.id)|\($0.name)|\($0.statusRaw)|\($0.effectiveExpiryDate?.timeIntervalSince1970 ?? -1)|\($0.quantity)|\($0.locationRaw)"
        }.joined(separator: ";")
        return "\(settings.language)|\(settings.warningDays)|\(settings.notificationsEnabled)|\(settings.weeklyReportEnabled)|\(settings.reminderHour):\(settings.reminderMinute)|\(records)"
    }

    @MainActor
    private func refreshRemindersAndWidgets() async {
        WidgetSnapshotWriter.refresh(context: modelContext)
        await NotificationScheduler.reschedule(settings: settings, context: modelContext)
    }

    private var floatingTabIsland: some View {
        HStack(spacing: 8) {
            ForEach(AppTab.allCases) { tab in
                let isSelected = navigation.selectedTab == tab
                Button {
                    if navigation.selectedTab != tab {
                        Motion.hapticSelection()
                        withAnimation(Motion.liquidSpring) {
                            navigation.selectedTab = tab
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: isSelected ? .bold : .medium))
                                .symbolEffect(.bounce, value: isSelected)
                                .symbolEffectsRemoved(reduceMotion)

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
                    .overlay(alignment: .topTrailing) {
                        if tab == .shelf {
                            InventoryCountBadge(count: activeFoodCount, style: settings.inventoryBadgeStyle)
                                .offset(x: 3, y: -4)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title(locale: locale))
                .accessibilityValue(tab == .shelf ? String(activeFoodCount) + " " + locale.text(activeFoodCount == 1 ? "shelf.badge.item" : "shelf.badge.items") : "")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
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


/// Each visible navigation page owns the same three controls; native Back remains intact.
private struct GlobalShelfToolbarModifier: ViewModifier {
    @Environment(AppNavigationState.self) private var navigation
    @Environment(SettingsStore.self) private var settings
    @Environment(\.locale) private var locale
    @Query(sort: \FoodItemRecord.createdAt, order: .reverse) private var foods: [FoodItemRecord]
    var title: String
    var hasBackButton: Bool
    var centersTitle: Bool
    @State private var availableWidth: CGFloat = 0
    @ScaledMetric(relativeTo: .headline) private var titleFontSize: CGFloat = 17
    var isSelectionActive: Bool
    var onCancelSelection: (() -> Void)?

    private var recentPurchases: [FoodItemRecord] {
        var names = Set<String>()
        return Array(foods.filter {
            names.insert($0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()).inserted
        }.prefix(5))
    }

    private var shouldCollapse: Bool {
        // Measure the current localized title, independent of the collapsed toolbar's width.
        // This prevents oscillation between the two presentations near the fit boundary.
        let font = UIFont.systemFont(ofSize: min(titleFontSize, 22), weight: .semibold)
        let titleWidth = (title as NSString).size(withAttributes: [.font: font]).width
        let leadingWidth: CGFloat = hasBackButton || isSelectionActive ? 90 : 0
        guard availableWidth > 0 else { return false }
        let trailingWidth: CGFloat = 172 + 24
        if centersTitle {
            // A centered title needs the same free space on each side, including native margins.
            let sideWidth = max(leadingWidth, trailingWidth) + 12
            return titleWidth > availableWidth - 2 * sideWidth
        }
        return titleWidth + leadingWidth + trailingWidth + 40 > availableWidth
    }

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
            .toolbar {
                if centersTitle {
                    ToolbarItem(id: "global.title", placement: .principal) {
                        Text(title)
                            .font(.system(size: min(titleFontSize, 22), weight: .semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("global.title")
                    }
                }
                GlobalShelfToolbar(navigation: navigation, tint: settings.tint, locale: locale,
                                   recentPurchases: recentPurchases,
                                   isCollapsed: shouldCollapse,
                                   isSelectionActive: isSelectionActive,
                                   onCancelSelection: onCancelSelection)
            }
    }
}

struct GlobalShelfToolbar: ToolbarContent {
    let navigation: AppNavigationState
    let tint: Color
    let locale: Locale
    let recentPurchases: [FoodItemRecord]
    var isCollapsed = false
    var isSelectionActive = false
    var onCancelSelection: (() -> Void)?

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if isSelectionActive {
            ToolbarItem(id: "shelf.cancelSelection", placement: .topBarLeading) {
                Button(locale.text("shelf.cancel")) { onCancelSelection?() }
                    .frame(minHeight: 44)
            }
        }
        ToolbarItem(id: "global.actions", placement: .topBarTrailing) {
            AdaptiveShelfActions(navigation: navigation, tint: tint, locale: locale,
                                 recentPurchases: recentPurchases, isCollapsed: isCollapsed)
        }
    }
}

/// Keep the controls inside a custom toolbar view. Native toolbar Menu conversion on iOS 26
/// otherwise imposes a 36-point height and asymmetric padding on the SwiftUI button group.
private struct AdaptiveShelfActions: UIViewRepresentable {
    let navigation: AppNavigationState
    let tint: Color
    let locale: Locale
    let recentPurchases: [FoodItemRecord]
    let isCollapsed: Bool

    func makeUIView(context: Context) -> ShelfActionsHostingView {
        ShelfActionsHostingView(rootView: content(reduceMotion: context.environment.accessibilityReduceMotion),
                               size: CGSize(width: isCollapsed ? 60 : 172, height: 44))
    }

    func updateUIView(_ view: ShelfActionsHostingView, context: Context) {
        view.contentView.configuration = UIHostingConfiguration {
            content(reduceMotion: context.environment.accessibilityReduceMotion)
        }.margins(.all, 0)
        let size = CGSize(width: isCollapsed ? 60 : 172, height: 44)
        if view.desiredSize != size {
            view.desiredSize = size
            view.invalidateIntrinsicContentSize()
            view.setNeedsLayout()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ShelfActionsHostingView, context: Context) -> CGSize? {
        uiView.desiredSize
    }

    private func content(reduceMotion: Bool) -> AdaptiveShelfActionsContent {
        AdaptiveShelfActionsContent(navigation: navigation, tint: tint, locale: locale,
                                    recentPurchases: recentPurchases, isCollapsed: isCollapsed,
                                    reduceMotion: reduceMotion)
    }
}

private final class ShelfActionsHostingView: UIView {
    let contentView: any UIView & UIContentView
    var desiredSize: CGSize

    init(rootView: AdaptiveShelfActionsContent, size: CGSize) {
        contentView = UIHostingConfiguration { rootView }.margins(.all, 0).makeContentView()
        desiredSize = size
        super.init(frame: CGRect(origin: .zero, size: size))
        backgroundColor = .clear
        accessibilityIdentifier = "global.actions.container"
        contentView.backgroundColor = .clear
        addSubview(contentView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var intrinsicContentSize: CGSize { desiredSize }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.frame = bounds
    }
}

private struct AdaptiveShelfActionsContent: View {
    let navigation: AppNavigationState
    let tint: Color
    let locale: Locale
    let recentPurchases: [FoodItemRecord]
    let isCollapsed: Bool
    let reduceMotion: Bool

    var body: some View {
        ZStack(alignment: .trailing) {
            if isCollapsed {
                Menu {
                    Button { navigation.requestShelfAction(.search) } label: {
                        Label(locale.text("shelf.search"), systemImage: "magnifyingglass")
                    }
                    .accessibilityIdentifier("global.search")
                    Menu { sortOptions } label: {
                        Label(locale.text("shelf.sort"), systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityIdentifier("global.sort")
                    Menu { addOptions } label: {
                        Label(locale.text("shelf.empty.action"), systemImage: "plus")
                    }
                    .accessibilityIdentifier("global.add")
                } label: {
                    actionIcon("ellipsis")
                }
                .accessibilityLabel(locale.text("global.moreActions"))
                .accessibilityIdentifier("global.more")
                .transition(actionTransition)
            } else {
                HStack(spacing: 12) {
                    Button { navigation.requestShelfAction(.search) } label: { actionIcon("magnifyingglass") }
                        .accessibilityLabel(locale.text("shelf.search"))
                        .accessibilityIdentifier("global.search")
                    Menu { sortOptions } label: { actionIcon("line.3.horizontal.decrease.circle") }
                        .accessibilityLabel(locale.text("shelf.sort"))
                        .accessibilityIdentifier("global.sort")
                    Menu { addOptions } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(tint, in: Circle())
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(locale.text("shelf.empty.action"))
                    .accessibilityIdentifier("global.add")
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                .transition(actionTransition)
            }
        }
        .buttonStyle(.plain)
        .menuStyle(.borderlessButton)
        .frame(width: isCollapsed ? 44 : 156, height: 44, alignment: .trailing)
        .padding(.horizontal, 8)
        .accessibilityElement(children: .contain)
        .menuIndicator(.hidden)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: isCollapsed)
    }

    private var actionTransition: AnyTransition {
        reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.9, anchor: .trailing))
    }

    private func actionIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(tint)
            .frame(minWidth: 44, minHeight: 44)
    }

    @ViewBuilder private var sortOptions: some View {
        Picker(locale.text("shelf.sort"), selection: Binding(
            get: { navigation.sortMode }, set: { navigation.chooseSort($0) }
        )) {
            ForEach(InventorySortMode.allCases, id: \.self) { mode in
                Text(mode.title(locale: locale)).tag(mode)
            }
        }
        Toggle(locale.text("shelf.expiredOnly"), isOn: Binding(
            get: { navigation.showExpiredOnly }, set: { navigation.setExpiredOnly($0) }
        ))
    }

    @ViewBuilder private var addOptions: some View {
        Button { navigation.requestShelfAction(.scan) } label: {
            Label(locale.text("scanner.title"), systemImage: "barcode.viewfinder")
        }
        .accessibilityIdentifier("global.add.scan")
        Button { navigation.requestShelfAction(.add) } label: {
            Label(locale.text("shelf.empty.action"), systemImage: "plus")
        }
        .accessibilityIdentifier("global.add.manual")
        if !recentPurchases.isEmpty {
            Section(locale.text("detail.repeatPurchase")) {
                ForEach(recentPurchases, id: \.id) { food in
                    Button(food.name) { navigation.requestShelfAction(.repeatPurchase(food.id)) }
                }
            }
        }
    }
}

extension View {
    func globalShelfToolbar(title: String, hasBackButton: Bool = false, centersTitle: Bool = false, isSelectionActive: Bool = false, onCancelSelection: (() -> Void)? = nil) -> some View {
        modifier(GlobalShelfToolbarModifier(title: title, hasBackButton: hasBackButton, centersTitle: centersTitle, isSelectionActive: isSelectionActive, onCancelSelection: onCancelSelection))
    }
}
