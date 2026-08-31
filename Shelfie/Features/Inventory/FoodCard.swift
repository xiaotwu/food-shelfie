import SwiftUI

struct FoodCard: View {
    var food: FoodItemRecord
    var categoryName: String?
    var locationTitle: String
    var locationSymbol: String
    var selected: Bool
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                foodImage
                    .frame(height: 110)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                FreshnessRing(progress: food.usedProgress, freshness: food.freshness, lineWidth: 4)
                    .frame(width: 22, height: 22)
                    .padding(8)
            }

            Text(food.name)
                .font(.headline)
                .lineLimit(2)
                .foregroundStyle(.primary)

            Text(RemainingDaysCopy.label(days: food.remainingDays, locale: locale, short: true))
                .font(.caption.weight(.semibold))
                .foregroundStyle(FreshnessPalette.color(for: food.freshness))
                .contentTransition(.numericText())

            HStack(spacing: 6) {
                Image(systemName: locationSymbol)
                    .symbolEffect(.pulse, options: .nonRepeating, value: food.id)
                Text(locationTitle)
                if let categoryName {
                    Text("·")
                    Text(categoryName)
                        .lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 3)
        }
        .scaleEffect(selected ? 0.98 : 1)
        .animation(Motion.snappy, value: selected)
        .animation(Motion.soft, value: food.freshness)
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
                FreshnessPalette.fill(for: food.freshness)
                Image(systemName: "carrot.fill")
                    .font(.title)
                    .foregroundStyle(FreshnessPalette.color(for: food.freshness))
                    .symbolEffect(.pulse, options: .repeating.speed(0.35), value: food.freshness)
            }
        }
    }
}
