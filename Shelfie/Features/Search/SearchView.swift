import SwiftData
import SwiftUI

struct SearchView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Query(sort: \FoodItemRecord.name) private var foods: [FoodItemRecord]
    @Query(sort: \SearchHistoryRecord.timestamp, order: .reverse) private var history: [SearchHistoryRecord]
    @Query(sort: \CategoryRecord.name) private var categories: [CategoryRecord]
    @Query(sort: \LocationRecord.sortOrder) private var locations: [LocationRecord]

    @State private var query = ""
    @State private var detailFood: FoodItemRecord?

    var body: some View {
        Group {
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                historyList
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
                    .appearUp()
            } else {
                List(results, id: \.id) { food in
                    Button {
                        remember(query)
                        detailFood = food
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(food.name)
                            Text(food.resolvedLocation(in: locations)?.displayName(locale: locale)
                                 ?? food.location.title(locale: locale))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .animation(Motion.soft, value: results.map(\.id))
            }
        }
        .navigationTitle(locale.text("search.title"))
        .searchable(text: $query, prompt: locale.text("search.prompt"))
        .sheet(item: $detailFood) { food in
            FoodDetailSheet(
                food: food,
                categoryName: categories.first(where: { $0.id == food.categoryId })?.displayName(locale: locale),
                locationTitle: food.resolvedLocation(in: locations)?.displayName(locale: locale) ?? food.location.title(locale: locale),
                locationSymbol: food.resolvedLocation(in: locations)?.symbolName ?? food.location.symbolName,
                onEdit: {},
                onConsumed: {
                    food.status = .consumed
                    food.resolvedDate = .now
                    try? modelContext.save()
                    detailFood = nil
                },
                onWasted: {
                    food.status = .wasted
                    food.resolvedDate = .now
                    try? modelContext.save()
                    detailFood = nil
                }
            )
        }
    }

    private var historyList: some View {
        List {
            if !history.isEmpty {
                Section(locale.text("search.recent")) {
                    ForEach(history, id: \.timestamp) { item in
                        Button(item.query) {
                            withAnimation(Motion.snappy) { query = item.query }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            modelContext.delete(history[index])
                        }
                    }
                }
            }
        }
    }

    private var results: [FoodItemRecord] {
        let needle = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return foods.filter {
            $0.status == .active && $0.normalizedName.contains(needle)
        }
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
