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
    @Environment(\.dismiss) private var dismiss

    private var freshnessColor: Color {
        FreshnessPalette.color(for: food.freshness)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Ambient light canvas background
                Glass.ambientBackground(tint: freshnessColor)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Hero visual header card
                        heroHeader
                            .appearUp()

                        // Expiry lifecycle timeline
                        shelfLifeTimeline
                            .appearUp(delay: 0.05)

                        // Key dates and storage info grid
                        HStack(spacing: 12) {
                            glassInfoCard(
                                title: locale.text("detail.boughtOn"),
                                value: food.purchaseDate.localizedDate(locale, date: .abbreviated),
                                icon: "calendar.badge.clock"
                            )
                            glassInfoCard(
                                title: locale.text("detail.expiresOn"),
                                value: food.expiryDate?.localizedDate(locale, date: .abbreviated)
                                    ?? locale.text("detail.unknown"),
                                icon: "hourglass"
                            )
                        }
                        .appearUp(delay: 0.1)

                        // Storage and category row
                        HStack(spacing: 12) {
                            glassInfoCard(
                                title: locale.text("entry.location"),
                                value: locationTitle,
                                icon: locationSymbol
                            )
                            if let categoryName {
                                glassInfoCard(
                                    title: locale.text("entry.category"),
                                    value: categoryName,
                                    icon: "tag.fill"
                                )
                            }
                        }
                        .appearUp(delay: 0.14)

                        // Owner info card
                        if let owner = food.owner, !owner.isEmpty {
                            glassInfoCard(
                                title: locale.text("entry.owner"),
                                value: owner,
                                icon: "person.fill"
                            )
                            .appearUp(delay: 0.16)
                        }

                        // Notes card
                        if !food.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(locale.text("detail.notes"), systemImage: "note.text")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(food.notes)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .liquidCard(cornerRadius: 20)
                            .appearUp(delay: 0.18)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 90)
                }
            }
            .navigationTitle(food.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        Motion.hapticSelection()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(locale.text("detail.edit")) {
                        Motion.hapticSelection()
                        onEdit()
                    }
                    .font(.body.weight(.semibold))
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Bottom liquid dual action bar
                HStack(spacing: 14) {
                    Button(role: .destructive) {
                        Motion.hapticNotification(.warning)
                        onWasted()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.fill")
                            Text(locale.text("detail.discard"))
                        }
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(FreshnessPalette.color(for: .expired))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(FreshnessPalette.color(for: .expired).opacity(0.35), lineWidth: 0.8)
                        }
                    }
                    .buttonStyle(PressScaleButtonStyle(pressedScale: 0.95))

                    Button {
                        Motion.hapticNotification(.success)
                        onConsumed()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text(locale.text("detail.eaten"))
                        }
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.16, green: 0.74, blue: 0.48),
                                    Color(red: 0.10, green: 0.60, blue: 0.38)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(.white.opacity(0.35), lineWidth: 0.8)
                        }
                        .shadow(color: Color.green.opacity(0.3), radius: 10, y: 5)
                    }
                    .buttonStyle(PressScaleButtonStyle(pressedScale: 0.95))
                    .symbolEffect(.bounce, value: food.status)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var heroHeader: some View {
        HStack(spacing: 16) {
            // Food image container
            Group {
                if let image = ImageStore.load(food) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [
                                FreshnessPalette.fill(for: food.freshness),
                                freshnessColor.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: locationSymbol == "snowflake" ? "snowflake" : "carrot.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(freshnessColor)
                    }
                }
            }
            .frame(width: 104, height: 104)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.3), lineWidth: 0.8)
            }
            .shadow(color: freshnessColor.opacity(0.18), radius: 10, y: 5)

            VStack(alignment: .leading, spacing: 8) {
                // Remaining days hero label
                Text(RemainingDaysCopy.label(days: food.remainingDays, locale: locale))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(freshnessColor)
                    .contentTransition(.numericText())

                // Status badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(freshnessColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: freshnessColor.opacity(0.8), radius: 3)
                    Text(food.freshness.title(locale: locale))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(freshnessColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(FreshnessPalette.fill(for: food.freshness), in: Capsule())

                HStack(spacing: 6) {
                    Image(systemName: locationSymbol)
                    Text(locationTitle)
                    if let categoryName {
                        Text("·")
                        Text(categoryName)
                    }
                    if let owner = food.owner, !owner.isEmpty {
                        Text("·")
                        Text(owner)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .liquidCard(cornerRadius: 24, tint: freshnessColor.opacity(0.08))
    }

    // Expiry lifecycle timeline
    private var shelfLifeTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(locale.text("about.feature.track"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(food.usedProgress * 100))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(freshnessColor)
            }

            // Timeline progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.16))
                        .frame(height: 8)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, freshnessColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * food.usedProgress, 8), height: 8)
                        .shadow(color: freshnessColor.opacity(0.4), radius: 4, y: 0)
                }
            }
            .frame(height: 8)

            HStack {
                Text(food.purchaseDate.localizedDate(locale, date: .numeric))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if let expiry = food.expiryDate {
                    Text(expiry.localizedDate(locale, date: .numeric))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(freshnessColor)
                }
            }
        }
        .padding(16)
        .liquidCard(cornerRadius: 20)
    }

    private func glassInfoCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidCard(cornerRadius: 18)
    }
}
