import SwiftUI

struct FoodCard: View {
    var food: FoodItemRecord
    var categoryName: String?
    var locationTitle: String
    var locationSymbol: String
    var selected: Bool
    @Environment(\.locale) private var locale

    private var freshnessColor: Color {
        FreshnessPalette.color(for: food.freshness)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top food visual and translucent glass status bar
            ZStack(alignment: .topTrailing) {
                foodImage
                    .frame(height: 114)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        // Storage location liquid glass pill
                        HStack(spacing: 4) {
                            Image(systemName: locationSymbol)
                                .font(.caption2.weight(.bold))
                            Text(locationTitle)
                                .font(.caption2.weight(.semibold))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
                        }
                        .foregroundStyle(.primary)
                        .padding(8)
                    }

                // Expiry progress ring
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 30, height: 30)
                        .overlay {
                            Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
                        }
                    FreshnessRing(progress: food.usedProgress, freshness: food.freshness, lineWidth: 3.5)
                        .frame(width: 22, height: 22)
                }
                .padding(8)
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            }

            // Food title
            Text(food.name)
                .font(.headline.weight(.semibold))
                .lineLimit(2)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            // Expiry countdown and category tags
            HStack(alignment: .center, spacing: 7) {
                circularDaysBadge

                HStack(spacing: 5) {
                    if let categoryName {
                        Text(categoryName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let owner = food.owner, !owner.isEmpty {
                        if categoryName != nil {
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(.secondary.opacity(0.6))
                        }
                        Text(owner)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .frame(minHeight: 204)
        .background {
            // Liquid glass background with ambient sheen
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)

                // Freshness ambient aura glow
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.4),
                                .init(color: freshnessColor.opacity(0.09), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                if selected {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                }
            }
        }
        .overlay {
            // Liquid dual-layer specular highlight border
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    selected
                    ? LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.42), location: 0),
                            .init(color: .white.opacity(0.12), location: 0.4),
                            .init(color: freshnessColor.opacity(0.2), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: selected ? 2.5 : 0.8
                )
        }
        .shadow(
            color: selected ? Color.accentColor.opacity(0.25) : freshnessColor.opacity(0.08),
            radius: selected ? 14 : 8,
            x: 0,
            y: selected ? 6 : 4
        )
        .scaleEffect(selected ? 0.97 : 1)
        .animation(Motion.snappy, value: selected)
        .animation(Motion.liquidSpring, value: food.freshness)
    }

    @ViewBuilder
    private var foodImage: some View {
        if let image = ImageStore.load(food) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .transition(.opacity)
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        FreshnessPalette.fill(for: food.freshness),
                        freshnessColor.opacity(0.24)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: locationSymbol == "snowflake" ? "snowflake" : "carrot.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.95), freshnessColor.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: freshnessColor.opacity(0.35), radius: 6, y: 3)
                    .symbolEffect(.pulse, options: .repeating.speed(0.35), value: food.freshness)
            }
        }
    }

    private var daysNumberText: String {
        guard let days = food.remainingDays else { return "–" }
        let absDays = abs(days)
        return absDays > 99 ? "99+" : "\(absDays)"
    }

    private var circularDaysBadge: some View {
        ZStack {
            Circle()
                .fill(freshnessColor)

            Text(daysNumberText)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 26, height: 26)
        .overlay {
            Circle()
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
        }
        .shadow(color: freshnessColor.opacity(0.35), radius: 3, x: 0, y: 1.5)
        .accessibilityLabel(RemainingDaysCopy.label(days: food.remainingDays, locale: locale))
    }
}

