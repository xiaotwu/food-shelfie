import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: loadSnapshot())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadSnapshot() -> WidgetSnapshot {
        guard let data = try? Data(contentsOf: AppGroup.snapshotURL),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .placeholder
        }
        return snapshot
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct ExpiringWidgetView: View {
    var entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(locale.text("widget.expiring"))
                    .font(.headline)
                Spacer()
                Text("\(entry.snapshot.expiringSoonCount)")
                    .font(.title2.weight(.bold))
            }
            if entry.snapshot.foodsThisWeek.isEmpty {
                Text(locale.text("widget.empty"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.snapshot.foodsThisWeek.prefix(family == .systemSmall ? 2 : 5)) { food in
                    HStack {
                        Text(food.name)
                            .lineLimit(1)
                        Spacer()
                        Text(food.remainingDays == 0 ? locale.text("widget.today") : locale.format("widget.daysShort", food.remainingDays))
                            .foregroundStyle(food.remainingDays <= 1 ? Color.red : Color.secondary)
                    }
                    .font(.caption)
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct FreshnessWidgetView: View {
    var entry: SnapshotEntry
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(locale.text("widget.thisWeek"))
                .font(.headline)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(entry.snapshot.weeklyCounts.enumerated()), id: \.offset) { index, count in
                    VStack {
                        Capsule()
                            .fill(Color.green.opacity(count == 0 ? 0.25 : 0.9))
                            .frame(width: 10, height: CGFloat(max(count, 1)) * 14)
                        Text(weekday(index))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack {
                Label(locale.format("widget.expiredCount", entry.snapshot.expiredCount), systemImage: "exclamationmark.triangle")
                Spacer()
                Text(locale.format("widget.soonCount", entry.snapshot.expiringSoonCount))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func weekday(_ index: Int) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        let mondayFirst = Array(symbols[1...]) + [symbols[0]]
        return mondayFirst[index]
    }
}

struct ExpiringWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ShelfieExpiringWidget", provider: Provider()) { entry in
            ExpiringWidgetView(entry: entry)
        }
        .configurationDisplayName(String(localized: "widget.expiringName"))
        .description(String(localized: "widget.expiringDesc"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FreshnessWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ShelfieFreshnessWidget", provider: Provider()) { entry in
            FreshnessWidgetView(entry: entry)
        }
        .configurationDisplayName(String(localized: "widget.freshnessName"))
        .description(String(localized: "widget.freshnessDesc"))
        .supportedFamilies([.systemMedium])
    }
}

@main
struct ShelfieWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ExpiringWidget()
        FreshnessWidget()
    }
}

private extension WidgetSnapshot {
    static var placeholder: WidgetSnapshot {
        WidgetSnapshot(
            expiredCount: 1,
            expiringSoonCount: 3,
            weeklyCounts: [0, 1, 0, 2, 1, 0, 0],
            foodsThisWeek: [
                WidgetFoodSnapshot(id: UUID(), name: "Milk", expiryDate: .now, remainingDays: 1, location: .fridge),
                WidgetFoodSnapshot(id: UUID(), name: "Spinach", expiryDate: .now, remainingDays: 2, location: .fridge)
            ],
            updatedAt: .now
        )
    }
}
