import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsHomeView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Group 1: Core preferences
                    VStack(spacing: 2) {
                        NavigationLink {
                            AppearanceSettingsView()
                        } label: {
                            liquidSettingsRow(
                                symbol: "paintpalette.fill",
                                title: locale.text("settings.appearance")
                            )
                        }

                        Divider().padding(.leading, 52).opacity(0.4)

                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            liquidSettingsRow(
                                symbol: "bell.badge.fill",
                                title: locale.text("settings.notifications")
                            )
                        }

                        Divider().padding(.leading, 52).opacity(0.4)

                        NavigationLink {
                            DataSettingsView()
                        } label: {
                            liquidSettingsRow(
                                symbol: "externaldrive.fill",
                                title: locale.text("settings.data")
                            )
                        }

                        Divider().padding(.leading, 52).opacity(0.4)

                        NavigationLink {
                            OtherSettingsView()
                        } label: {
                            liquidSettingsRow(
                                symbol: "slider.horizontal.3",
                                title: locale.text("settings.more")
                            )
                        }
                    }
                    .padding(.vertical, 6)
                    .liquidCard(cornerRadius: 22)
                    .appearUp(delay: 0.06)

                    // Group 2: About & legal
                    VStack(spacing: 2) {
                        NavigationLink {
                            AboutSettingsView()
                        } label: {
                            liquidSettingsRow(
                                symbol: "info.circle.fill",
                                title: locale.text("settings.about")
                            )
                        }
                    }
                    .padding(.vertical, 6)
                    .liquidCard(cornerRadius: 22)
                    .appearUp(delay: 0.12)
                }
                .padding(18)
                .floatingDockClearance()
            }
            .navigationTitle(locale.text("settings.title"))
        }
    }

    private func liquidSettingsRow<Accessory: View>(
        symbol: String,
        title: String,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(settings.tint)
                .frame(width: 32, height: 32)
                .background(settings.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()

            accessory()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct AppearanceSettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.locale) private var locale
    @Namespace private var themeNamespace

    var body: some View {
        @Bindable var settings = settings
        ZStack {
            Glass.ambientBackground(tint: settings.tint)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Theme mode switch card
                    VStack(alignment: .leading, spacing: 14) {
                        Text(locale.text("settings.theme"))
                            .font(.headline)
                            .foregroundStyle(.primary)

                        HStack(spacing: 8) {
                            ForEach(ThemeMode.allCases) { mode in
                                let isSelected = settings.themeMode == mode
                                Button {
                                    Motion.hapticSelection()
                                    withAnimation(Motion.liquidSpring) {
                                        settings.themeMode = mode
                                    }
                                    settings.persist()
                                } label: {
                                    Text(mode.title(locale: locale))
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
                                                    .matchedGeometryEffect(id: "theme-mode-chip", in: themeNamespace)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay { Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5) }
                    }
                    .padding(18)
                    .liquidCard(cornerRadius: 22)

                    // Accent seed color grid
                    VStack(alignment: .leading, spacing: 14) {
                        Text(locale.text("settings.accent"))
                            .font(.headline)
                            .foregroundStyle(.primary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 14) {
                            ForEach(SeedColor.allCases) { color in
                                let isSelected = settings.seedColor == color
                                Button {
                                    Motion.hapticImpact(.light)
                                    withAnimation(Motion.liquidSpring) {
                                        settings.seedColor = color
                                    }
                                    settings.persist()
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(color.color)
                                            .frame(width: 44, height: 44)
                                            .shadow(color: color.color.opacity(isSelected ? 0.45 : 0.15), radius: isSelected ? 8 : 4, y: 3)

                                        if isSelected {
                                            Circle()
                                                .strokeBorder(.white, lineWidth: 2.5)
                                                .frame(width: 44, height: 44)

                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.heavy))
                                                .foregroundStyle(.white)
                                                .transition(.scale.combined(with: .opacity))
                                        }
                                    }
                                    .scaleEffect(isSelected ? 1.12 : 1.0)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(color.title(locale: locale))
                            }
                        }
                        .padding(.vertical, 6)
                        .animation(Motion.liquidSpring, value: settings.seedColor)
                    }
                    .padding(18)
                    .liquidCard(cornerRadius: 22)
                }
                .padding(18)
                .floatingDockClearance()
            }
        }
        .navigationTitle(locale.text("settings.appearance"))
    }
}

struct NotificationSettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale

    var body: some View {
        @Bindable var settings = settings
        Form {
            Toggle(locale.text("settings.expiryReminders"), isOn: $settings.notificationsEnabled)
            Toggle(locale.text("settings.weeklySummary"), isOn: $settings.weeklyReportEnabled)
            DatePicker(
                locale.text("settings.dailyReminder"),
                selection: $settings.reminderDate,
                displayedComponents: .hourAndMinute
            )
            DayStepperField(
                title: locale.text("settings.warnDaysShort"),
                value: $settings.warningDays,
                range: 0...14
            )
            DayStepperField(
                title: locale.text("settings.autoDeleteShort"),
                value: $settings.autoDeleteConsumedAfterDays,
                range: 0...90
            )
        }
        .safeAreaPadding(.bottom, LayoutConstants.floatingDockClearance)
        .navigationTitle(locale.text("settings.notifications"))
        .onChange(of: settings.notificationsEnabled) { _, _ in persistAndSchedule() }
        .onChange(of: settings.weeklyReportEnabled) { _, _ in persistAndSchedule() }
        .onChange(of: settings.warningDays) { _, _ in persistAndSchedule() }
        .onChange(of: settings.autoDeleteConsumedAfterDays) { _, _ in persistAndSchedule() }
        .onChange(of: settings.reminderHour) { _, _ in persistAndSchedule() }
        .onChange(of: settings.reminderMinute) { _, _ in persistAndSchedule() }
    }

    private func persistAndSchedule() {
        settings.persist()
        Task { await NotificationScheduler.reschedule(settings: settings, context: modelContext) }
    }
}

struct DayStepperField: View {
    var title: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    @State private var text: String = ""
    @State private var showWheel = false
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer()
                TextField("", text: $text)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 56)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(.quinary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .onChange(of: text) { _, new in
                        let filtered = new.filter(\.isNumber)
                        if filtered != new { text = filtered }
                        if let n = Int(filtered), range.contains(n) {
                            value = n
                        }
                    }
                Stepper("", value: $value, in: range)
                    .labelsHidden()
                    .frame(width: 94)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(Motion.gentle) { showWheel.toggle() }
            }

            if showWheel {
                Picker("", selection: $value) {
                    ForEach(Array(range), id: \.self) { n in
                        Text(locale.format("settings.daysValue", n)).tag(n)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 110)
                .clipped()
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .padding(.vertical, 4)
        .onAppear { text = "\(value)" }
        .onChange(of: value) { _, new in
            let s = "\(new)"
            if text != s { text = s }
        }
    }
}

struct DataSettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var showDeleteConfirm = false
    @State private var message: String?

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Toggle(locale.text("settings.iCloud"), isOn: $settings.iCloudSyncEnabled)
                    .onChange(of: settings.iCloudSyncEnabled) { _, _ in settings.persist() }
            } footer: {
                Text(locale.text("settings.iCloudFootnote"))
            }

            Section {
                Button(locale.text("settings.export")) {
                    do {
                        let payload = try BackupService.exportPayload(context: modelContext)
                        exportURL = try BackupService.writeJSON(from: payload)
                    } catch {
                        message = error.localizedDescription
                    }
                }
                Button(locale.text("settings.import")) {
                    showImporter = true
                }
            }

            Section {
                Button(locale.text("settings.deleteAll"), role: .destructive) {
                    showDeleteConfirm = true
                }
            }

            if let message {
                Text(message).foregroundStyle(.secondary).transition(.opacity)
            }
        }
        .safeAreaPadding(.bottom, LayoutConstants.floatingDockClearance)
        .animation(Motion.soft, value: message)
        .navigationTitle(locale.text("settings.data"))
        .fileExporter(
            isPresented: Binding(
                get: { exportURL != nil },
                set: { if !$0 { exportURL = nil } }
            ),
            document: exportURL.map { FileDocumentWrapper(url: $0) },
            contentType: .json,
            defaultFilename: "shelfie-backup"
        ) { _ in
            exportURL = nil
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result {
                do {
                    try BackupService.importJSON(from: url, context: modelContext)
                    message = locale.text("settings.backupRestored")
                } catch {
                    message = error.localizedDescription
                }
            }
        }
        .confirmationDialog(
            locale.text("settings.deleteConfirm"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(locale.text("settings.deleteAll"), role: .destructive) {
                try? BackupService.deleteAll(context: modelContext)
                SeedData.ensureDefaultCategories(context: modelContext)
                SeedData.ensureDefaultLocations(context: modelContext)
                message = locale.text("settings.allDeleted")
            }
        }
    }
}

struct FileDocumentWrapper: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var url: URL

    init(url: URL) {
        self.url = url
    }

    init(configuration: ReadConfiguration) throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("import.json")
        if let data = configuration.file.regularFileContents {
            try data.write(to: url)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try Data(contentsOf: url))
    }
}

struct OtherSettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.locale) private var locale

    var body: some View {
        @Bindable var settings = settings
        Form {
            Picker(locale.text("settings.language"), selection: $settings.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.title(locale: locale)).tag(language)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: settings.language) { _, _ in settings.persist() }

            Toggle(locale.text("settings.lock"), isOn: $settings.biometricLockEnabled)
                .onChange(of: settings.biometricLockEnabled) { _, enabled in
                    if enabled {
                        Task {
                            let ok = await BiometricAuth.unlock(reason: locale.text("settings.enableLock"))
                            await MainActor.run {
                                withAnimation(Motion.snappy) {
                                    settings.biometricLockEnabled = ok
                                    settings.isUnlocked = true
                                }
                                settings.persist()
                            }
                        }
                    } else {
                        settings.persist()
                    }
                }

            Toggle(locale.text("settings.groupByCategory"), isOn: $settings.groupByCategory)
                .onChange(of: settings.groupByCategory) { _, _ in settings.persist() }
        }
        .safeAreaPadding(.bottom, LayoutConstants.floatingDockClearance)
        .navigationTitle(locale.text("settings.more"))
    }
}

struct AboutSettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.locale) private var locale
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    @State private var floatingLogo = false

    var body: some View {
        ZStack {
            Glass.ambientBackground(tint: settings.tint)

            ScrollView {
                VStack(spacing: 24) {
                    // Minimalist Brand Hero
                    VStack(spacing: 12) {
                        Image("BrandMark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                            .shadow(color: settings.tint.opacity(0.32), radius: 14, y: 6)
                            .scaleEffect(floatingLogo ? 1.03 : 0.98)
                            .offset(y: floatingLogo ? -3 : 3)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                                    floatingLogo = true
                                }
                            }

                        Text("Shelfie")
                            .font(.system(.title2, design: .rounded).bold())

                        Text("\(locale.text("about.version")) \(version) (\(build))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(settings.tint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(settings.tint.opacity(0.12), in: Capsule())

                        Text(locale.text("about.tagline"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)

                    // Single sleek glass card with privacy info
                    aboutRow(
                        icon: "hand.raised.fill",
                        title: locale.text("settings.privacy"),
                        detail: locale.text("about.privacyRow")
                    )
                    .padding(.vertical, 4)
                    .liquidCard(cornerRadius: 22)

                    // Minimal footer
                    Text("© 2026 Shelfie")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 16)
                        .floatingDockClearance()
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle(locale.text("settings.about"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func aboutRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(settings.tint)
                .frame(width: 28, height: 28)
                .background(settings.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
