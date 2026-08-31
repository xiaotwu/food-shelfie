import SwiftData
import SwiftUI

struct FoodDetailSheet: View {
    var food: FoodItemRecord
    var categoryName: String?
    var locationTitle: String
    var locationSymbol: String
    var onEdit: () -> Void
    var onConsumed: () -> Void
    var onWasted: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                        .appearUp()
                    HStack(spacing: 12) {
                        infoCard(
                            title: locale.text("detail.boughtOn"),
                            value: food.purchaseDate.formatted(date: .abbreviated, time: .omitted)
                        )
                        infoCard(
                            title: locale.text("detail.expiresOn"),
                            value: food.expiryDate?.formatted(date: .abbreviated, time: .omitted)
                                ?? locale.text("detail.unknown")
                        )
                    }
                    .appearUp(delay: 0.05)
                    if !food.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(locale.text("detail.notes"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(food.notes)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .appearUp(delay: 0.1)
                    }
                }
                .padding(20)
            }
            .navigationTitle(food.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(locale.text("detail.edit"), action: onEdit)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button(role: .destructive, action: onWasted) {
                        Text(locale.text("detail.discard"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button(action: onConsumed) {
                        Text(locale.text("detail.eaten"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .symbolEffect(.bounce, value: food.status)
                }
                .padding(20)
                .background(.bar)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Group {
                if let image = ImageStore.load(food) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        FreshnessPalette.fill(for: food.freshness)
                        Image(systemName: "carrot.fill")
                            .font(.largeTitle)
                            .foregroundStyle(FreshnessPalette.color(for: food.freshness))
                    }
                }
            }
            .frame(width: 108, height: 108)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(RemainingDaysCopy.label(days: food.remainingDays, locale: locale))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(FreshnessPalette.color(for: food.freshness))
                    .contentTransition(.numericText())
                Label(locationTitle, systemImage: locationSymbol)
                    .foregroundStyle(.secondary)
                if let categoryName {
                    Text(categoryName)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private func infoCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
