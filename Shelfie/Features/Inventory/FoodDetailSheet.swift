import SwiftData
import SwiftUI

struct FoodDetailSheet: View {
    var food: FoodItemRecord
    var categoryName: String?
    var locationTitle: String
    var locationSymbol: String
    var onEdit: () -> Void
    var onConsumed: () -> Bool
    var onWasted: () -> Bool
    var onPartialConsumption: (Double) -> Bool
    var onRepeatPurchase: () -> Void
    var onShopping: (() -> Bool)? = nil
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    @State private var showAmountEntry = false
    @State private var amountText = ""
    @State private var showSaveError = false
    @State private var addedToShopping = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var consumptionAmount: Double? {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        let input = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = formatter.decimalSeparator ?? "."
        let parts = input.components(separatedBy: separator)
        guard !input.isEmpty, parts.count <= 2,
              parts.joined().unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }),
              let number = formatter.number(from: input) else { return nil }
        let value = number.doubleValue
        guard FoodQuantity.isValid(value), value <= food.quantity else { return nil }
        return value
    }

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

                        glassInfoCard(title: locale.text("detail.quantity"), value: food.quantityLabel(locale: locale), icon: "number")

                        FlowLayout(spacing: 12) {
                            Button { amountText = ""; showAmountEntry = true } label: {
                                Label(locale.text("detail.consumePartial"), systemImage: "minus.circle")
                            }
                            .disabled(food.status != .active || food.quantity <= 0)
                            Button(action: onRepeatPurchase) {
                                Label(locale.text("detail.repeatPurchase"), systemImage: "plus.square.on.square")
                            }
                            if let onShopping {
                                Button {
                                    if onShopping() { addedToShopping = true } else { showSaveError = true }
                                } label: {
                                    Label(locale.text(addedToShopping ? "shopping.added" : "shopping.add"), systemImage: addedToShopping ? "checkmark" : "cart.badge.plus")
                                }
                            }
                        }
                        .font(.subheadline.weight(.semibold))

                        // Expiry lifecycle timeline
                        shelfLifeTimeline
                            .appearUp(delay: 0.05)

                        // Key dates and storage info grid
                        detailInfoLayout {
                            glassInfoCard(
                                title: locale.text("detail.boughtOn"),
                                value: food.purchaseDate.localizedDate(locale, date: .abbreviated),
                                icon: "calendar.badge.clock"
                            )
                            glassInfoCard(
                                title: locale.text("detail.packageExpiry"),
                                value: food.expiryDate?.localizedDate(locale, date: .abbreviated)
                                    ?? locale.text("detail.unknown"),
                                icon: "hourglass"
                            )
                        }
                        .appearUp(delay: 0.1)

                        if let openedDate = food.openedDate {
                            VStack(alignment: .leading, spacing: 12) {
                                glassInfoCard(title: locale.text("entry.openedDate"), value: openedDate.localizedDate(locale, date: .abbreviated), icon: "seal")
                                if let openedExpiry = food.openedExpiryDate {
                                    glassInfoCard(title: locale.text("detail.openedExpiry"), value: openedExpiry.localizedDate(locale, date: .abbreviated), icon: "clock")
                                }
                                if let effective = food.effectiveExpiryDate {
                                    glassInfoCard(title: locale.text("detail.effectiveExpiry"), value: effective.localizedDate(locale, date: .abbreviated), icon: "bell")
                                }
                                Text(locale.text("entry.openedHint")).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Text(locale.text("entry.batchHint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Storage and category row
                        detailInfoLayout {
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
                .accessibilityIdentifier("detail.scroll")
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
                    .accessibilityIdentifier("detail.close")
                    .accessibilityLabel(locale.text("shelf.cancel"))
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
                detailActionLayout {
                    Button(role: .destructive) {
                        if !onWasted() { showSaveError = true }
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
                        if !onConsumed() { showSaveError = true }
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
                    .symbolEffect(.bounce, value: reduceMotion ? FoodStatus.active : food.status)
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
        .alert(locale.text("detail.consumeAmount"), isPresented: $showAmountEntry) {
            TextField(locale.text("detail.consumeAmount"), text: $amountText)
                .keyboardType(.decimalPad)
            Button(locale.text("detail.consumePartial")) {
                if let amount = consumptionAmount, !onPartialConsumption(amount) { showSaveError = true }
            }
            .disabled(consumptionAmount == nil)
            Button(locale.text("shelf.cancel"), role: .cancel) { }
        } message: {
            Text(food.quantityLabel(locale: locale) + "\n" + locale.text("detail.consumeHint"))
        }
        .alert(locale.text("error.saveTitle"), isPresented: $showSaveError) {
            Button(locale.text("common.ok"), role: .cancel) { }
        } message: { Text(locale.text("error.saveMessage")) }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var detailActionLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .center, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
    }

    private var detailInfoLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
    }

    private var heroLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
    }

    private var heroHeader: some View {
        heroLayout {
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
                Text((food.openedDate ?? food.purchaseDate).localizedDate(locale, date: .numeric))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if let expiry = food.effectiveExpiryDate {
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
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidCard(cornerRadius: 18)
    }
}

// Captures exact values so both failed saves and explicit undo restore the prior inventory.
struct FoodActionSnapshot {
    let food: FoodItemRecord
    let quantity: Double
    let status: FoodStatus
    let resolvedDate: Date?

    init(_ food: FoodItemRecord) {
        self.food = food
        quantity = food.quantity
        status = food.status
        resolvedDate = food.resolvedDate
    }

    var matchesCurrent: Bool {
        food.modelContext != nil && !food.isDeleted && food.quantity == quantity
            && food.status == status && food.resolvedDate == resolvedDate
    }

    func restore() {
        food.quantity = quantity
        food.status = status
        food.resolvedDate = resolvedDate
    }
}

struct InventoryUndoBanner: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var reservesDockSpace = false
    var undo: () -> Void
    var close: () -> Void

    private var rowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
    }

    var body: some View {
        rowLayout {
            Text(locale.text("action.updated"))
                .font(.subheadline)
            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
            HStack(spacing: 16) {
            Button(locale.text("action.undo"), action: undo)
                .font(.subheadline.weight(.bold))
            Button(action: close) { Image(systemName: "xmark") }
                .accessibilityLabel(locale.text("shelf.cancel"))
                .frame(minWidth: 44, minHeight: 44)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.bottom, reservesDockSpace ? LayoutConstants.floatingDockClearance : 8)
    }
}
