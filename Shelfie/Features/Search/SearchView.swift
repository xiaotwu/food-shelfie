import SwiftData
import SwiftUI

enum SearchScope: String, CaseIterable, Identifiable {
    case all
    case name
    case owner
    case location
    case category

    var id: String { rawValue }

    func title(locale: Locale) -> String {
        switch self {
        case .all: locale.text("search.scope.all")
        case .name: locale.text("search.scope.name")
        case .owner: locale.text("search.scope.owner")
        case .location: locale.text("search.scope.location")
        case .category: locale.text("search.scope.category")
        }
    }
}

struct SearchView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Query(sort: \FoodItemRecord.name) private var foods: [FoodItemRecord]
    @Query(sort: \SearchHistoryRecord.timestamp, order: .reverse) private var history: [SearchHistoryRecord]
    @Query(sort: \CategoryRecord.name) private var categories: [CategoryRecord]
    @Query(sort: \LocationRecord.sortOrder) private var locations: [LocationRecord]

    @State private var query = ""
    @State private var selectedScope: SearchScope = .all
    @State private var detailFood: FoodItemRecord?
    @State private var editingFood: FoodItemRecord?
    @FocusState private var isSearchFocused: Bool
    @Namespace private var scopeNamespace

    var body: some View {
        ZStack {
            // Liquid ambient canvas background
            Glass.ambientBackground(tint: settings.tint)

            VStack(spacing: 0) {
                // Fixed top search and scope header
                searchHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            emptyQueryContent
                        } else if results.isEmpty {
                            noResultsContent
                        } else {
                            resultsContent
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationTitle(locale.text("search.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            settings.isTabBarHidden = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isSearchFocused = true
            }
        }
        .onDisappear {
            settings.isTabBarHidden = false
        }
        .sheet(item: $detailFood) { food in
            FoodDetailSheet(
                food: food,
                categoryName: categories.first(where: { $0.id == food.categoryId })?.displayName(locale: locale),
                locationTitle: food.resolvedLocation(in: locations)?.displayName(locale: locale) ?? food.location.title(locale: locale),
                locationSymbol: food.resolvedLocation(in: locations)?.symbolName ?? food.location.symbolName,
                onEdit: {
                    let target = food
                    detailFood = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        editingFood = target
                    }
                },
                onConsumed: {
                    food.status = .consumed
                    food.resolvedDate = .now
                    try? modelContext.save()
                    WidgetSnapshotWriter.refresh(context: modelContext)
                    Task { await NotificationScheduler.reschedule(settings: settings, context: modelContext) }
                    detailFood = nil
                },
                onWasted: {
                    food.status = .wasted
                    food.resolvedDate = .now
                    try? modelContext.save()
                    WidgetSnapshotWriter.refresh(context: modelContext)
                    Task { await NotificationScheduler.reschedule(settings: settings, context: modelContext) }
                    detailFood = nil
                }
            )
        }
        .sheet(item: $editingFood) { food in
            FoodEntryView(existing: food) {
                editingFood = nil
                WidgetSnapshotWriter.refresh(context: modelContext)
                Task { await NotificationScheduler.reschedule(settings: settings, context: modelContext) }
            }
        }
    }

    // MARK: - Search Header & Bar

    private var searchHeader: some View {
        VStack(spacing: 12) {
            // Liquid glass search field capsule
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(settings.tint)

                TextField(locale.text("search.prompt"), text: $query)
                    .font(.body)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        remember(query)
                    }

                if !query.isEmpty {
                    Button {
                        Motion.hapticSelection()
                        withAnimation(Motion.snappy) {
                            query = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.8)
            }
            .shadow(color: settings.tint.opacity(0.15), radius: 8, y: 3)

            // Scopes picker pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SearchScope.allCases) { scope in
                        let isSelected = selectedScope == scope
                        Button {
                            Motion.hapticSelection()
                            withAnimation(Motion.liquidSpring) {
                                selectedScope = scope
                            }
                        } label: {
                            Text(scope.title(locale: locale))
                                .font(.caption.weight(isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background {
                                    if isSelected {
                                        Capsule()
                                            .fill(settings.tint)
                                            .matchedGeometryEffect(id: "search-scope-pill", in: scopeNamespace)
                                            .shadow(color: settings.tint.opacity(0.3), radius: 6, y: 2)
                                    } else {
                                        Capsule()
                                            .fill(.ultraThinMaterial.opacity(0.6))
                                            .overlay {
                                                Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                                            }
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Empty Query State (History & Quick Filters)

    private var emptyQueryContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Recent Searches (if available)
            if !history.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(locale.text("search.recent"), systemImage: "clock.arrow.circlepath")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Button(locale.text("search.clear")) {
                            withAnimation(Motion.snappy) {
                                for item in history {
                                    modelContext.delete(item)
                                }
                                try? modelContext.save()
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    }

                    FlowLayout(spacing: 8) {
                        ForEach(history, id: \.timestamp) { item in
                            Button {
                                Motion.hapticSelection()
                                withAnimation(Motion.snappy) {
                                    query = item.query
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(item.query)
                                        .font(.subheadline.weight(.medium))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay {
                                    Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
                                }
                                .foregroundStyle(.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .liquidCard(cornerRadius: 22)
            }

            // Quick Discover / Popular Filter Tags
            VStack(alignment: .leading, spacing: 12) {
                Label(locale.text("search.quickFilters"), systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.primary)

                FlowLayout(spacing: 8) {
                    // Predefined freshness filters
                    quickFilterChip(title: locale.text("search.expiringSoon"), icon: "clock.badge.exclamationmark") {
                        query = locale.text("search.expiringSoon")
                    }

                    quickFilterChip(title: locale.text("search.expired"), icon: "exclamationmark.octagon") {
                        query = locale.text("search.expired")
                    }

                    // Built-in storage locations
                    ForEach(locations, id: \.id) { loc in
                        quickFilterChip(title: loc.displayName(locale: locale), icon: loc.symbolName) {
                            selectedScope = .location
                            query = loc.displayName(locale: locale)
                        }
                    }

                    // Discovered owners in user inventory
                    ForEach(availableOwners, id: \.self) { owner in
                        quickFilterChip(title: owner, icon: "person.fill") {
                            selectedScope = .owner
                            query = owner
                        }
                    }
                }
            }
            .padding(16)
            .liquidCard(cornerRadius: 22)

            // Search Guide Helper Card
            HStack(spacing: 14) {
                Image(systemName: "info.circle.fill")
                    .font(.title2)
                    .foregroundStyle(settings.tint)

                Text(locale.text("search.emptyHint"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .liquidCard(cornerRadius: 20, tint: settings.tint.opacity(0.06))
        }
    }

    private func quickFilterChip(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Motion.hapticSelection()
            withAnimation(Motion.snappy) {
                action()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(settings.tint)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            }
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Results List

    private var resultsContent: some View {
        VStack(spacing: 10) {
            ForEach(results, id: \.id) { food in
                Button {
                    Motion.hapticSelection()
                    remember(query)
                    detailFood = food
                } label: {
                    HStack(spacing: 12) {
                        // Freshness status dot
                        Circle()
                            .fill(FreshnessPalette.color(for: food.freshness))
                            .frame(width: 10, height: 10)
                            .shadow(color: FreshnessPalette.color(for: food.freshness).opacity(0.5), radius: 3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(food.name)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)

                            HStack(spacing: 6) {
                                // Storage location
                                Text(food.resolvedLocation(in: locations)?.displayName(locale: locale)
                                     ?? food.location.title(locale: locale))

                                // Owner badge
                                if let owner = food.owner, !owner.isEmpty {
                                    Text("·")
                                    Label(owner, systemImage: "person.fill")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(settings.tint)
                                }

                                // Remaining days
                                if let days = food.remainingDays {
                                    Text("·")
                                    Text(RemainingDaysCopy.label(days: days, locale: locale, short: true))
                                        .foregroundStyle(FreshnessPalette.color(for: food.freshness))
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                    .padding(14)
                    .liquidCard(cornerRadius: 18)
                }
                .buttonStyle(PressScaleButtonStyle(pressedScale: 0.98))
            }
        }
    }

    // MARK: - No Results State

    private var noResultsContent: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary.opacity(0.6))
                .padding(.top, 30)

            Text(locale.text("search.noResults"))
                .font(.headline)
                .foregroundStyle(.primary)

            Text(locale.text("search.noResultsSubtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .liquidCard(cornerRadius: 22)
        .appearUp()
    }

    // MARK: - Matching Engine

    private var results: [FoodItemRecord] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }

        // Special freshness keyword handling
        let isSearchExpiringSoon = needle.caseInsensitiveCompare(locale.text("search.expiringSoon")) == .orderedSame
        let isSearchExpired = needle.caseInsensitiveCompare(locale.text("search.expired")) == .orderedSame

        return foods.filter { food in
            guard food.status == .active else { return false }

            if isSearchExpiringSoon {
                if let days = food.remainingDays {
                    return days >= 0 && days <= 7
                }
                return false
            }

            if isSearchExpired {
                if let days = food.remainingDays {
                    return days < 0
                }
                return false
            }

            switch selectedScope {
            case .all:
                let matchesName = food.name.localizedCaseInsensitiveContains(needle)
                let matchesOwner = food.owner?.localizedCaseInsensitiveContains(needle) ?? false
                let matchesNotes = food.notes.localizedCaseInsensitiveContains(needle)
                let matchesLocation = food.resolvedLocation(in: locations)?.displayName(locale: locale).localizedCaseInsensitiveContains(needle)
                    ?? food.location.title(locale: locale).localizedCaseInsensitiveContains(needle)
                let matchesCategory = categories.first(where: { $0.id == food.categoryId })?.displayName(locale: locale).localizedCaseInsensitiveContains(needle) ?? false

                return matchesName || matchesOwner || matchesNotes || matchesLocation || matchesCategory

            case .name:
                return food.name.localizedCaseInsensitiveContains(needle)

            case .owner:
                return food.owner?.localizedCaseInsensitiveContains(needle) ?? false

            case .location:
                return food.resolvedLocation(in: locations)?.displayName(locale: locale).localizedCaseInsensitiveContains(needle)
                    ?? food.location.title(locale: locale).localizedCaseInsensitiveContains(needle)

            case .category:
                return categories.first(where: { $0.id == food.categoryId })?.displayName(locale: locale).localizedCaseInsensitiveContains(needle) ?? false
            }
        }
    }

    private var availableOwners: [String] {
        let raw = foods
            .filter { $0.status == .active }
            .compactMap { food -> String? in
                guard let o = food.owner?.trimmingCharacters(in: .whitespacesAndNewlines), !o.isEmpty else { return nil }
                return o
            }
        return Array(Set(raw)).sorted()
    }

    private func remember(_ raw: String) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        if let existing = history.first(where: { $0.query.compare(value, options: .caseInsensitive) == .orderedSame }) {
            existing.timestamp = .now
        } else {
            modelContext.insert(SearchHistoryRecord(query: value))
        }
        try? modelContext.save()
    }
}

// Flow layout for dynamic tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: width, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
