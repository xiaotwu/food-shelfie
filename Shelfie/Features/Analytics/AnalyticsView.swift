import Charts
import SwiftData
import SwiftUI

struct AnalyticsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.locale) private var locale
    @Query private var foods: [FoodItemRecord]
    @State private var period: AnalyticsPeriod = .month

    private var snapshot: AnalyticsSnapshot {
        AnalyticsEngine.snapshot(
            items: foods.map {
                .init(status: $0.status, expiryDate: $0.expiryDate, resolvedDate: $0.resolvedDate, purchaseDate: $0.purchaseDate)
            },
            period: period
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        statCard(
                            title: locale.text("insights.expired"),
                            value: "\(snapshot.expiredCount)",
                            color: FreshnessPalette.color(for: .expired)
                        )
                        .appearUp()
                        statCard(
                            title: locale.text("insights.expiringWeek"),
                            value: "\(snapshot.expiringSoonCount)",
                            color: FreshnessPalette.color(for: .warning)
                        )
                        .appearUp(delay: 0.06)
                    }
                    .animation(Motion.snappy, value: snapshot.expiredCount)

                    Picker("", selection: $period) {
                        ForEach(AnalyticsPeriod.allCases) { item in
                            Text(item.title(locale: locale)).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: period) { _, _ in
                        withAnimation(Motion.soft) {}
                    }

                    chartCard(title: locale.text("insights.weekChart")) {
                        Chart(snapshot.weekly) { point in
                            BarMark(
                                x: .value("Day", point.date, unit: .day),
                                y: .value("Count", point.count)
                            )
                            .foregroundStyle(settings.tint)
                            .cornerRadius(6)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { _ in
                                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            }
                        }
                        .frame(height: 220)
                        .animation(Motion.soft, value: snapshot.weekly.map(\.count))
                    }
                    .appearUp(delay: 0.1)

                    chartCard(title: locale.text("insights.freshnessHistory")) {
                        let freshness = snapshot.freshness
                        let slices: [(Freshness, Int)] = [
                            (.fresh, freshness.fresh),
                            (.warning, freshness.warning),
                            (.urgent, freshness.urgent),
                            (.expired, freshness.expiry)
                        ]
                        if freshness.total == 0 {
                            Text(locale.text("insights.freshnessEmpty"))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 24)
                        } else {
                            Chart(slices, id: \.0) { item in
                                SectorMark(
                                    angle: .value("Count", item.1),
                                    innerRadius: .ratio(0.56)
                                )
                                .foregroundStyle(FreshnessPalette.color(for: item.0))
                            }
                            .frame(height: 220)
                            .animation(Motion.soft, value: freshness.total)
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(slices, id: \.0) { item in
                                    HStack {
                                        Circle().fill(FreshnessPalette.color(for: item.0)).frame(width: 8, height: 8)
                                        Text(item.0.title(locale: locale))
                                        Spacer()
                                        Text("\(item.1)")
                                            .foregroundStyle(.secondary)
                                            .contentTransition(.numericText())
                                    }
                                    .font(.footnote)
                                }
                            }
                        }
                    }
                    .appearUp(delay: 0.16)

                    chartCard(title: locale.text("insights.eatenVsDiscarded")) {
                        Chart {
                            ForEach(snapshot.spoilage) { point in
                                LineMark(
                                    x: .value("Day", point.date),
                                    y: .value("Eaten", point.consumed),
                                    series: .value("Kind", locale.text("insights.eaten"))
                                )
                                .foregroundStyle(settings.tint)
                                LineMark(
                                    x: .value("Day", point.date),
                                    y: .value("Discarded", point.waste),
                                    series: .value("Kind", locale.text("insights.discarded"))
                                )
                                .foregroundStyle(FreshnessPalette.color(for: .expired))
                            }
                        }
                        .frame(height: 220)
                    }
                    .appearUp(delay: 0.22)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(locale.text("insights.title"))
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(color, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func chartCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
