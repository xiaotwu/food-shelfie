import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: aged(loadSnapshot(), at: .now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let now = Date.now
        let source = loadSnapshot()
        var entries = [SnapshotEntry(date: now, snapshot: aged(source, at: now))]
        for offset in 1...7 {
            if let day = Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: now)) {
                entries.append(SnapshotEntry(date: day, snapshot: aged(source, at: day)))
            }
        }
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(next)))
    }

    private func loadSnapshot() -> WidgetSnapshot {
        guard let data = try? Data(contentsOf: AppGroup.snapshotURL),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return WidgetSnapshot(expiredCount: 0, expiringSoonCount: 0, weeklyCounts: Array(repeating: 0, count: 7),
                                  foodsThisWeek: [], updatedAt: .now)
        }
        return snapshot
    }

    private func aged(_ source: WidgetSnapshot, at date: Date) -> WidgetSnapshot {
        let calendar = Calendar.current
        let foods = source.foodsThisWeek.map { food in
            var copy = food
            copy.remainingDays = FreshnessRules.remainingDays(from: food.expiryDate, now: date, calendar: calendar) ?? 0
            return copy
        }
        let today = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: today)
        let monday = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: today) ?? today
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: monday) ?? monday
        var counts = Array(repeating: 0, count: 7)
        for food in foods where food.expiryDate >= monday && food.expiryDate < weekEnd {
            let index = (calendar.component(.weekday, from: food.expiryDate) + 5) % 7
            counts[index] += 1
        }
        return WidgetSnapshot(expiredCount: foods.filter { $0.remainingDays < 0 }.count,
                              expiringSoonCount: foods.filter { (0...7).contains($0.remainingDays) }.count,
                              weeklyCounts: counts, foodsThisWeek: foods.filter { $0.remainingDays <= 7 },
                              updatedAt: source.updatedAt)
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
                    if family == .systemSmall {
                        foodRow(food)
                    } else {
                        Link(destination: foodURL(food.id)) { foodRow(food) }
                            .accessibilityLabel("\(food.name), \(dayLabel(food.remainingDays))")
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(family == .systemSmall ? entry.snapshot.foodsThisWeek.first.map { foodURL($0.id) } ?? URL(string: "shelfie://shelf") : URL(string: "shelfie://shelf"))
    }

    private func foodURL(_ id: UUID) -> URL { URL(string: "shelfie://food/\(id.uuidString)")! }

    private func dayLabel(_ days: Int) -> String {
        if days < 0 { return locale.format("widget.overdueDays", -days) }
        return days == 0 ? locale.text("widget.today") : locale.format("widget.daysShort", days)
    }

    private func foodRow(_ food: WidgetFoodSnapshot) -> some View {
        HStack {
            Text(food.name).lineLimit(1)
            Spacer()
            Text(dayLabel(food.remainingDays))
                .foregroundStyle(food.remainingDays <= 1 ? Color.red : Color.secondary)
        }
        .font(.caption)
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
                            .frame(width: 10, height: min(CGFloat(max(count, 1)) * 14, 64))
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
        .widgetURL(URL(string: "shelfie://shelf"))
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
