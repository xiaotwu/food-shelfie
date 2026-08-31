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
            Form {
                Section {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        HStack(spacing: 16) {
                            Group {
                                if let image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .transition(.scale.combined(with: .opacity))
                                } else {
                                    ZStack {
                                        Color.secondary.opacity(0.12)
                                        Image(systemName: "photo.badge.plus")
                                            .font(.title2)
                                            .symbolEffect(.pulse, options: .repeating.speed(0.4), value: image == nil)
                                    }
                                }
                            }
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .animation(Motion.snappy, value: image != nil)
                            VStack(alignment: .leading) {
                                Text(locale.text("entry.photo"))
                                    .font(.headline)
                                Text(locale.text("entry.photoHint"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    TextField(locale.text("entry.name"), text: $name)
                    if let message = FoodValidator.validateName(name).message(locale: locale), !name.isEmpty {
                        Text(message).foregroundStyle(.red).font(.caption)
                    }
                }

                Section(locale.text("entry.dates")) {
                    DatePicker(locale.text("entry.expiry"), selection: $expiryDate, displayedComponents: .date)
                        .environment(\.locale, locale)
                        .environment(\.calendar, locale.gregorianCalendar)
                    DatePicker(locale.text("entry.purchased"), selection: $purchaseDate, displayedComponents: .date)
                        .environment(\.locale, locale)
                        .environment(\.calendar, locale.gregorianCalendar)
                    if let message = FoodValidator.validateExpiryDate(expiryDate, purchaseDate: purchaseDate).message(locale: locale) {
                        Text(message).foregroundStyle(.red).font(.caption)
                    }
                }

                Section(locale.text("entry.storage")) {
                    Picker(locale.text("entry.location"), selection: $locationID) {
                        ForEach(locations, id: \.id) { location in
                            Label(location.displayName(locale: locale), systemImage: location.symbolName)
                                .tag(Optional(location.id))
                        }
                    }
                    Button(locale.text("location.new")) {
                        showNewLocation = true
                    }
                    Picker(locale.text("entry.category"), selection: $categoryID) {
                        Text(locale.text("category.uncategorized")).tag(Optional<UUID>.none)
                        ForEach(categories, id: \.id) { category in
                            Text(category.displayName(locale: locale)).tag(Optional(category.id))
                        }
                    }
                    Button(locale.text("entry.newCategory")) {
                        showNewCategory = true
                    }
                }

                Section(locale.text("entry.notes")) {
                    TextField(locale.text("entry.notesPlaceholder"), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(existing == nil ? locale.text("entry.addTitle") : locale.text("entry.editTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.locale, locale)
            .environment(\.calendar, locale.gregorianCalendar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locale.text("entry.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(locale.text("entry.save"), action: save)
                        .disabled(!isValid)
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
            image = ImageStore.load(existing)
        } else if let draft {
            name = draft.name
            if let expiry = draft.expiryDate { expiryDate = expiry }
            purchaseDate = draft.purchaseDate
            locationID = locations.first(where: { $0.builtInKey == draft.location.rawValue })?.id
            categoryID = draft.categoryID
            notes = draft.notes
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

        if let existing {
            existing.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.refreshNormalizedName()
            existing.expiryDate = expiryDate
            existing.purchaseDate = purchaseDate
            existing.categoryId = categoryID
            existing.notes = notes
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
                notes: notes
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
