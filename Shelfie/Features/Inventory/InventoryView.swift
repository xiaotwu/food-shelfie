import SwiftData
import SwiftUI

struct InventoryView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Query(sort: \FoodItemRecord.createdAt, order: .reverse) private var foods: [FoodItemRecord]
    @Query(sort: \CategoryRecord.name) private var categories: [CategoryRecord]
    @Query(sort: \LocationRecord.sortOrder) private var locations: [LocationRecord]
    @Namespace private var chipNamespace

    @State private var selectedLocationID: UUID?
    @State private var selectedCategoryID: UUID?
    @State private var sortMode: InventorySortMode = .byExpiry
    @State private var showExpiredOnly = false
    @State private var isSelectMode = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var showEntry = false
    @State private var showScanner = false
    @State private var showSearch = false
    @State private var editingFood: FoodItemRecord?
    @State private var detailFood: FoodItemRecord?
    @State private var prefill: FoodEntryDraft?

    private var activeFoods: [FoodItemRecord] {
        foods.filter { $0.status == .active }
    }

    private var urgentCount: Int {
        activeFoods.filter { $0.freshness == .urgent || $0.freshness == .expired }.count
    }

    private var freshCount: Int {
        activeFoods.filter { $0.freshness == .fresh }.count
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                content
                    .navigationTitle(locale.text("shelf.title"))
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar { toolbar }
                    .animation(Motion.liquidSpring, value: isSelectMode)
                    .navigationDestination(isPresented: $showSearch) {
                        SearchView()
                    }
                    .sheet(isPresented: $showEntry) {
                        FoodEntryView(existing: editingFood, draft: prefill) {
                            editingFood = nil
                            prefill = nil
                            WidgetSnapshotWriter.refresh(context: modelContext)
                        }
                    }
                    .fullScreenCover(isPresented: $showScanner) {
                        ScannerView { draft in
                            prefill = draft
                            showScanner = false
                            showEntry = true
                        }
                    }
                    .sheet(item: detailBinding) { food in
                        FoodDetailSheet(
                            food: food,
                            categoryName: categoryName(for: food.categoryId),
                            locationTitle: locationInfo(for: food).title,
                            locationSymbol: locationInfo(for: food).symbol,
                            onEdit: {
                                detailFood = nil
                                editingFood = food
                                showEntry = true
                            },
                            onConsumed: { resolve(food, as: .consumed) },
                            onWasted: { resolve(food, as: .wasted) }
                        )
                    }

                // Floating batch action island
                if isSelectMode {
                    floatingBatchIsland
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 14)
                }
            }
            .sensoryFeedback(.selection, trigger: selectedLocationID)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: selectedIDs.count)
            .onChange(of: isSelectMode) { _, active in
                withAnimation(Motion.liquidSpring) {
                    settings.isTabBarHidden = active
                }
            }

        }
    }

    private var content: some View {
        VStack(spacing: 12) {
            // Freshness horizon bar
            freshnessHorizonBar

            // Category / location filter rail
            filterBar

            if visibleFoods.isEmpty {
                EmptyShelfView {
                    showEntry = true
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 154), spacing: 14)], spacing: 14) {
                        ForEach(visibleFoods, id: \.id) { food in
                            Button {
                                if isSelectMode {
                                    Motion.hapticSelection()
                                    withAnimation(Motion.snappy) { toggleSelection(food.id) }
                                } else {
                                    detailFood = food
                                }
                            } label: {
                                FoodCard(
                                    food: food,
                                    categoryName: categoryName(for: food.categoryId),
                                    locationTitle: locationInfo(for: food).title,
                                    locationSymbol: locationInfo(for: food).symbol,
                                    selected: selectedIDs.contains(food.id)
                                )
                            }
                            .buttonStyle(PressScaleButtonStyle(pressedScale: 0.96))
                            .onLongPressGesture {
                                Motion.hapticImpact(.medium)
                                withAnimation(Motion.bouncy) {
                                    isSelectMode = true
                                    selectedIDs.insert(food.id)
                                }
                            }
                            .shelfCardScrollTransition()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .floatingDockClearance()
                    .animation(Motion.liquidSpring, value: visibleFoods.map(\.id))
                }
            }
        }
    }

    // Freshness horizon bar
    private var freshnessHorizonBar: some View {
        HStack(spacing: 8) {
            // Total items count capsule
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(settings.tint)
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay { Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5) }

            Spacer()

            // Urgent warning quick filter pill
            if urgentCount > 0 {
                Button {
                    Motion.hapticImpact(.light)
                    withAnimation(Motion.snappy) {
                        showExpiredOnly.toggle()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(FreshnessPalette.color(for: .urgent))
                            .frame(width: 7, height: 7)
                            .shadow(color: FreshnessPalette.color(for: .urgent).opacity(0.6), radius: 3)
                        Text("\(urgentCount)")
                            .font(.caption.weight(.bold))
                        Text(locale.text("freshness.urgent"))
                            .font(.caption2.weight(.medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background {
                        Capsule()
                            .fill(
                                showExpiredOnly
                                ? FreshnessPalette.color(for: .urgent).opacity(0.24)
                                : FreshnessPalette.fill(for: .urgent)
                            )
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                showExpiredOnly
                                ? FreshnessPalette.color(for: .urgent).opacity(0.7)
                                : .white.opacity(0.2),
                                lineWidth: showExpiredOnly ? 1.2 : 0.5
                            )
                    }
                    .foregroundStyle(FreshnessPalette.color(for: .urgent))
                }
                .buttonStyle(.plain)
            }

            // Fresh status indicator pill
            if freshCount > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(FreshnessPalette.color(for: .fresh))
                        .frame(width: 6, height: 6)
                    Text("\(freshCount)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FreshnessPalette.color(for: .fresh))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(FreshnessPalette.fill(for: .fresh), in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if settings.groupByCategory {
                    FilterChip(
                        title: locale.text("location.all"),
                        symbol: "line.3.horizontal.decrease",
                        selected: selectedCategoryID == nil,
                        namespace: chipNamespace
                    ) {
                        Motion.hapticSelection()
                        withAnimation(Motion.liquidSpring) { selectedCategoryID = nil }
                    }
                    ForEach(categories, id: \.id) { category in
                        FilterChip(
                            title: category.displayName(locale: locale),
                            symbol: nil,
                            selected: selectedCategoryID == category.id,
                            namespace: chipNamespace
                        ) {
                            Motion.hapticSelection()
                            withAnimation(Motion.liquidSpring) { selectedCategoryID = category.id }
                        }
                    }
                } else {
                    FilterChip(
                        title: locale.text("location.all"),
                        symbol: "square.grid.2x2",
                        selected: selectedLocationID == nil,
                        namespace: chipNamespace
                    ) {
                        Motion.hapticSelection()
                        withAnimation(Motion.liquidSpring) { selectedLocationID = nil }
                    }
                    ForEach(locations, id: \.id) { location in
                        FilterChip(
                            title: location.displayName(locale: locale),
                            symbol: location.symbolName,
                            selected: selectedLocationID == location.id,
                            namespace: chipNamespace
                        ) {
                            Motion.hapticSelection()
                            withAnimation(Motion.liquidSpring) { selectedLocationID = location.id }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    // Floating batch action island
    private var floatingBatchIsland: some View {
        HStack(spacing: 12) {
            Text("\(selectedIDs.count)")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(settings.tint, in: Circle())

            Spacer()

            Button {
                Motion.hapticImpact(.medium)
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
                Motion.hapticImpact(.medium)
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
                Motion.hapticImpact(.heavy)
                bulkDelete()
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

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if isSelectMode {
            ToolbarItem(placement: .cancellationAction) {
                Button(locale.text("shelf.cancel")) {
                    withAnimation(Motion.snappy) {
                        isSelectMode = false
                        selectedIDs = []
                    }
                }
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Motion.hapticSelection()
                    showSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel(locale.text("shelf.search"))
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker(locale.text("shelf.sort"), selection: $sortMode) {
                        ForEach(InventorySortMode.allCases, id: \.self) { mode in
                            Text(mode.title(locale: locale)).tag(mode)
                        }
                    }
                    Toggle(locale.text("shelf.expiredOnly"), isOn: $showExpiredOnly)
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        Motion.hapticSelection()
                        showScanner = true
                    } label: {
                        Label(locale.text("scanner.title"), systemImage: "barcode.viewfinder")
                    }
                    Button {
                        Motion.hapticSelection()
                        editingFood = nil
                        prefill = nil
                        showEntry = true
                    } label: {
                        Label(locale.text("shelf.empty.action"), systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(settings.tint, in: Circle())
                        .shadow(color: settings.tint.opacity(0.4), radius: 6, y: 3)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .accessibilityLabel(locale.text("shelf.actions"))
            }
        }
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
        if showExpiredOnly {
            result = result.filter { $0.freshness == .expired || $0.freshness == .urgent }
        }
        switch sortMode {
        case .none:
            result.sort { $0.createdAt > $1.createdAt }
        case .byName:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .byExpiry:
            result.sort { lhs, rhs in
                let l = lhs.expiryDate ?? .distantFuture
                let r = rhs.expiryDate ?? .distantFuture
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

    private func resolve(_ food: FoodItemRecord, as status: FoodStatus) {
        Motion.hapticNotification(status == .consumed ? .success : .warning)
        withAnimation(Motion.soft) {
            food.status = status
            food.resolvedDate = .now
            detailFood = nil
        }
        try? modelContext.save()
        WidgetSnapshotWriter.refresh(context: modelContext)
        Task { await NotificationScheduler.reschedule(settings: settings, context: modelContext) }
    }

    private func bulkResolve(_ status: FoodStatus) {
        Motion.hapticNotification(status == .consumed ? .success : .warning)
        withAnimation(Motion.soft) {
            for food in foods where selectedIDs.contains(food.id) {
                food.status = status
                food.resolvedDate = .now
            }
            finishSelection()
        }
        try? modelContext.save()
    }

    private func bulkDelete() {
        withAnimation(Motion.soft) {
            for food in foods where selectedIDs.contains(food.id) {
                ImageStore.delete(fileName: food.imageFileName)
                modelContext.delete(food)
            }
            finishSelection()
        }
        try? modelContext.save()
    }

    private func finishSelection() {
        isSelectMode = false
        selectedIDs = []
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
    var action: () -> Void

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
        }
        .buttonStyle(.plain)
    }
}
