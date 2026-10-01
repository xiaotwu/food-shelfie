import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Optional expiry is preserved until the user explicitly chooses a date.
struct FoodEntryExpirySelection: Equatable {
    var date: Date
    var hasDate: Bool
    var requiresConfirmation: Bool
    var confirmed: Bool

    init(date: Date? = nil, requiresConfirmation: Bool = false, now: Date = .now) {
        self.date = date ?? now
        hasDate = date != nil
        self.requiresConfirmation = requiresConfirmation
        confirmed = !requiresConfirmation
    }

    var storedDate: Date? { hasDate ? date : nil }
    var canSave: Bool { !requiresConfirmation || confirmed }

    mutating func chooseDate(_ date: Date) {
        self.date = date
        hasDate = true
        confirmed = true
    }

    mutating func chooseNoDate() {
        hasDate = false
        confirmed = true
    }
}

enum FoodEntryShoppingConversion {
    enum ConversionError: Error { case missingSource, alreadyAdded }

    static func commit(foodID: UUID, shoppingItemID: UUID, context: ModelContext,
                       save: (ModelContext) throws -> Void = { try $0.save() }) throws {
        do {
            try link(foodID: foodID, shoppingItemID: shoppingItemID, context: context)
            try save(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Link the source in the food's transaction so a failed save cannot mark it bought.
    static func link(foodID: UUID, shoppingItemID: UUID, context: ModelContext) throws {
        let id = shoppingItemID
        let query = FetchDescriptor<ShoppingItemRecord>(predicate: #Predicate { $0.id == id })
        guard let source = try context.fetch(query).first else { throw ConversionError.missingSource }
        guard source.inventoryFoodID == nil else { throw ConversionError.alreadyAdded }
        source.inventoryFoodID = foodID
        source.isCompleted = true
    }
}

struct FoodEntryDraft: Equatable {
    var name: String = ""
    var expiryDate: Date?
    var purchaseDate: Date = .now
    var image: UIImage?
    var categoryID: UUID?
    var locationID: UUID?
    var quantity: Double = 1
    var unit: FoodUnit = .piece
    var requiresExpiryConfirmation = false
    var openedDate: Date?
    var openedShelfLifeDays: Int?
    var lowStockThreshold: Double?
    var location: StorageLocation = .fridge
    var notes: String = ""
    var owner: String = ""
    var lookupNotice: String?

    static func confirmedDateScan(expiryDate: Date, now: Date = .now) -> FoodEntryDraft {
        FoodEntryDraft(expiryDate: expiryDate, purchaseDate: now)
    }

    /// A new purchase intentionally does not inherit the previous batch's dates.
    static func repeatPurchase(from item: FoodItemRecord) -> FoodEntryDraft {
        FoodEntryDraft(
            name: item.name,
            image: ImageStore.load(item),
            categoryID: item.categoryId,
            locationID: item.locationId,
            unit: FoodUnit(rawValue: item.unitRaw) ?? .piece,
            requiresExpiryConfirmation: true,
            openedShelfLifeDays: item.openedShelfLifeDays,
            lowStockThreshold: item.lowStockThreshold,
            location: item.location,
            notes: item.notes,
            owner: item.owner ?? ""
        )
    }
}

struct FoodEntryView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Query(sort: \CategoryRecord.name) private var categories: [CategoryRecord]
    @Query(sort: \LocationRecord.sortOrder) private var locations: [LocationRecord]

    var existing: FoodItemRecord?
    var draft: FoodEntryDraft?
    var shoppingItemID: UUID? = nil
    var onSaved: () -> Void

    @State private var name = ""
    @State private var owner = ""
    @State private var expirySelection = FoodEntryExpirySelection()
    @State private var purchaseDate = Date.now
    @State private var locationID: UUID?
    @State private var categoryID: UUID?
    @State private var notes = ""
    @State private var image: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var newCategoryName = ""
    @State private var newLocationName = ""
    @State private var showNewCategory = false
    @State private var showNewLocation = false
    @State private var savedTick = false
    @State private var quantityText = "1"
    @State private var unit: FoodUnit = .piece
    @State private var showMoreInformation = false
    @State private var didNotifySource = false
    @State private var formSessionID = UUID()
    @State private var lookupNotice: String?
    @State private var hasHydrated = false
    @State private var saveError: String?
    @State private var isOpened = false
    @State private var openedDate = Date.now
    @State private var openedDaysText = "7"
    @State private var trackLowStock = false
    @State private var thresholdText = "1"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ZStack {
                // Ambient light canvas
                Glass.ambientBackground(tint: settings.tint)

                ScrollView {
                    VStack(spacing: 18) {
                        if let notice = lookupNotice {
                            Label(notice, systemImage: "info.circle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        // 1. Food name & photo card
                        nameAndPhotoCard
                            .appearUp()

                        // 2. Expiry dates & quick presets card
                        datesAndPresetsCard
                            .appearUp(delay: 0.06)

                        // 3. Storage location & category card
                        storageAndCategoryCard
                            .appearUp(delay: 0.12)

                        DisclosureGroup(locale.text("entry.moreInformation"), isExpanded: $showMoreInformation) {
                            VStack(spacing: 18) {
                                ownerCard
                                openingAndStockCard
                                notesCard
                            }
                            .padding(.top, 12)
                        }
                        .accessibilityIdentifier("entry.moreInformation")
                        .padding(18)
                        .liquidCard(cornerRadius: 22)

                        if existing == nil {
                            Button(locale.text("entry.saveAndContinue")) { save(continueAdding: true) }
                                .buttonStyle(.borderedProminent)
                                .tint(settings.tint)
                                .disabled(!isValid)
                                .accessibilityIdentifier("entry.saveAndContinue")
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 40)
                }
                .id(formSessionID)
                .accessibilityIdentifier("entry.scroll")
            }
            .navigationTitle(existing == nil ? locale.text("entry.addTitle") : locale.text("entry.editTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.locale, locale)
            .environment(\.calendar, locale.gregorianCalendar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locale.text("entry.cancel")) { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(locale.text("entry.save")) { save() }
                        .disabled(!isValid)
                        .font(.body.weight(.bold))
                        .foregroundStyle(isValid ? settings.tint : .secondary.opacity(0.5))
                        .symbolEffect(.bounce, value: reduceMotion ? false : savedTick)
                }
            }
            .onAppear(perform: hydrate)
            .onChange(of: pickerItem) { _, item in
                Task {
                    if let item, let data = try? await item.loadTransferable(type: Data.self), let loaded = UIImage(data: data) {
                        withAnimation(Motion.snappy) { image = loaded }
                    }
                }
            }
            .alert(locale.text("location.new"), isPresented: $showNewLocation) {
                TextField(locale.text("location.name"), text: $newLocationName)
                Button(locale.text("entry.add")) {
                    addLocation()
                }
                Button(locale.text("entry.cancel"), role: .cancel) {}
            }
            .alert(locale.text("entry.newCategory"), isPresented: $showNewCategory) {
                TextField(locale.text("entry.categoryName"), text: $newCategoryName)
                Button(locale.text("entry.add")) {
                    addCategory()
                }
                Button(locale.text("entry.cancel"), role: .cancel) {}
            }
            .alert(locale.text("entry.saveErrorTitle"), isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button(locale.text("entry.ok"), role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
            .sensoryFeedback(.success, trigger: savedTick)
        }
    }

    private var entryRowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
    }

    // 1. Food name & photo card
    private var nameAndPhotoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            entryRowLayout {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                ZStack {
                                    LinearGradient(
                                        colors: [settings.tint.opacity(0.18), settings.tint.opacity(0.06)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                        .foregroundStyle(settings.tint)
                                }
                            }
                        }
                        .frame(width: 82, height: 82)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(.white.opacity(0.35), lineWidth: 0.8)
                        }
                        .shadow(color: settings.tint.opacity(0.18), radius: 8, y: 4)

                        // Camera badge
                        Image(systemName: "photo.badge.plus")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(settings.tint, in: Circle())
                            .offset(x: 4, y: 4)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(locale.text("entry.photo"))
                .accessibilityHint(locale.text("entry.photoHint"))

                VStack(alignment: .leading, spacing: 6) {
                    Text(locale.text("entry.name"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    TextField(locale.text("entry.name"), text: $name)
                        .accessibilityIdentifier("entry.name")
                        .font(.title3.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
                        }

                    if let message = FoodValidator.validateName(name).message(locale: locale), !name.isEmpty {
                        Text(message)
                            .foregroundStyle(.red)
                            .font(.caption2.weight(.semibold))
                    }
                }
            }

            Divider().opacity(0.4)

            entryRowLayout {
                VStack(alignment: .leading, spacing: 6) {
                    Text(locale.text("entry.quantity"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    TextField(locale.text("entry.quantity"), text: $quantityText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("entry.quantity")
                }
                Picker(locale.text("entry.unit"), selection: $unit) {
                    ForEach(FoodUnit.allCases, id: \.self) { value in
                        Text(value.title(locale: locale)).tag(value)
                    }
                }
                .accessibilityIdentifier("entry.unit")
            }
            if !isQuantityValid {
                Text(locale.text("entry.quantityInvalid"))
                    .font(.caption)
                    .foregroundStyle(.red)
            }

        }
        .padding(18)
        .liquidCard(cornerRadius: 22)
    }

    private var ownerCard: some View {
            // Owner input
            VStack(alignment: .leading, spacing: 6) {
                Label(locale.text("entry.owner"), systemImage: "person.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                TextField(locale.text("entry.ownerPlaceholder"), text: $owner)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
                    }
            }
    }

    // 2. Expiry dates & quick presets card
    private var datesAndPresetsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(locale.text("entry.dates"), systemImage: "clock.badge.exclamationmark")
                .font(.headline)
                .foregroundStyle(.primary)

            Toggle(locale.text("entry.hasExpiry"), isOn: Binding(
                get: { expirySelection.hasDate },
                set: { selected in
                    if selected { expirySelection.chooseDate(expirySelection.date) }
                    else { expirySelection.chooseNoDate() }
                }
            ))
            .accessibilityIdentifier("entry.hasExpiry")

            if expirySelection.hasDate {
                VStack(alignment: .leading, spacing: 8) {
                    Text(locale.text("entry.quickExpiry"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 8) {
                        quickPresetChip(days: 3, label: locale.text("entry.quickDays3"))
                        quickPresetChip(days: 7, label: locale.text("entry.quickWeek1"))
                        quickPresetChip(days: 14, label: locale.text("entry.quickWeeks2"))
                        quickPresetChip(days: 30, label: locale.text("entry.quickMonth1"))
                    }
                }
                DatePicker(locale.text("entry.expiry"), selection: Binding(
                    get: { expirySelection.date },
                    set: { expirySelection.chooseDate($0) }
                ), displayedComponents: .date)
                .environment(\.locale, locale)
                .environment(\.calendar, locale.gregorianCalendar)
            } else {
                Text(locale.text("entry.expiryNotSet"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if expirySelection.requiresConfirmation && !expirySelection.hasDate {
                Text(locale.text("entry.repeatExpiryChoice"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Toggle(locale.text("entry.confirmNoExpiry"), isOn: $expirySelection.confirmed)
                    .accessibilityIdentifier("entry.confirmExpiry")
            }

            DatePicker(
                locale.text("entry.purchased"),
                selection: $purchaseDate,
                displayedComponents: .date
            )
            .environment(\.locale, locale)
            .environment(\.calendar, locale.gregorianCalendar)

            if let expiry = expirySelection.storedDate, let message = FoodValidator.validateExpiryDate(expiry, purchaseDate: purchaseDate).message(locale: locale) {
                Text(message)
                    .foregroundStyle(.red)
                    .font(.caption2.weight(.semibold))
            }
        }
        .padding(18)
        .liquidCard(cornerRadius: 22)
    }

    private var openingAndStockCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(locale.text("entry.opened"), isOn: $isOpened)
                .accessibilityIdentifier("entry.opened")
            if isOpened {
                DatePicker(locale.text("entry.openedDate"), selection: $openedDate, displayedComponents: .date)
                Text(locale.text("entry.openedDays")).font(.subheadline)
                TextField(locale.text("entry.openedDays"), text: $openedDaysText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("entry.openedDays")
                Text(locale.text("entry.openedHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !openingValid {
                    Text(locale.text("entry.openedInvalid"))
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Divider()
            Toggle(locale.text("entry.lowStock"), isOn: $trackLowStock)
                .accessibilityIdentifier("entry.lowStock")
            if trackLowStock {
                Text(locale.text("entry.lowStockThreshold")).font(.subheadline)
                HStack {
                    TextField(locale.text("entry.lowStockThreshold"), text: $thresholdText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("entry.lowStockThreshold")
                    Text(unit.title(locale: locale))
                        .foregroundStyle(.secondary)
                }
                Text(locale.text("entry.lowStockHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !thresholdValid {
                    Text(locale.text("entry.lowStockInvalid"))
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Text(locale.text("entry.batchHint"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .liquidCard(cornerRadius: 22)
    }

    private func quickPresetChip(days: Int, label: String) -> some View {
        Button {
            Motion.hapticSelection()
            withAnimation(Motion.snappy) {
                if let target = Calendar.current.date(byAdding: .day, value: days, to: purchaseDate) {
                    expirySelection.chooseDate(target)
                }
            }
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                }
                .foregroundStyle(settings.tint)
        }
        .buttonStyle(.plain)
    }

    // 3. Storage location & category visual selector
    private var storageAndCategoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(locale.text("entry.storage"), systemImage: "archivebox.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            // Storage location capsule row
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(locale.text("entry.location"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(locale.text("location.new")) {
                        showNewLocation = true
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(settings.tint)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(locations, id: \.id) { loc in
                            let isSelected = locationID == loc.id
                            Button {
                                Motion.hapticSelection()
                                withAnimation(Motion.snappy) { locationID = loc.id }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: loc.symbolName)
                                        .font(.caption)
                                    Text(loc.displayName(locale: locale))
                                        .font(.caption.weight(isSelected ? .bold : .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background {
                                    if isSelected {
                                        Capsule()
                                            .fill(settings.tint)
                                            .overlay { Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.75) }
                                    } else {
                                        Capsule()
                                            .fill(.ultraThinMaterial)
                                            .overlay { Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5) }
                                    }
                                }
                                .foregroundStyle(isSelected ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Divider()
                .opacity(0.4)

            // Category capsule row
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(locale.text("entry.category"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(locale.text("entry.newCategory")) {
                        showNewCategory = true
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(settings.tint)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        let isUncategorized = categoryID == nil
                        Button {
                            Motion.hapticSelection()
                            withAnimation(Motion.snappy) { categoryID = nil }
                        } label: {
                            Text(locale.text("category.uncategorized"))
                                .font(.caption.weight(isUncategorized ? .bold : .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background {
                                    if isUncategorized {
                                        Capsule()
                                            .fill(settings.tint)
                                            .overlay { Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.75) }
                                    } else {
                                        Capsule()
                                            .fill(.ultraThinMaterial)
                                            .overlay { Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5) }
                                    }
                                }
                                .foregroundStyle(isUncategorized ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)

                        ForEach(categories, id: \.id) { cat in
                            let isSelected = categoryID == cat.id
                            Button {
                                Motion.hapticSelection()
                                withAnimation(Motion.snappy) { categoryID = cat.id }
                            } label: {
                                Text(cat.displayName(locale: locale))
                                    .font(.caption.weight(isSelected ? .bold : .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background {
                                        if isSelected {
                                            Capsule()
                                                .fill(settings.tint)
                                                .overlay { Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.75) }
                                        } else {
                                            Capsule()
                                                .fill(.ultraThinMaterial)
                                                .overlay { Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5) }
                                        }
                                    }
                                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(18)
        .liquidCard(cornerRadius: 22)
    }

    // 4. Notes card
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(locale.text("entry.notes"), systemImage: "pencil.line")
                .font(.headline)
                .foregroundStyle(.primary)

            TextField(locale.text("entry.notesPlaceholder"), text: $notes, axis: .vertical)
                .lineLimit(3...5)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
                }
        }
        .padding(18)
        .liquidCard(cornerRadius: 22)
    }

    private var quantity: Double {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        let separator = formatter.decimalSeparator ?? "."
        let input = quantityText.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: separator))
        guard !input.isEmpty,
              input.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              input.components(separatedBy: separator).count <= 2,
              let number = formatter.number(from: input) else { return .nan }
        return number.doubleValue
    }

    private var isQuantityValid: Bool {
        FoodQuantity.isValid(quantity) || (quantity == 0 && existing.map { $0.status != .active } == true)
    }

    private var openedDays: Int? { Int(openedDaysText.trimmingCharacters(in: .whitespacesAndNewlines)) }

    private var threshold: Double? { InventoryNumber.parse(thresholdText, locale: locale) }

    private var openingValid: Bool {
        guard isOpened else { return true }
        let calendar = locale.gregorianCalendar
        guard let days = openedDays, (1...365).contains(days) else { return false }
        return calendar.startOfDay(for: openedDate) >= calendar.startOfDay(for: purchaseDate)
            && calendar.startOfDay(for: openedDate) <= calendar.startOfDay(for: .now)
    }

    private var thresholdValid: Bool {
        !trackLowStock || threshold.map { $0 == 0 || FoodQuantity.isValid($0) } == true
    }

    private var isValid: Bool {
        expirySelection.canSave && isQuantityValid && openingValid && thresholdValid &&
        FoodValidator.validateName(name).isValid &&
        (expirySelection.storedDate == nil || FoodValidator.validateExpiryDate(expirySelection.storedDate, purchaseDate: purchaseDate).isValid) &&
        FoodValidator.validatePurchaseDate(purchaseDate).isValid
    }

    private func hydrate() {
        // Seed form state only once; appearances after a picker must preserve edits.
        guard !hasHydrated else { return }
        hasHydrated = true
        if let existing {
            quantityText = existing.quantity.formatted(.number.grouping(.never).locale(locale))
            unit = FoodUnit(rawValue: existing.unitRaw) ?? .piece
            isOpened = existing.openedDate != nil
            openedDate = existing.openedDate ?? .now
            openedDaysText = String(existing.openedShelfLifeDays ?? 7)
            trackLowStock = existing.lowStockThreshold != nil
            thresholdText = (existing.lowStockThreshold ?? 1).formatted(.number.grouping(.never).locale(locale))
            name = existing.name
            expirySelection = FoodEntryExpirySelection(date: existing.expiryDate)
            purchaseDate = existing.purchaseDate
            locationID = existing.locationId ?? existing.resolvedLocation(in: locations)?.id
            categoryID = existing.categoryId
            notes = existing.notes
            owner = existing.owner ?? ""
            image = ImageStore.load(existing)
        } else if let draft {
            quantityText = draft.quantity.formatted(.number.grouping(.never).locale(locale))
            unit = draft.unit
            expirySelection = FoodEntryExpirySelection(date: draft.expiryDate, requiresConfirmation: draft.requiresExpiryConfirmation)
            isOpened = draft.openedDate != nil
            openedDate = draft.openedDate ?? .now
            openedDaysText = String(draft.openedShelfLifeDays ?? 7)
            trackLowStock = draft.lowStockThreshold != nil
            thresholdText = (draft.lowStockThreshold ?? 1).formatted(.number.grouping(.never).locale(locale))
            name = draft.name
            purchaseDate = draft.purchaseDate
            locationID = draft.locationID ?? locations.first(where: { $0.builtInKey == draft.location.rawValue })?.id
            categoryID = draft.categoryID
            notes = draft.notes
            owner = draft.owner
            image = draft.image
            lookupNotice = draft.lookupNotice
        }
        showMoreInformation = !owner.isEmpty || !notes.isEmpty || isOpened || trackLowStock
            || existing?.openedShelfLifeDays != nil || draft?.openedShelfLifeDays != nil
        if locationID == nil {
            locationID = locations.first(where: { $0.builtInKey == StorageLocation.fridge.rawValue })?.id
                ?? locations.first?.id
        }
    }

    private func addLocation() {
        let trimmed = newLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let context = ModelContext(modelContext.container)
        context.autosaveEnabled = false
        let location = LocationRecord(name: trimmed, symbolName: "shippingbox", sortOrder: 100 + locations.count)
        context.insert(location)
        do {
            try context.save()
            withAnimation(Motion.snappy) { locationID = location.id }
            newLocationName = ""
        } catch {
            context.rollback()
            saveError = locale.text("entry.locationSaveError") + " " + error.localizedDescription
        }
    }

    private func addCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let context = ModelContext(modelContext.container)
        context.autosaveEnabled = false
        let category = CategoryRecord(name: trimmed)
        context.insert(category)
        do {
            try context.save()
            withAnimation(Motion.snappy) { categoryID = category.id }
            newCategoryName = ""
        } catch {
            context.rollback()
            saveError = locale.text("entry.categorySaveError") + " " + error.localizedDescription
        }
    }

    private func resetForNextItem() {
        name = ""
        owner = ""
        notes = ""
        image = nil
        pickerItem = nil
        quantityText = "1"
        unit = .piece
        expirySelection = FoodEntryExpirySelection()
        purchaseDate = .now
        isOpened = false
        openedDate = .now
        openedDaysText = "7"
        trackLowStock = false
        thresholdText = "1"
        showMoreInformation = false
        lookupNotice = nil
        formSessionID = UUID()
    }

    private func save(continueAdding: Bool = false) {
        guard isValid else { return }
        let context = ModelContext(modelContext.container)
        context.autosaveEnabled = false
        var newImageFileName: String?
        var oldImageFileName: String?

        do {
            let food: FoodItemRecord
            if let existing {
                let itemID = existing.id
                let descriptor = FetchDescriptor<FoodItemRecord>(predicate: #Predicate { $0.id == itemID })
                guard let persisted = try context.fetch(descriptor).first else {
                    saveError = locale.text("entry.missingFoodError")
                    return
                }
                food = persisted
                oldImageFileName = food.imageFileName
            } else {
                food = FoodItemRecord(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
                context.insert(food)
            }

            food.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            food.refreshNormalizedName()
            food.expiryDate = expirySelection.storedDate
            food.purchaseDate = purchaseDate
            food.categoryId = categoryID
            food.notes = notes
            food.quantity = quantity
            food.unitRaw = unit.rawValue
            food.openedDate = isOpened ? openedDate : nil
            food.openedShelfLifeDays = isOpened ? openedDays : nil
            food.lowStockThreshold = trackLowStock ? threshold : nil
            let trimmedOwner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
            food.owner = trimmedOwner.isEmpty ? nil : trimmedOwner
            if let selectedLocation = locations.first(where: { $0.id == locationID }) {
                food.apply(locationRecord: selectedLocation)
            } else {
                food.locationId = nil
                food.location = .other
            }

            if let image {
                guard let data = image.jpegData(compressionQuality: 0.82),
                      let fileName = ImageStore.save(image: image) else {
                    context.rollback()
                    saveError = locale.text("entry.photoSaveError")
                    return
                }
                newImageFileName = fileName
                food.photoData = data
                food.imageFileName = fileName
            }

            if !didNotifySource, let shoppingItemID {
                try FoodEntryShoppingConversion.commit(foodID: food.id, shoppingItemID: shoppingItemID, context: context)
            } else {
                try context.save()
            }
            if newImageFileName != nil, oldImageFileName != newImageFileName {
                ImageStore.delete(fileName: oldImageFileName)
            }
            savedTick.toggle()
            WidgetSnapshotWriter.refresh(context: context)
            Task { await NotificationScheduler.reschedule(settings: settings, context: context) }
            if !didNotifySource {
                didNotifySource = true
                onSaved()
            }
            if continueAdding {
                resetForNextItem()
            } else {
                dismiss()
            }
        } catch {
            context.rollback()
            ImageStore.delete(fileName: newImageFileName)
            if let sourceError = error as? FoodEntryShoppingConversion.ConversionError {
                switch sourceError {
                case .missingSource: saveError = locale.text("entry.shoppingSourceMissing")
                case .alreadyAdded: saveError = locale.text("entry.shoppingAlreadyAdded")
                }
            } else {
                saveError = locale.text("entry.saveError") + " " + error.localizedDescription
            }
        }
    }
}
