import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct FoodEntryDraft: Equatable {
    var name: String = ""
    var expiryDate: Date?
    var purchaseDate: Date = .now
    var image: UIImage?
    var categoryID: UUID?
    var location: StorageLocation = .fridge
    var notes: String = ""
    var owner: String = ""
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
    var onSaved: () -> Void

    @State private var name = ""
    @State private var owner = ""
    @State private var expiryDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
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

    var body: some View {
        NavigationStack {
            ZStack {
                // Ambient light canvas
                Glass.ambientBackground(tint: settings.tint)

                ScrollView {
                    VStack(spacing: 18) {
                        // 1. Food name & photo card
                        nameAndPhotoCard
                            .appearUp()

                        // 2. Expiry dates & quick presets card
                        datesAndPresetsCard
                            .appearUp(delay: 0.06)

                        // 3. Storage location & category card
                        storageAndCategoryCard
                            .appearUp(delay: 0.12)

                        // 4. Notes card
                        notesCard
                            .appearUp(delay: 0.18)
                    }
                    .padding(18)
                    .padding(.bottom, 40)
                }
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
                    Button(locale.text("entry.save"), action: save)
                        .disabled(!isValid)
                        .font(.body.weight(.bold))
                        .foregroundStyle(isValid ? settings.tint : .secondary.opacity(0.5))
                        .symbolEffect(.bounce, value: savedTick)
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
                    let trimmed = newLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    let location = LocationRecord(
                        name: trimmed,
                        symbolName: "shippingbox",
                        sortOrder: 100 + locations.count
                    )
                    modelContext.insert(location)
                    withAnimation(Motion.snappy) { locationID = location.id }
                    newLocationName = ""
                }
                Button(locale.text("entry.cancel"), role: .cancel) {}
            }
            .alert(locale.text("entry.newCategory"), isPresented: $showNewCategory) {
                TextField(locale.text("entry.categoryName"), text: $newCategoryName)
                Button(locale.text("entry.add")) {
                    let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    let category = CategoryRecord(name: trimmed)
                    modelContext.insert(category)
                    withAnimation(Motion.snappy) { categoryID = category.id }
                    newCategoryName = ""
                }
                Button(locale.text("entry.cancel"), role: .cancel) {}
            }
            .sensoryFeedback(.success, trigger: savedTick)
        }
    }

    // 1. Food name & photo card
    private var nameAndPhotoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
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

                VStack(alignment: .leading, spacing: 6) {
                    Text(locale.text("entry.name"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    TextField(locale.text("entry.name"), text: $name)
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
        .padding(18)
        .liquidCard(cornerRadius: 22)
    }

    // 2. Expiry dates & quick presets card
    private var datesAndPresetsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(locale.text("entry.dates"), systemImage: "clock.badge.exclamationmark")
                .font(.headline)
                .foregroundStyle(.primary)

            // Quick preset chips (+3d, +7d, +2w, +1m)
            VStack(alignment: .leading, spacing: 8) {
                Text(locale.text("entry.quickExpiry"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    quickPresetChip(days: 3, label: locale.text("entry.quickDays3"))
                    quickPresetChip(days: 7, label: locale.text("entry.quickWeek1"))
                    quickPresetChip(days: 14, label: locale.text("entry.quickWeeks2"))
                    quickPresetChip(days: 30, label: locale.text("entry.quickMonth1"))
                }
            }

            Divider()
                .opacity(0.4)

            DatePicker(
                locale.text("entry.expiry"),
                selection: $expiryDate,
                displayedComponents: .date
            )
            .environment(\.locale, locale)
            .environment(\.calendar, locale.gregorianCalendar)

            DatePicker(
                locale.text("entry.purchased"),
                selection: $purchaseDate,
                displayedComponents: .date
            )
            .environment(\.locale, locale)
            .environment(\.calendar, locale.gregorianCalendar)

            if let message = FoodValidator.validateExpiryDate(expiryDate, purchaseDate: purchaseDate).message(locale: locale) {
                Text(message)
                    .foregroundStyle(.red)
                    .font(.caption2.weight(.semibold))
            }
        }
        .padding(18)
        .liquidCard(cornerRadius: 22)
    }

    private func quickPresetChip(days: Int, label: String) -> some View {
        Button {
            Motion.hapticSelection()
            withAnimation(Motion.snappy) {
                if let target = Calendar.current.date(byAdding: .day, value: days, to: purchaseDate) {
                    expiryDate = target
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

    private var isValid: Bool {
        FoodValidator.validateName(name).isValid &&
        FoodValidator.validateExpiryDate(expiryDate, purchaseDate: purchaseDate).isValid &&
        FoodValidator.validatePurchaseDate(purchaseDate).isValid
    }

    private func hydrate() {
        if let existing {
            name = existing.name
            expiryDate = existing.expiryDate ?? expiryDate
            purchaseDate = existing.purchaseDate
            locationID = existing.locationId ?? existing.resolvedLocation(in: locations)?.id
            categoryID = existing.categoryId
            notes = existing.notes
            owner = existing.owner ?? ""
            image = ImageStore.load(existing)
        } else if let draft {
            name = draft.name
            if let expiry = draft.expiryDate { expiryDate = expiry }
            purchaseDate = draft.purchaseDate
            locationID = locations.first(where: { $0.builtInKey == draft.location.rawValue })?.id
            categoryID = draft.categoryID
            notes = draft.notes
            owner = draft.owner
            image = draft.image
        }
        if locationID == nil {
            locationID = locations.first(where: { $0.builtInKey == StorageLocation.fridge.rawValue })?.id
                ?? locations.first?.id
        }
    }

    private func save() {
        let selectedLocation = locations.first(where: { $0.id == locationID })
        let builtIn = selectedLocation.flatMap { record in
            record.builtInKey.flatMap(StorageLocation.init(rawValue:))
        } ?? .other
        let trimmedOwner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedOwner = trimmedOwner.isEmpty ? nil : trimmedOwner

        if let existing {
            existing.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.refreshNormalizedName()
            existing.expiryDate = expiryDate
            existing.purchaseDate = purchaseDate
            existing.categoryId = categoryID
            existing.notes = notes
            existing.owner = resolvedOwner
            if let selectedLocation {
                existing.apply(locationRecord: selectedLocation)
            } else {
                existing.location = builtIn
            }
            if let image {
                ImageStore.assign(image, to: existing)
            }
        } else {
            let food = FoodItemRecord(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                categoryId: categoryID,
                locationId: locationID,
                location: builtIn,
                purchaseDate: purchaseDate,
                expiryDate: expiryDate,
                notes: notes,
                owner: resolvedOwner
            )
            if let selectedLocation {
                food.apply(locationRecord: selectedLocation)
            }
            if let image {
                ImageStore.assign(image, to: food)
            }
            modelContext.insert(food)
        }
        try? modelContext.save()
        savedTick.toggle()
        WidgetSnapshotWriter.refresh(context: modelContext)
        Task { await NotificationScheduler.reschedule(settings: settings, context: modelContext) }
        onSaved()
        dismiss()
    }
}
