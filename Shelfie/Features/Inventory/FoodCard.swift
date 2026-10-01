import SwiftUI

struct FoodCard: View {
    var food: FoodItemRecord
    var categoryName: String?
    var locationTitle: String
    var locationSymbol: String
    var selected: Bool
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var freshnessColor: Color {
        FreshnessPalette.color(for: food.freshness)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let image = ImageStore.load(food) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 114)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityHidden(true)
            }
            HStack(alignment: .top, spacing: 6) {
                Label(locationTitle, systemImage: locationSymbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel(locale.text("shelf.selected"))
                }
            }

            // Food title
            Text(food.name)
                .font(.headline.weight(.semibold))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(locale.text("detail.boughtOn") + " " + food.purchaseDate.localizedDate(locale, date: .abbreviated))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(food.quantityLabel(locale: locale))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            // Expiry countdown and category tags
            VStack(alignment: .leading, spacing: 6) {
                Text(RemainingDaysCopy.label(days: food.remainingDays, locale: locale, short: true))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(freshnessColor)
                    .fixedSize(horizontal: false, vertical: true)

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

            }
        }
        .padding(12)
        .contentShape(Rectangle())
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
        .animation(reduceMotion ? nil : Motion.snappy, value: selected)
        .animation(reduceMotion ? nil : Motion.liquidSpring, value: food.freshness)
    }

}
