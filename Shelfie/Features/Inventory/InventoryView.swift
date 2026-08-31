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

    var body: some View {
        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .animation(Motion.snappy, value: isSelectMode)
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
                .sensoryFeedback(.selection, trigger: selectedLocationID)
                .sensoryFeedback(.impact(flexibility: .soft), trigger: selectedIDs.count)
        }
    }

    private var content: some View {
        VStack(spacing: 12) {
            filterBar
            if visibleFoods.isEmpty {
                EmptyShelfView {
                    showEntry = true
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(visibleFoods, id: \.id) { food in
                            Button {
                                if isSelectMode {
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
                            .buttonStyle(PressScaleButtonStyle())
                            .onLongPressGesture {
                                withAnimation(Motion.bouncy) {
                                    isSelectMode = true
                                    selectedIDs.insert(food.id)
                                }
                            }
                            .shelfCardScrollTransition()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 112)
                    .animation(Motion.soft, value: visibleFoods.map(\.id))
                }
            }
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .contentTransition(.numericText())
                .animation(Motion.snappy, value: visibleFoods.count)

            if settings.groupByCategory {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: locale.text("location.all"),
                            selected: selectedCategoryID == nil,
                            namespace: chipNamespace
                        ) {
                            withAnimation(Motion.snappy) { selectedCategoryID = nil }
                        }
                        ForEach(categories, id: \.id) { category in
                            FilterChip(
                                title: category.displayName(locale: locale),
                                selected: selectedCategoryID == category.id,
                                namespace: chipNamespace
                            ) {
                                withAnimation(Motion.snappy) { selectedCategoryID = category.id }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: locale.text("location.all"),
                            selected: selectedLocationID == nil,
                            namespace: chipNamespace
                        ) {
                            withAnimation(Motion.snappy) { selectedLocationID = nil }
                        }
                        ForEach(locations, id: \.id) { location in
                            FilterChip(
                                title: location.displayName(locale: locale),
                                selected: selectedLocationID == location.id,
                                namespace: chipNamespace
                            ) {
                                withAnimation(Motion.snappy) { selectedLocationID = location.id }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.top, 4)
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
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(locale.text("shelf.markEaten")) {
                        bulkResolve(.consumed)
                    }
                    Button(locale.text("shelf.markDiscarded"), role: .destructive) {
                        bulkResolve(.wasted)
                    }
                    Button(locale.text("shelf.delete"), role: .destructive) {
                        bulkDelete()
                    }
                } label: {
                    Label(locale.text("shelf.actions"), systemImage: "ellipsis.circle")
                }
            }
        } else {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button {
                        showScanner = true
                    } label: {
                        Label(locale.text("scanner.title"), systemImage: "barcode.viewfinder")
                    }
                    Button {
                        editingFood = nil
                        prefill = nil
                        showEntry = true
                    } label: {
                        Label(locale.text("shelf.empty.action"), systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                .accessibilityLabel(locale.text("shelf.actions"))
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
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
        }
    }

    private var activeFoods: [FoodItemRecord] {
        foods.filter { $0.status == .active }
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
            result = result.filter { $0.freshness == .expired }
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
    var selected: Bool
    var namespace: Namespace.ID
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if selected {
                        Capsule()
                            .fill(Color.accentColor)
                            .matchedGeometryEffect(id: "chip-selection", in: namespace)
                    } else {
                        Capsule()
                            .fill(Color.secondary.opacity(0.12))
                    }
                }
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
