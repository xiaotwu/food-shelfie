import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsHomeView: View {
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        settingsLabel("paintpalette.fill", locale.text("settings.appearance"))
                    }
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        settingsLabel("bell.badge.fill", locale.text("settings.notifications"))
                    }
                    NavigationLink {
                        DataSettingsView()
                    } label: {
                        settingsLabel("externaldrive.fill", locale.text("settings.data"))
                    }
                    NavigationLink {
                        OtherSettingsView()
                    } label: {
                        settingsLabel("slider.horizontal.3", locale.text("settings.more"))
                    }
                }

                Section {
                    NavigationLink {
                        AboutSettingsView()
                    } label: {
                        settingsLabel("info.circle.fill", locale.text("settings.about"))
                    }
                }
            }
            .navigationTitle(locale.text("settings.title"))
        }
    }

    private func settingsLabel(_ symbol: String, _ title: String) -> some View {
        Label(title, systemImage: symbol)
    }
}

struct AppearanceSettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.locale) private var locale

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section(locale.text("settings.theme")) {
                Picker(locale.text("settings.appearance"), selection: $settings.themeMode) {
                    ForEach(ThemeMode.allCases) { mode in
                        Text(mode.title(locale: locale)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.themeMode) { _, _ in settings.persist() }
            }
            Section(locale.text("settings.accent")) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                    ForEach(SeedColor.allCases) { color in
                        Button {
                            withAnimation(Motion.snappy) {
                                settings.seedColor = color
                            }
                            settings.persist()
                        } label: {
                            Circle()
                                .fill(color.color)
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if settings.seedColor == color {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .scaleEffect(settings.seedColor == color ? 1.08 : 1)
                        }
                        // 明确指定 plain 样式,否则 Form 中的 Button 只有图形时手势可能被系统样式吞掉
                        .buttonStyle(.plain)
                        .accessibilityLabel(color.title(locale: locale))
                    }
                }
                .padding(.vertical, 4)
                .animation(Motion.snappy, value: settings.seedColor)
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
        Form {
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
            Button(locale.text("settings.deleteAll"), role: .destructive) {
                showDeleteConfirm = true
            }
            if let message {
                Text(message).foregroundStyle(.secondary).transition(.opacity)
            }
        }
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

            Toggle(locale.text("settings.iCloud"), isOn: $settings.iCloudSyncEnabled)
                .onChange(of: settings.iCloudSyncEnabled) { _, _ in settings.persist() }
            Text(locale.text("settings.iCloudFootnote"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(locale.text("settings.more"))
    }
}

struct AboutSettingsView: View {
    @Environment(\.locale) private var locale
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Liquid Glass 头部卡片
                VStack(spacing: 8) {
                    Image("BrandMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    Text("Shelfie")
                        .font(.title.bold())
                    Text("\(locale.text("about.version")) \(version)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(locale.text("settings.aboutBlurb"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.1), radius: 12, y: 6)

                // 功能亮点
                VStack(alignment: .leading, spacing: 14) {
                    Text(locale.text("about.features"))
                        .font(.headline)
                        .padding(.leading, 4)
                    featureRow("barcode.viewfinder", locale.text("about.feature.scan"))
                    featureRow("refrigerator.fill", locale.text("about.feature.track"))
                    featureRow("bell.badge.fill", locale.text("about.feature.widgets"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                }

                // 隐私
                VStack(alignment: .leading, spacing: 8) {
                    Text(locale.text("settings.privacy"))
                        .font(.headline)
                    Text(locale.text("settings.privacyBody"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                }

                VStack(spacing: 6) {
                    Text("\(locale.text("about.madeWith")) SwiftUI · SwiftData · Vision · WidgetKit")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("© 2026 Shelfie · \(locale.text("settings.inspired"))")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(locale.text("settings.about"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func featureRow(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body)
                .frame(width: 28, height: 28)
                .foregroundStyle(.tint)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(text)
                .font(.subheadline)
        }
    }
}
