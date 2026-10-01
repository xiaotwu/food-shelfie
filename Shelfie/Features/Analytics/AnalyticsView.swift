import Charts
import SwiftData
import SwiftUI

struct AnalyticsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var foods: [FoodItemRecord]
    @Namespace private var periodNamespace
    @State private var period: AnalyticsPeriod = .month

    private var snapshot: AnalyticsSnapshot {
        AnalyticsEngine.snapshot(
            items: foods.map {
                .init(status: $0.status, expiryDate: $0.effectiveExpiryDate, resolvedDate: $0.resolvedDate, purchaseDate: $0.purchaseDate)
            },
            period: period
        )
    }

    private var consumptionRate: Int? {
        let eaten = snapshot.spoilage.reduce(0) { $0 + $1.consumed }
        let wasted = snapshot.spoilage.reduce(0) { $0 + $1.waste }
        let total = eaten + wasted
        guard total > 0 else { return nil }
        return Int((Double(eaten) / Double(total)) * 100)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. Hero metric cards
                    adaptiveLayout(spacing: 12).callAsFunction {
                        luminousStatCard(
                            identifier: "insights.expired",
                            title: locale.text("insights.expired"),
                            value: "\(snapshot.expiredCount)",
                            icon: "exclamationmark.octagon.fill",
                            color: FreshnessPalette.color(for: .expired)
                        )
                        .appearUp()

                        luminousStatCard(
                            identifier: "insights.expiring",
                            title: locale.text("insights.expiringWeek"),
                            value: "\(snapshot.expiringSoonCount)",
                            icon: "clock.badge.exclamationmark.fill",
                            color: FreshnessPalette.color(for: .warning)
                        )
                        .appearUp(delay: 0.05)
                    }

                    // 2. Freshness & anti-waste efficiency banner
                    efficiencyBanner
                        .appearUp(delay: 0.08)

                    // 3. Liquid glass period segmented picker
                    periodPicker
                        .appearUp(delay: 0.1)

                    // 4. Expiry distribution chart
                    chartCard(
                        title: locale.text("insights.weekChart"),
                        icon: "chart.bar.xaxis"
                    ) {
                        Chart(snapshot.weekly) { point in
                            BarMark(
                                x: .value(locale.text("Day"), point.date, unit: .day),
                                y: .value(locale.text("Count"), point.count)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [settings.tint, settings.tint.opacity(0.65)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(8)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { _ in
                                AxisValueLabel(format: .dateTime.locale(locale).weekday(.abbreviated))
                            }
                        }
                        .frame(height: 200)
                        .animation(Motion.liquidSpring, value: snapshot.weekly.map(\.count))
                    }
                    .appearUp(delay: 0.12)

                    // 5. Freshness breakdown donut chart
                    chartCard(
                        title: locale.text("insights.freshnessHistory"),
                        icon: "chart.pie.fill"
                    ) {
                        let freshness = snapshot.freshness
                        let slices: [(Freshness, Int)] = [
                            (.fresh, freshness.fresh),
                            (.warning, freshness.warning),
                            (.urgent, freshness.urgent),
                            (.expired, freshness.expiry)
                        ]
                        if freshness.total == 0 {
                            Text(locale.text("insights.freshnessEmpty"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 160)
                        } else {
                            adaptiveLayout(spacing: 20).callAsFunction {
                                ZStack {
                                    Chart(slices, id: \.0) { item in
                                        SectorMark(
                                            angle: .value(locale.text("Count"), item.1),
                                            innerRadius: .ratio(0.64),
                                            angularInset: 2.0
                                        )
                                        .cornerRadius(5)
                                        .foregroundStyle(FreshnessPalette.color(for: item.0))
                                    }
                                    .frame(width: 150, height: 150)

                                    VStack(spacing: 2) {
                                        Text("\(freshness.total)")
                                            .font(.title2.weight(.bold))
                                            .contentTransition(.numericText())
                                        Text(locale.text("tab.shelf"))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(slices, id: \.0) { item in
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(FreshnessPalette.color(for: item.0))
                                                .frame(width: 8, height: 8)
                                            Text(item.0.title(locale: locale))
                                                .font(.caption.weight(.medium))
                                            Spacer()
                                            Text("\(item.1)")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.secondary)
                                                .contentTransition(.numericText())
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            .animation(Motion.liquidSpring, value: freshness.total)
                        }
                    }
                    .appearUp(delay: 0.15)

                    // 6. Eaten vs discarded trend chart
                    chartCard(
                        title: locale.text("insights.eatenVsDiscarded"),
                        icon: "arrow.up.arrow.down.circle.fill"
                    ) {
                        Chart {
                            ForEach(snapshot.spoilage) { point in
                                LineMark(
                                    x: .value(locale.text("Day"), point.date),
                                    y: .value(locale.text("Eaten"), point.consumed),
                                    series: .value(locale.text("Kind"), locale.text("insights.eaten"))
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(settings.tint)
                                .lineStyle(StrokeStyle(lineWidth: 3))

                                AreaMark(
                                    x: .value(locale.text("Day"), point.date),
                                    y: .value(locale.text("Eaten"), point.consumed),
                                    series: .value(locale.text("Kind"), locale.text("insights.eaten"))
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(settings.tint.opacity(0.12))

                                LineMark(
                                    x: .value(locale.text("Day"), point.date),
                                    y: .value(locale.text("Discarded"), point.waste),
                                    series: .value(locale.text("Kind"), locale.text("insights.discarded"))
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(FreshnessPalette.color(for: .expired))
                                .lineStyle(StrokeStyle(lineWidth: 3))
                            }
                        }
                        .frame(height: 200)
                    }
                    .appearUp(delay: 0.18)
                }
                .padding(18)
                .floatingDockClearance()
            }
            .navigationTitle(locale.text("insights.title"))
            .navigationBarTitleDisplayMode(.inline)
            .globalShelfToolbar(title: locale.text("insights.title"))
        }
    }

    private func adaptiveLayout(spacing: CGFloat) -> AnyLayout {
        dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing)) : AnyLayout(HStackLayout(spacing: spacing))
    }

    // Luminous hero stat card
    private func luminousStatCard(identifier: String, title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)

                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
                    .padding(.top, 1)
            }

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .accessibilityIdentifier(identifier + ".count")
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 126,
               maxHeight: dynamicTypeSize.isAccessibilitySize ? nil : 126, alignment: .topLeading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.16), color.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.4), location: 0),
                            .init(color: color.opacity(0.3), location: 0.5),
                            .init(color: .white.opacity(0.1), location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
        .shadow(color: color.opacity(0.14), radius: 12, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier + ".card")
    }

    // Freshness & anti-waste efficiency banner
    private var efficiencyBanner: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(settings.tint.opacity(0.2), lineWidth: 5)
                    .frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: CGFloat(consumptionRate ?? 0) / 100.0)
                    .stroke(settings.tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 48, height: 48)
                Text(consumptionRate.map { "\($0)%" } ?? "—")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(settings.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(locale.text("insights.efficiency.title"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(locale.text(consumptionRate == nil ? "insights.efficiency.empty" : "insights.efficiency.subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .liquidCard(cornerRadius: 20, tint: settings.tint.opacity(0.08))
    }

    // Liquid glass segmented picker
    private var periodPicker: some View {
        adaptiveLayout(spacing: 8).callAsFunction {
            ForEach(AnalyticsPeriod.allCases) { item in
                let isSelected = period == item
                Button {
                    Motion.hapticSelection()
                    withAnimation(Motion.liquidSpring) {
                        period = item
                    }
                } label: {
                    Text(item.title(locale: locale))
                        .font(.subheadline.weight(isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? Color.white : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(settings.tint)
                                    .overlay { Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.75) }
                                    .shadow(color: settings.tint.opacity(0.35), radius: 8, y: 3)
                                    .matchedGeometryEffect(id: "period-picker-chip", in: periodNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
        }
    }

    private func chartCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(settings.tint)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidCard(cornerRadius: 24)
    }
}
