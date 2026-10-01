import SwiftData
import SwiftUI

struct InventoryView: View {
    @Environment(AppNavigationState.self) private var navigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Query(sort: \FoodItemRecord.createdAt, order: .reverse) private var foods: [FoodItemRecord]
    @Query(sort: \CategoryRecord.name) private var categories: [CategoryRecord]
    @Query(sort: \LocationRecord.sortOrder) private var locations: [LocationRecord]
    @Namespace private var chipNamespace

    @State private var selectedLocationID: UUID?
    @State private var selectedCategoryID: UUID?
    @State private var isSelectMode = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var entryPresentation: EntryPresentation?
    @State private var showScanner = false
    @State private var showSearch = false
    @State private var showShopping = false
    @State private var showHistory = false
    @State private var showQuickAmount = false
    @State private var quickFood: FoodItemRecord?
    @State private var quickAmountText = ""
    @State private var detailFood: FoodItemRecord?
    @State private var pendingScanDraft: FoodEntryDraft?
    @State private var pendingDetailEntry: EntryPresentation?
    @State private var lastAction: [FoodActionSnapshot] = []
    @State private var lastActionResult: [FoodActionSnapshot] = []
    @State private var errorMessageKey = "error.saveMessage"
    @State private var showSaveError = false
    @State private var confirmBulkDelete = false
    @State private var pendingGlobalAction: GlobalShelfActionRequest?

    private struct EntryPresentation: Identifiable {
        let id = UUID()
        var existing: FoodItemRecord?
        var draft: FoodEntryDraft?
    }

    private var activeFoods: [FoodItemRecord] {
        foods.filter { $0.status == .active }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                content
                    .accessibilityIdentifier("shelf.scroll")
                    .navigationTitle(locale.text("shelf.title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .globalShelfToolbar(title: locale.text("shelf.title"), isSelectionActive: isSelectMode, onCancelSelection: finishSelection)
                    .onAppear {
                        presentPendingGlobalAction()
                    }
                    .animation(Motion.liquidSpring, value: isSelectMode)
                    .navigationDestination(isPresented: $showSearch) {
                        SearchView().globalShelfToolbar(title: locale.text("search.title"), hasBackButton: true)
                    }
                    .navigationDestination(isPresented: $showShopping) { ShoppingListView().globalShelfToolbar(title: locale.text("shopping.title"), hasBackButton: true) }
                    .navigationDestination(isPresented: $showHistory) { FoodHistoryView().globalShelfToolbar(title: locale.text("history.title"), hasBackButton: true) }
                    .sheet(item: $entryPresentation) { presentation in
                        FoodEntryView(existing: presentation.existing, draft: presentation.draft) {
                            lastAction = []
                            refreshInventory()
                        }
                    }
                    .fullScreenCover(isPresented: $showScanner, onDismiss: {
                        // Present only after the scanner's dismissal has completed.
                        if let draft = pendingScanDraft {
                            pendingScanDraft = nil
                            entryPresentation = EntryPresentation(draft: draft)
                        }
                    }) {
                        ScannerView { draft in
                            pendingScanDraft = draft
                            showScanner = false
                        }
                    }
                    .sheet(item: detailBinding, onDismiss: {
                        if let presentation = pendingDetailEntry {
                            pendingDetailEntry = nil
                            entryPresentation = presentation
                        }
                    }) { food in
                        FoodDetailSheet(
                            food: food,
                            categoryName: categoryName(for: food.categoryId),
                            locationTitle: locationInfo(for: food).title,
                            locationSymbol: locationInfo(for: food).symbol,
                            onEdit: {
                                pendingDetailEntry = EntryPresentation(existing: food)
                                detailFood = nil
                            },
                            onConsumed: { resolve(food, as: .consumed) },
                            onWasted: { resolve(food, as: .wasted) },
                            onPartialConsumption: { consume(food, amount: $0) },
                            onRepeatPurchase: {
                                pendingDetailEntry = EntryPresentation(draft: .repeatPurchase(from: food))
                                detailFood = nil
                            },
                            onShopping: { addToShopping(food) }
                        )
                    }

                if isSelectMode {
                    floatingBatchIsland
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 14)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !lastAction.isEmpty && !isSelectMode {
                    InventoryUndoBanner(reservesDockSpace: true, undo: undoLastAction, close: { lastAction = [] })
                }
            }
            .alert(locale.text("error.saveTitle"), isPresented: $showSaveError) {
                Button(locale.text("common.ok"), role: .cancel) { }
            } message: { Text(locale.text(errorMessageKey)) }
            .confirmationDialog(locale.text("shelf.deleteConfirmation"), isPresented: $confirmBulkDelete, titleVisibility: .visible) {
                Button(locale.text("shelf.delete"), role: .destructive) { bulkDelete() }
                Button(locale.text("shelf.cancel"), role: .cancel) { }
            }
            .alert(locale.text("detail.consumeAmount"), isPresented: $showQuickAmount) {
                TextField(locale.text("detail.consumeAmount"), text: $quickAmountText).keyboardType(.decimalPad)
                Button(locale.text("detail.consumePartial")) {
                    if let food = quickFood, let amount = InventoryNumber.parse(quickAmountText, locale: locale), !consume(food, amount: amount) {
                        errorMessageKey = "error.saveMessage"; showSaveError = true
                    }
                }
                .disabled(quickAmount == nil)
                Button(locale.text("shelf.cancel"), role: .cancel) { }
            } message: { Text(locale.text("detail.consumeHint")) }
            .onAppear(perform: handleNavigation)
            .task(id: navigation.shelfActionRequest?.id) {
                guard let request = navigation.shelfActionRequest else { return }
                await receiveGlobalAction(request)
            }
            .onChange(of: navigation.foodID) { _, _ in handleNavigation() }
            .onChange(of: navigation.shelfRequest) { _, _ in
                pendingGlobalAction = nil
                detailFood = nil
                showSearch = false
                showShopping = false
                showHistory = false
            }
            .sensoryFeedback(.selection, trigger: selectedLocationID)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: selectedIDs.count)
            .onChange(of: isSelectMode) { _, active in
                withAnimation(reduceMotion ? nil : Motion.liquidSpring) { settings.isTabBarHidden = active }
            }
#if DEBUG
            .task {
                if ProcessInfo.processInfo.arguments.contains("--qa-barcode") { showScanner = true }
            }
#endif
        }
    }

    private var shelfHeaderLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                shelfHeaderLayout {
                    Button { showShopping = true } label: { Label(locale.text("shopping.title"), systemImage: "cart") }
                    if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                    Button { showHistory = true } label: { Label(locale.text("history.title"), systemImage: "clock.arrow.circlepath") }
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                filterBar
                useFirstSection
                if foods.isEmpty && !settings.hasDismissedGettingStarted {
                    gettingStartedCard
                } else if visibleFoods.isEmpty {
                    EmptyShelfView { entryPresentation = EntryPresentation() }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 280 : 154), spacing: 14)], spacing: 14) {
                        ForEach(visibleFoods, id: \.id) { food in
                            Button {
                                if isSelectMode {
                                    Motion.hapticSelection()
                                    withAnimation(reduceMotion ? nil : Motion.snappy) { toggleSelection(food.id) }
                                } else { detailFood = food }
                            } label: {
                                FoodCard(food: food, categoryName: categoryName(for: food.categoryId),
                                         locationTitle: locationInfo(for: food).title,
                                         locationSymbol: locationInfo(for: food).symbol,
                                         selected: selectedIDs.contains(food.id))
                            }
                            .buttonStyle(PressScaleButtonStyle(pressedScale: 0.96))
                            .highPriorityGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                                Motion.hapticImpact(.medium)
                                withAnimation(reduceMotion ? nil : Motion.bouncy) { isSelectMode = true; selectedIDs.insert(food.id) }
                            })
                            .shelfCardScrollTransition()
                        }
                    }
                    .padding(.horizontal, 16)
                    .animation(reduceMotion ? nil : Motion.liquidSpring, value: visibleFoods.map(\.id))
                }
            }
            .padding(.top, 4)
            .floatingDockClearance(extra: isSelectMode ? (dynamicTypeSize.isAccessibilitySize ? 80 : 20) : 0)
        }
    }

    private var gettingStartedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(locale.text("shelf.gettingStarted"), systemImage: "leaf")
                .font(.headline)
            Text(locale.text("shelf.gettingStartedSteps"))
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            FlowLayout(spacing: 10) {
                Button(locale.text("shelf.gettingStartedAdd")) { entryPresentation = EntryPresentation() }
                    .buttonStyle(.borderedProminent)
                Button(locale.text("shelf.gettingStartedSkip")) { settings.dismissGettingStarted() }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16).liquidCard(cornerRadius: 20).padding(.horizontal, 16)
    }

    private var useFirstFoods: [FoodItemRecord] {
        Array(visibleFoods.filter { food in
            guard let days = food.remainingDays else { return false }
            return days >= 0 && days <= 7
        }.sorted { ($0.effectiveExpiryDate ?? .distantFuture) < ($1.effectiveExpiryDate ?? .distantFuture) }.prefix(3))
    }

    @ViewBuilder
    private var useFirstSection: some View {
        if !useFirstFoods.isEmpty && !isSelectMode {
            VStack(alignment: .leading, spacing: 8) {
                Label(locale.text("shelf.useFirst"), systemImage: "fork.knife").font(.headline)
                ForEach(useFirstFoods, id: \.id) { food in
                    HStack(spacing: 8) {
                        Button { detailFood = food } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(food.name).font(.subheadline.weight(.semibold))
                                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                                Text(food.quantityLabel(locale: locale) + " · " + RemainingDaysCopy.label(days: food.remainingDays, locale: locale, short: true))
                                    .font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        .accessibilityIdentifier("shelf.useFirst.\(food.id.uuidString)")
                        Menu {
                            Button { quickFood = food; quickAmountText = ""; showQuickAmount = true } label: {
                                Label(locale.text("detail.consumePartial"), systemImage: "minus.circle")
                            }
                            Button {
                                if !resolve(food, as: .consumed) { errorMessageKey = "error.saveMessage"; showSaveError = true }
                            } label: { Label(locale.text("detail.eaten"), systemImage: "checkmark.circle") }
                            Button(role: .destructive) {
                                if !resolve(food, as: .wasted) { errorMessageKey = "error.saveMessage"; showSaveError = true }
                            } label: { Label(locale.text("detail.discard"), systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis.circle").font(.title3)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel(locale.format("shelf.foodActions", food.name))
                    }
                    if food.id != useFirstFoods.last?.id { Divider() }
                }
            }.padding(12).liquidCard(cornerRadius: 20).padding(.horizontal, 16)
        }
    }

    private var quickAmount: Double? {
        guard let food = quickFood, let value = InventoryNumber.parse(quickAmountText, locale: locale),
              FoodQuantity.isValid(value), value <= food.quantity else { return nil }
        return value
    }

    private func addToShopping(_ food: FoodItemRecord) -> Bool {
        do { try ShoppingListOperations.add(food: food, context: modelContext); return true }
        catch { return false }
    }

    @MainActor
    private func receiveGlobalAction(_ request: GlobalShelfActionRequest) async {
        guard navigation.shelfActionRequest?.id == request.id else { return }
        // A request replaces a pushed workflow rather than stacking another copy.
        let wasPushed = showSearch || showShopping || showHistory
        pendingGlobalAction = request
        finishSelection()
        detailFood = nil
        pendingDetailEntry = nil
        pendingScanDraft = nil
        showSearch = false
        showShopping = false
        showHistory = false
        if !wasPushed {
            // The newly selected Shelf tab must mount before it presents a workflow.
            await Task.yield()
            guard !Task.isCancelled else { return }
            presentPendingGlobalAction()
        }
        // When a push is dismissed, the Shelf content's onAppear completes presentation.
    }

    private func presentPendingGlobalAction() {
        guard let request = pendingGlobalAction,
              navigation.shelfActionRequest?.id == request.id,
              navigation.selectedTab == .shelf,
              !showSearch, !showShopping, !showHistory else { return }
        pendingGlobalAction = nil
        navigation.completeShelfAction(request.id)
        settings.isTabBarHidden = false
        switch request.action {
        case .search: showSearch = true
        case .scan:
            pendingScanDraft = nil
            showScanner = true
        case .add: entryPresentation = EntryPresentation()
        case .repeatPurchase(let id):
            guard let food = foods.first(where: { $0.id == id }) else {
                navigation.actionError = locale.text("notif.missingFood")
                return
            }
            entryPresentation = EntryPresentation(draft: .repeatPurchase(from: food))
        case .revealShelf: break
        }
    }

    private func handleNavigation() {
        if let id = navigation.foodID {
            if let food = foods.first(where: { $0.id == id && $0.status == .active }) { detailFood = food }
            else { navigation.actionError = locale.text("notif.missingFood") }
            navigation.foodID = nil
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if settings.groupByCategory {
                    FilterChip(title: locale.text("location.all"), symbol: "line.3.horizontal.decrease",
                               selected: selectedCategoryID == nil, namespace: chipNamespace,
                               count: activeFoods.count, badgeStyle: settings.inventoryBadgeStyle) {
                        Motion.hapticSelection()
                        withAnimation(reduceMotion ? nil : Motion.liquidSpring) { selectedCategoryID = nil }
                    }
                    ForEach(categories, id: \.id) { category in
                        FilterChip(title: category.displayName(locale: locale), symbol: nil,
                                   selected: selectedCategoryID == category.id, namespace: chipNamespace,
                                   count: activeFoods.filter { $0.categoryId == category.id }.count,
                                   badgeStyle: settings.inventoryBadgeStyle) {
                            Motion.hapticSelection()
                            withAnimation(reduceMotion ? nil : Motion.liquidSpring) { selectedCategoryID = category.id }
                        }
                    }
                } else {
                    FilterChip(title: locale.text("location.all"), symbol: "square.grid.2x2",
                               selected: selectedLocationID == nil, namespace: chipNamespace,
                               count: activeFoods.count, badgeStyle: settings.inventoryBadgeStyle) {
                        Motion.hapticSelection()
                        withAnimation(reduceMotion ? nil : Motion.liquidSpring) { selectedLocationID = nil }
                    }
                    ForEach(locations, id: \.id) { location in
                        FilterChip(title: location.displayName(locale: locale), symbol: location.symbolName,
                                   selected: selectedLocationID == location.id, namespace: chipNamespace,
                                   count: activeFoods.filter { $0.locationId == location.id || $0.resolvedLocation(in: locations)?.id == location.id }.count,
                                   badgeStyle: settings.inventoryBadgeStyle) {
                            Motion.hapticSelection()
                            withAnimation(reduceMotion ? nil : Motion.liquidSpring) { selectedLocationID = location.id }
                        }
                    }
                }
            }.padding(.horizontal, 16).padding(.vertical, 12)
        }
    }

    // Preserve all batch actions on narrow screens and at larger text sizes.
    @ViewBuilder
    private var floatingBatchIsland: some View {
        if dynamicTypeSize.isAccessibilitySize {
            compactBatchIsland
        } else {
            ViewThatFits(in: .horizontal) {
                regularBatchIsland
                compactBatchIsland
            }
        }
    }

    private var compactBatchIsland: some View {
        HStack(spacing: 16) {
            Text("\(selectedIDs.count)").font(.headline)
                .accessibilityLabel(locale.format("shelf.selectedCount", selectedIDs.count))
            Spacer()
            Menu {
                Button(locale.text("shelf.markEaten")) { bulkResolve(.consumed) }
                Button(locale.text("shelf.markDiscarded")) { bulkResolve(.wasted) }
                Button(locale.text("shelf.delete"), role: .destructive) { confirmBulkDelete = true }
            } label: { Image(systemName: "ellipsis.circle").font(.title2) }
                .accessibilityLabel(locale.text("shelf.actions"))
                .frame(minWidth: 44, minHeight: 44)
            Button {
                isSelectMode = false; selectedIDs = []
            } label: { Image(systemName: "xmark.circle").font(.title2) }
                .accessibilityLabel(locale.text("shelf.cancel"))
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var regularBatchIsland: some View {
        HStack(spacing: 12) {
            Text("\(selectedIDs.count)")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(settings.tint, in: Circle())

            Spacer()

            Button {
                bulkResolve(.consumed)
            } label: {
                Label(locale.text("shelf.markEaten"), systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FreshnessPalette.color(for: .fresh))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(FreshnessPalette.fill(for: .fresh), in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                bulkResolve(.wasted)
            } label: {
                Label(locale.text("shelf.markDiscarded"), systemImage: "xmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FreshnessPalette.color(for: .expired))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(FreshnessPalette.fill(for: .expired), in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                confirmBulkDelete = true
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(Motion.snappy) {
                    isSelectMode = false
                    selectedIDs = []
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        )
    }

    private var visibleFoods: [FoodItemRecord] {
        var result = activeFoods
        if settings.groupByCategory {
            if let selectedCategoryID {
                result = result.filter { $0.categoryId == selectedCategoryID }
            }
        } else if let selectedLocationID {
            result = result.filter { food in
                food.locationId == selectedLocationID || food.resolvedLocation(in: locations)?.id == selectedLocationID
            }
        }
        if navigation.showExpiredOnly {
            result = result.filter { $0.freshness == .expired || $0.freshness == .urgent }
        }
        switch navigation.sortMode {
        case .none:
            result.sort { $0.createdAt > $1.createdAt }
        case .byName:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .byExpiry:
            result.sort { lhs, rhs in
                let l = lhs.effectiveExpiryDate ?? .distantFuture
                let r = rhs.effectiveExpiryDate ?? .distantFuture
                return l < r
            }
        }
        return result
    }

    private var subtitle: String {
        let count = visibleFoods.count
        if count == 0 { return locale.text("shelf.count.zero") }
        if count == 1 { return locale.text("shelf.count.one") }
        return locale.format("shelf.count.other", count)
    }

    private func categoryName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return categories.first(where: { $0.id == id })?.displayName(locale: locale)
    }

    private func locationInfo(for food: FoodItemRecord) -> (title: String, symbol: String) {
        if let location = food.resolvedLocation(in: locations) {
            return (location.displayName(locale: locale), location.symbolName)
        }
        return (food.location.title(locale: locale), food.location.symbolName)
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    @discardableResult
    private func resolve(_ food: FoodItemRecord, as status: FoodStatus) -> Bool {
        guard food.modelContext != nil, !food.isDeleted, food.status == .active else { return false }
        let snapshot = FoodActionSnapshot(food)
        food.status = status
        food.resolvedDate = .now
        do {
            try modelContext.save()
            lastAction = [snapshot]
            lastActionResult = [FoodActionSnapshot(food)]
            detailFood = nil
            Motion.hapticNotification(status == .consumed ? .success : .warning)
            refreshInventory()
            return true
        } catch {
            snapshot.restore()
            return false
        }
    }

    private func consume(_ food: FoodItemRecord, amount: Double) -> Bool {
        guard food.modelContext != nil, !food.isDeleted, food.status == .active else { return false }
        let snapshot = FoodActionSnapshot(food)
        do {
            try food.consume(amount: amount)
            try modelContext.save()
            lastAction = [snapshot]
            lastActionResult = [FoodActionSnapshot(food)]
            detailFood = nil
            Motion.hapticNotification(.success)
            refreshInventory()
            return true
        } catch {
            snapshot.restore()
            return false
        }
    }

    private func bulkResolve(_ status: FoodStatus) {
        let targets = foods.filter { selectedIDs.contains($0.id) && $0.status == .active }
        guard !targets.isEmpty else { return }
        let snapshots = targets.map(FoodActionSnapshot.init)
        for food in targets {
            food.status = status
            food.resolvedDate = .now
        }
        do {
            try modelContext.save()
            lastAction = snapshots
            lastActionResult = targets.map(FoodActionSnapshot.init)
            finishSelection()
            Motion.hapticNotification(status == .consumed ? .success : .warning)
            refreshInventory()
        } catch {
            snapshots.forEach { $0.restore() }
            errorMessageKey = "error.saveMessage"
            showSaveError = true
        }
    }

    private func bulkDelete() {
        let targets = foods.filter { selectedIDs.contains($0.id) }
        let images = targets.compactMap(\.imageFileName)
        for food in targets { modelContext.delete(food) }
        do {
            try modelContext.save()
            // Files are removed only after the database commits successfully.
            for image in images { ImageStore.delete(fileName: image) }
            lastAction = []
            finishSelection()
            Motion.hapticNotification(.success)
            refreshInventory()
        } catch {
            modelContext.rollback()
            errorMessageKey = "error.saveMessage"
            showSaveError = true
        }
    }

    private func undoLastAction() {
        guard !lastAction.isEmpty, lastActionResult.count == lastAction.count,
              lastActionResult.allSatisfy({ $0.matchesCurrent }) else {
            lastAction = []
            errorMessageKey = "action.undoUnavailable"
            showSaveError = true
            return
        }
        let current = lastAction.map { FoodActionSnapshot($0.food) }
        lastAction.forEach { $0.restore() }
        do {
            try modelContext.save()
            lastAction = []
            Motion.hapticNotification(.success)
            refreshInventory()
        } catch {
            current.forEach { $0.restore() }
            errorMessageKey = "error.saveMessage"
            showSaveError = true
        }
    }

    private func finishSelection() {
        isSelectMode = false
        selectedIDs = []
    }

    private func refreshInventory() {
        WidgetSnapshotWriter.refresh(context: modelContext)
        Task { await NotificationScheduler.reschedule(settings: settings, context: modelContext) }
    }

    private var detailBinding: Binding<FoodItemRecord?> {
        Binding(
            get: { detailFood },
            set: { detailFood = $0 }
        )
    }
}

struct FilterChip: View {
    var title: String
    var symbol: String? = nil
    var selected: Bool
    var namespace: Namespace.ID
    var count: Int = 0
    var badgeStyle: InventoryBadgeStyle = .number
    var action: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.caption.weight(selected ? .bold : .medium))
                }
                Text(title)
                    .font(.subheadline.weight(selected ? .bold : .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                if selected {
                    Capsule()
                        .fill(Color.accentColor)
                        .overlay {
                            Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.75)
                        }
                        .shadow(color: Color.accentColor.opacity(0.35), radius: 8, y: 3)
                        .matchedGeometryEffect(id: "chip-selection", in: namespace)
                } else {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                        }
                }
            }
            .foregroundStyle(selected ? Color.white : Color.primary)
            .overlay(alignment: .topTrailing) {
                InventoryCountBadge(count: count, style: badgeStyle)
                    .offset(x: 6, y: -6)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title + ", " + String(count) + " " + locale.text(count == 1 ? "shelf.badge.item" : "shelf.badge.items"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// Decimal fields share strict, locale-aware parsing; malformed suffixes are rejected.
enum InventoryNumber {
    static func parse(_ raw: String, locale: Locale) -> Double? {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = formatter.decimalSeparator ?? "."
        let parts = input.components(separatedBy: separator)
        guard !input.isEmpty, parts.count <= 2,
              !parts.joined().isEmpty,
              parts.joined().unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }),
              let number = formatter.number(from: input), number.doubleValue.isFinite else { return nil }
        return number.doubleValue
    }
}

struct LowStockSuggestion: Identifiable {
    let id: String
    let food: FoodItemRecord
    let remaining: Double
    let threshold: Double

    static func suggestions(from foods: [FoodItemRecord]) -> [LowStockSuggestion] {
        let grouped = Dictionary(grouping: foods) { food in
            ShoppingListOperations.key(name: food.name, unit: food.unitRaw)
        }
        return grouped.compactMap { key, batches -> LowStockSuggestion? in
            let tracked = batches.filter { $0.lowStockThreshold != nil }
            guard let template = tracked.sorted(by: { $0.createdAt > $1.createdAt }).first,
                  let threshold = tracked.compactMap(\.lowStockThreshold).max() else { return nil }
            let total = batches.filter { $0.status == .active }.reduce(0) { $0 + $1.quantity }
            let remaining = (total * 1_000).rounded() / 1_000
            guard remaining <= threshold else { return nil }
            return LowStockSuggestion(id: key, food: template, remaining: remaining, threshold: threshold)
        }.sorted { $0.food.name.localizedCaseInsensitiveCompare($1.food.name) == .orderedAscending }
    }
}

enum ShoppingListOperations {
    static func key(name: String, unit: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            + "|" + unit
    }

    static func add(food: FoodItemRecord, context: ModelContext, quantity: Double = 1,
                    commit: (ModelContext) throws -> Void = { try $0.save() }) throws {
        guard FoodQuantity.isValid(quantity) else { throw FoodQuantity.Error.invalidAmount }
        let existing = try context.fetch(FetchDescriptor<ShoppingItemRecord>())
        let itemKey = key(name: food.name, unit: food.unitRaw)
        guard !existing.contains(where: { !$0.isCompleted && key(name: $0.name, unit: $0.unitRaw) == itemKey }) else { return }
        let item = ShoppingItemRecord(name: food.name, quantity: quantity, unit: FoodUnit(rawValue: food.unitRaw) ?? .piece)
        context.insert(item)
        do { try commit(context) }
        catch { context.delete(item); throw error }
    }
}

struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(SettingsStore.self) private var settings
    @Query(sort: \ShoppingItemRecord.createdAt, order: .reverse) private var items: [ShoppingItemRecord]
    @Query private var foods: [FoodItemRecord]
    @State private var name = ""
    @State private var quantityText = "1"
    @State private var unit: FoodUnit = .piece
    @State private var showSaveError = false
    @State private var editingItem: ShoppingItemRecord?
    @State private var editedQuantity = ""
    @State private var purchaseConfirmation: ShoppingItemRecord?
    @State private var showPurchaseConfirmation = false
    @State private var inventoryEntry: ShoppingInventoryEntry?

    private struct ShoppingInventoryEntry: Identifiable {
        let id: UUID
        let draft: FoodEntryDraft
    }


    private var quantity: Double? {
        guard let value = InventoryNumber.parse(quantityText, locale: locale), FoodQuantity.isValid(value) else { return nil }
        return value
    }

    private var validEditedQuantity: Double? {
        guard let value = InventoryNumber.parse(editedQuantity, locale: locale), FoodQuantity.isValid(value) else { return nil }
        return value
    }

    var body: some View {
        List {
            Section(locale.text("shopping.title")) {
                TextField(locale.text("shopping.name"), text: $name)
                    .accessibilityIdentifier("shopping.name")
                TextField(locale.text("shopping.quantity"), text: $quantityText)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("shopping.quantity")
                Picker(locale.text("entry.unit"), selection: $unit) {
                    ForEach(FoodUnit.allCases, id: \.self) { Text($0.title(locale: locale)).tag($0) }
                }
                Button(locale.text("entry.add"), action: addCustom)
                    .disabled(!FoodValidator.validateName(name).isValid || quantity == nil)
            }
            let suggestions = LowStockSuggestion.suggestions(from: foods)
            if !suggestions.isEmpty {
                Section(locale.text("shopping.lowStock")) {
                    ForEach(suggestions) { suggestion in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(suggestion.food.name).font(.headline)
                            Text(locale.text("shopping.remaining") + ": " + suggestion.remaining.formatted(.number.precision(.fractionLength(0...3)).locale(locale)) + " " + (FoodUnit(rawValue: suggestion.food.unitRaw) ?? .piece).title(locale: locale))
                                .font(.subheadline).foregroundStyle(.secondary)
                            let exists = items.contains { !$0.isCompleted && ShoppingListOperations.key(name: $0.name, unit: $0.unitRaw) == suggestion.id }
                            Button(locale.text(exists ? "shopping.added" : "shopping.add")) {
                                do {
                                    try ShoppingListOperations.add(food: suggestion.food, context: modelContext, quantity: max(1, suggestion.threshold - suggestion.remaining))
                                } catch { showSaveError = true }
                            }
                            .disabled(exists)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            if items.isEmpty {
                Text(locale.text("shopping.empty")).foregroundStyle(.secondary)
            }
            Section(locale.text("shopping.title")) {
                ForEach(items.filter { !$0.isCompleted }, id: \.id) { item in shoppingRow(item) }
            }
            if items.contains(where: \.isCompleted) {
                Section(locale.text("shopping.bought")) {
                    ForEach(items.filter(\.isCompleted), id: \.id) { item in shoppingRow(item) }
                }
            }
        }
        .accessibilityIdentifier("shopping.scroll")
        .navigationTitle(locale.text("shopping.title"))
        .onAppear { settings.isTabBarHidden = true }
        .onDisappear { settings.isTabBarHidden = false }
        .alert(locale.text("error.saveTitle"), isPresented: $showSaveError) {
            Button(locale.text("common.ok"), role: .cancel) { }
        } message: { Text(locale.text("error.saveMessage")) }
        .confirmationDialog(locale.text("shopping.purchasePrompt"), isPresented: $showPurchaseConfirmation, titleVisibility: .visible) {
            Button(locale.text("shopping.addInventory")) {
                if let item = purchaseConfirmation { beginInventoryEntry(item) }
                purchaseConfirmation = nil
            }
            .disabled(purchaseConfirmation?.inventoryFoodID != nil)
            Button(locale.text("shopping.boughtOnly")) {
                if let item = purchaseConfirmation { setCompleted(item, true) }
                purchaseConfirmation = nil
            }
            Button(locale.text("entry.cancel"), role: .cancel) { purchaseConfirmation = nil }
        }
        .sheet(item: $inventoryEntry) { entry in
            FoodEntryView(draft: entry.draft, shoppingItemID: entry.id) {
                // Entry commits the food and purchase link together before invoking this callback.
                Motion.hapticNotification(.success)
            }
        }
        .alert(locale.text("shopping.quantity"), isPresented: Binding(get: { editingItem != nil }, set: { if !$0 { editingItem = nil } })) {
            TextField(locale.text("shopping.quantity"), text: $editedQuantity).keyboardType(.decimalPad)
            Button(locale.text("entry.save")) {
                if let item = editingItem, let value = validEditedQuantity {
                    let old = item.quantity
                    item.quantity = value
                    do { try modelContext.save() }
                    catch { item.quantity = old; showSaveError = true }
                }
                editingItem = nil
            }
            .disabled(validEditedQuantity == nil)
            Button(locale.text("entry.cancel"), role: .cancel) { editingItem = nil }
        }
    }

    private func shoppingRow(_ item: ShoppingItemRecord) -> some View {
        HStack(spacing: 12) {
            Button {
                if item.isCompleted {
                    setCompleted(item, false)
                } else {
                    purchaseConfirmation = item
                    showPurchaseConfirmation = true
                }
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(locale.format(item.isCompleted ? "shopping.markPending" : "shopping.markBought", item.name))
            .accessibilityValue(locale.text(item.isCompleted ? "shopping.bought" : "shopping.pending"))
            VStack(alignment: .leading) {
                Text(item.name).strikethrough(item.isCompleted)
                Text(item.quantityLabel(locale: locale)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button {
                    editedQuantity = item.quantity.formatted(.number.grouping(.never).locale(locale))
                    editingItem = item
                } label: { Label(locale.text("detail.edit"), systemImage: "pencil") }
                if item.isCompleted {
                    Button { beginInventoryEntry(item) } label: {
                        Label(locale.text(item.inventoryFoodID == nil ? "shopping.addInventory" : "shopping.inventoryAdded"), systemImage: "plus.circle")
                    }.disabled(item.inventoryFoodID != nil)
                }
            } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44) }
                .accessibilityLabel(locale.format("shopping.itemActions", item.name))
        }
        .swipeActions {
            Button(role: .destructive) {
                modelContext.delete(item)
                do { try modelContext.save() }
                catch { modelContext.rollback(); showSaveError = true }
            } label: { Label(locale.text("shelf.delete"), systemImage: "trash") }
        }
    }

    private func setCompleted(_ item: ShoppingItemRecord, _ completed: Bool) {
        let old = item.isCompleted
        item.isCompleted = completed
        do { try modelContext.save(); Motion.hapticSelection() }
        catch { item.isCompleted = old; showSaveError = true }
    }

    private func beginInventoryEntry(_ item: ShoppingItemRecord) {
        guard inventoryEntry == nil, item.inventoryFoodID == nil, !item.isDeleted else { return }
        inventoryEntry = ShoppingInventoryEntry(
            id: item.id,
            draft: FoodEntryDraft(name: item.name, quantity: item.quantity, unit: item.unit, requiresExpiryConfirmation: true)
        )
    }

    private func addCustom() {
        guard let quantity, FoodValidator.validateName(name).isValid else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = ShoppingListOperations.key(name: trimmed, unit: unit.rawValue)
        guard !items.contains(where: { !$0.isCompleted && ShoppingListOperations.key(name: $0.name, unit: $0.unitRaw) == key }) else {
            name = ""; quantityText = "1"; return
        }
        let item = ShoppingItemRecord(name: trimmed, quantity: quantity, unit: unit)
        modelContext.insert(item)
        do { try modelContext.save(); name = ""; quantityText = "1"; Motion.hapticNotification(.success) }
        catch { modelContext.delete(item); showSaveError = true }
    }
}

struct FoodHistoryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(SettingsStore.self) private var settings
    @Query(sort: \FoodItemRecord.resolvedDate, order: .reverse) private var foods: [FoodItemRecord]
    @State private var entryPresentation: HistoryEntry?
    @State private var restoreFood: FoodItemRecord?
    @State private var restoreQuantityText = "1"
    @State private var showSaveError = false
    @State private var lastAction: FoodActionSnapshot?
    @State private var expectedAction: FoodActionSnapshot?
    @State private var errorKey = "error.saveMessage"

    private struct HistoryEntry: Identifiable {
        let id = UUID()
        var existing: FoodItemRecord?
        var draft: FoodEntryDraft?
    }

    private var historyRowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
    }

    private var restoreQuantity: Double? {
        guard let value = InventoryNumber.parse(restoreQuantityText, locale: locale), FoodQuantity.isValid(value) else { return nil }
        return value
    }

    var body: some View {
        List {
            Section {
                Text(locale.text("history.restoreHint")).font(.subheadline).foregroundStyle(.secondary)
            }
            let processed = foods.filter { $0.status != .active }
            if processed.isEmpty { Text(locale.text("history.empty")).foregroundStyle(.secondary) }
            ForEach(processed, id: \.id) { food in
                VStack(alignment: .leading, spacing: 8) {
                    historyRowLayout {
                        Text(food.name).font(.headline)
                        if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                        Text(locale.text(food.status == .consumed ? "history.eaten" : "history.discarded"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text(locale.text("detail.boughtOn") + " " + food.purchaseDate.localizedDate(locale, date: .abbreviated))
                        .font(.caption).foregroundStyle(.secondary)
                    if let resolved = food.resolvedDate {
                        Text(resolved.localizedDate(locale, date: .abbreviated)).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(food.quantityLabel(locale: locale)).font(.caption)
                    FlowLayout(spacing: 12) {
                        Button(locale.text("history.restore")) {
                            restoreQuantityText = (food.quantity > 0 ? food.quantity : 1).formatted(.number.grouping(.never).locale(locale))
                            restoreFood = food
                        }
                        Button(locale.text("detail.repeatPurchase")) {
                            entryPresentation = HistoryEntry(draft: .repeatPurchase(from: food))
                        }
                        Button(locale.text("detail.edit")) { entryPresentation = HistoryEntry(existing: food) }
                    }
                    .font(.subheadline)
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(locale.text("history.title"))
        .onAppear { settings.isTabBarHidden = true }
        .onDisappear { settings.isTabBarHidden = false }
        .sheet(item: $entryPresentation) { entry in
            FoodEntryView(existing: entry.existing, draft: entry.draft) { lastAction = nil; refresh() }
        }
        .safeAreaInset(edge: .bottom) {
            if lastAction != nil { InventoryUndoBanner(undo: undoRestore, close: { lastAction = nil }) }
        }
        .alert(locale.text("history.restoreQuantity"), isPresented: Binding(get: { restoreFood != nil }, set: { if !$0 { restoreFood = nil } })) {
            TextField(locale.text("history.restoreQuantity"), text: $restoreQuantityText).keyboardType(.decimalPad)
            Button(locale.text("history.restore")) {
                if let food = restoreFood, let value = restoreQuantity { restore(food, quantity: value) }
                restoreFood = nil
            }
            .disabled(restoreQuantity == nil)
            Button(locale.text("entry.cancel"), role: .cancel) { restoreFood = nil }
        } message: { Text(locale.text("history.restoreInvalid") + "\n" + locale.text("history.restoreHint")) }
        .alert(locale.text("error.saveTitle"), isPresented: $showSaveError) {
            Button(locale.text("common.ok"), role: .cancel) { }
        } message: { Text(locale.text(errorKey)) }
    }

    private func restore(_ food: FoodItemRecord, quantity: Double) {
        guard food.status != .active, food.modelContext != nil, !food.isDeleted else { return }
        let before = FoodActionSnapshot(food)
        food.quantity = quantity
        food.status = .active
        food.resolvedDate = nil
        do {
            try modelContext.save()
            lastAction = before
            expectedAction = FoodActionSnapshot(food)
            Motion.hapticNotification(.success)
            refresh()
        } catch { before.restore(); errorKey = "error.saveMessage"; showSaveError = true }
    }

    private func undoRestore() {
        guard let before = lastAction, let expected = expectedAction, expected.matchesCurrent else {
            lastAction = nil; errorKey = "action.undoUnavailable"; showSaveError = true; return
        }
        before.restore()
        do { try modelContext.save(); lastAction = nil; refresh() }
        catch { expected.restore(); errorKey = "error.saveMessage"; showSaveError = true }
    }

    private func refresh() {
        WidgetSnapshotWriter.refresh(context: modelContext)
        Task { await NotificationScheduler.reschedule(settings: settings, context: modelContext) }
    }
}
