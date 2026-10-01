import AVFoundation
import ImageIO
import PhotosUI
import SwiftData
import SwiftUI
import Vision

enum ScannerMode: String, CaseIterable {
    case barcode
    case date

    func title(locale: Locale) -> String {
        switch self {
        case .barcode: locale.text("scanner.barcode")
        case .date: locale.text("scanner.date")
        }
    }
}

struct ScannerView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \CategoryRecord.name) private var categories: [CategoryRecord]
    @StateObject private var camera = CameraController()

    var onComplete: (FoodEntryDraft) -> Void

    @State private var mode: ScannerMode = .barcode
    @State private var status = ""
    @State private var isBusy = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var showPolicy = false
    @State private var cameraAuthorized = false
    @State private var capturePulse = false
    @State private var operation: Task<Void, Never>?
    @State private var failedBarcode: String?
    @State private var showManualBarcode = false
    @State private var manualBarcode = ""
    @State private var pendingScan: FoodDateScan?
    @State private var selectedExpiry: Date?
    @State private var showDateReview = false

    @Namespace private var scannerModeNamespace

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if cameraAuthorized {
                    CameraPreview(session: camera.session)
                        .ignoresSafeArea()
                        .transition(reduceMotion ? .identity : .opacity)
                }
                VStack {
                    Spacer()
                    ScanningPulse(isActive: isBusy || mode == .barcode)
                        .frame(width: 260, height: mode == .barcode ? 140 : 220)
                        .animation(reduceMotion ? nil : Motion.snappy, value: mode)
                        .accessibilityHidden(true)
                    Spacer()
                    controls
                }
                if isBusy {
                    ProgressView()
                        .controlSize(.large)
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(.white.opacity(0.3), lineWidth: 0.8)
                        }
                        .transition(reduceMotion ? .identity : .scale.combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : Motion.soft, value: isBusy)
            .navigationTitle(locale.text("scanner.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locale.text("scanner.close")) { operation?.cancel(); dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        camera.toggleTorch()
                    } label: {
                        if reduceMotion {
                            Image(systemName: "flashlight.on.fill")
                        } else {
                            Image(systemName: "flashlight.on.fill")
                                .symbolEffect(.bounce, value: cameraAuthorized)
                        }
                    }
                    .foregroundStyle(.white)
                    .disabled(!cameraAuthorized)
                    .accessibilityLabel(locale.text("scanner.torch"))
                }
            }
            .onAppear {
#if DEBUG
                // Exercise the real lookup and presentation flow without a camera in QA.
                let arguments = ProcessInfo.processInfo.arguments
                if let index = arguments.firstIndex(of: "--qa-barcode"), arguments.indices.contains(index + 1) {
                    startBarcode(arguments[index + 1])
                    return
                }
#endif
                if !settings.cameraPolicyAccepted {
                    showPolicy = true
                } else {
                    Task { await prepareCamera() }
                }
            }
            .onChange(of: mode) { _, newMode in
                operation?.cancel()
                isBusy = false
                failedBarcode = nil
                camera.resetBarcode()
                camera.barcodeEnabled = newMode == .barcode
                withAnimation(reduceMotion ? nil : Motion.snappy) { status = "" }
            }
            .onChange(of: pickerItem) { _, item in
                operation?.cancel()
                isBusy = false
                operation = Task { await handlePicked(item) }
            }
            .onDisappear {
                operation?.cancel()
                camera.barcodeEnabled = false
                camera.stop()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active && settings.cameraPolicyAccepted && !cameraAuthorized {
                    Task { await prepareCamera() }
                }
            }
            .sheet(isPresented: $showManualBarcode) { manualBarcodeSheet }
            .sheet(isPresented: $showDateReview, onDismiss: {
                camera.resetBarcode()
                camera.barcodeEnabled = mode == .barcode
            }) { dateReviewSheet }
            .alert(locale.text("scanner.cameraPolicyTitle"), isPresented: $showPolicy) {
                Button(locale.text("scanner.continue")) {
                    settings.cameraPolicyAccepted = true
                    settings.persist()
                    Task { await prepareCamera() }
                }
                Button(locale.text("scanner.cancel"), role: .cancel) {
                    dismiss()
                }
            } message: {
                Text(locale.text("scanner.cameraPolicyBody"))
            }
        }
        .preferredColorScheme(.dark)
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 16) {
            if !status.isEmpty {
                Text(status)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                    }
                    .foregroundStyle(.white)
                    .transition(reduceMotion ? .identity : .move(edge: .bottom).combined(with: .opacity))
            }

            if !cameraAuthorized, !showPolicy {
                Button(locale.text("scanner.openSettings")) {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.bordered)
            }
            if let failedBarcode {
                Button(locale.text("scanner.retry")) { startBarcode(failedBarcode) }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy)
            }
            if isBusy {
                Button(locale.text("scanner.cancelRequest")) {
                    operation?.cancel()
                    isBusy = false
                    camera.resetBarcode()
                    camera.barcodeEnabled = mode == .barcode
                }
            }
            HStack {
                Button(locale.text("scanner.enterBarcode")) {
                    camera.barcodeEnabled = false
                    showManualBarcode = true
                }
                Button(locale.text("scanner.addManually")) {
                    operation?.cancel()
                    camera.stop()
                    onComplete(FoodEntryDraft(lookupNotice: failedBarcode == nil ? nil : status))
                }
            }
            .font(.subheadline)
            .disabled(isBusy)

            // Liquid glass mode segmented switcher
            HStack(spacing: 6) {
                ForEach(ScannerMode.allCases, id: \.self) { item in
                    let isSelected = mode == item
                    Button {
                        Motion.hapticSelection()
                        withAnimation(reduceMotion ? nil : Motion.liquidSpring) {
                            mode = item
                        }
                    } label: {
                        Text(item.title(locale: locale))
                            .font(.subheadline.weight(isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.65))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(settings.tint)
                                        .overlay { Capsule().strokeBorder(.white.opacity(0.4), lineWidth: 0.75) }
                                        .shadow(color: settings.tint.opacity(0.4), radius: 8, y: 3)
                                        .matchedGeometryEffect(id: "scanner-mode-tab", in: scannerModeNamespace)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            }
            .padding(.horizontal, 40)

            HStack(spacing: 28) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay {
                            Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                        }
                }
                .disabled(isBusy)
                .accessibilityLabel(locale.text("scanner.choosePhoto"))

                Button {
                    if mode == .date {
                        Motion.hapticImpact(.medium)
                        if !reduceMotion { capturePulse.toggle() }
                        camera.capturePhoto()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 72, height: 72)
                        Circle()
                            .strokeBorder(.white.opacity(0.45), lineWidth: 5)
                            .frame(width: 82, height: 82)
                    }
                    .scaleEffect(reduceMotion ? 1 : (capturePulse ? 0.92 : 1))
                    .animation(reduceMotion ? nil : Motion.bouncy, value: capturePulse)
                }
                .opacity(mode == .date ? 1 : 0.35)
                .disabled(mode != .date || !cameraAuthorized || isBusy)
                .accessibilityLabel(locale.text("scanner.captureDate"))

                Color.clear.frame(width: 50, height: 50)
            }

            Text(mode == .barcode ? locale.text("scanner.pointBarcode") : locale.text("scanner.captureDate"))
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.bottom, 24)
                .animation(reduceMotion ? nil : Motion.gentle, value: mode)
        }
        .padding()
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .top, endPoint: .bottom)
        )
    }

    private var manualBarcodeSheet: some View {
        NavigationStack {
            Form {
                TextField(locale.text("scanner.barcodeDigits"), text: $manualBarcode)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("scanner.manualBarcode")
                if !manualBarcode.isEmpty && OpenFoodFactsClient.normalizedBarcode(manualBarcode) == nil {
                    Text(locale.text("scanner.invalidBarcode")).foregroundStyle(.red)
                }
                Text(locale.text("scanner.manualBarcodeHelp"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button(locale.text("scanner.lookup")) {
                    let code = manualBarcode
                    showManualBarcode = false
                    startBarcode(code)
                }
                .disabled(OpenFoodFactsClient.normalizedBarcode(manualBarcode) == nil || isBusy)
            }
            .navigationTitle(locale.text("scanner.enterBarcode"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locale.text("scanner.cancel")) {
                        showManualBarcode = false
                        camera.resetBarcode()
                        camera.barcodeEnabled = mode == .barcode
                    }
                }
            }
        }
        .onDisappear {
            if !isBusy { camera.barcodeEnabled = mode == .barcode }
        }
    }

    private var dateReviewSheet: some View {
        NavigationStack {
            Form {
                Section(locale.text("scanner.recognizedText")) {
                    Text(pendingScan?.rawText ?? "")
                        .textSelection(.enabled)
                }
                Section(locale.text("scanner.confirmDate")) {
                    if (pendingScan?.expiryCandidates.count ?? 0) > 1 {
                        Text(locale.text("scanner.ambiguousDate"))
                    }
                    ForEach(pendingScan?.expiryCandidates ?? [], id: \.self) { candidate in
                        Button {
                            selectedExpiry = candidate
                        } label: {
                            HStack {
                                Text(candidate.formatted(.dateTime.year().month(.wide).day().locale(locale)))
                                Spacer()
                                if selectedExpiry == candidate { Image(systemName: "checkmark") }
                            }
                        }
                    }
                    DatePicker(locale.text("scanner.correctDate"), selection: Binding(
                        get: { selectedExpiry ?? .now },
                        set: { selectedExpiry = $0 }
                    ), displayedComponents: .date)
                    .environment(\.locale, locale)
                    .environment(\.calendar, locale.gregorianCalendar)
                }
                Button(locale.text("scanner.useConfirmedDate")) {
                    guard let selectedExpiry else { return }
                    camera.stop()
                    // Review prepares an editable draft. The food is saved only by the entry form.
                    onComplete(FoodEntryDraft.confirmedDateScan(expiryDate: selectedExpiry))
                }
                .disabled(selectedExpiry == nil)
            }
            .navigationTitle(locale.text("scanner.confirmDate"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locale.text("scanner.cancel")) { showDateReview = false }
                }
            }
        }
    }

    private func prepareCamera() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            withAnimation(reduceMotion ? nil : Motion.soft) { cameraAuthorized = granted }
            guard granted else {
                status = locale.text("scanner.cameraOff")
                return
            }
            camera.onBarcode = { code in
                startBarcode(code)
            }
            camera.onPhoto = { image in
                operation?.cancel()
                operation = Task { await handleDateImage(image) }
            }
            camera.barcodeEnabled = mode == .barcode
            camera.configure()
        }
    }

    @MainActor
    private func startBarcode(_ code: String) {
        guard !isBusy else { return }
        operation?.cancel()
        operation = Task { await handleBarcode(code) }
    }

    @MainActor
    private func handleBarcode(_ code: String) async {
        guard !isBusy else { return }
        guard let code = OpenFoodFactsClient.normalizedBarcode(code) else {
            status = locale.text("scanner.invalidBarcode")
            camera.resetBarcode()
            return
        }
        isBusy = true
        camera.barcodeEnabled = false
        failedBarcode = code
        status = locale.format("scanner.lookingUp", code)
        do {
            if let product = try await OpenFoodFactsClient.fetch(barcode: code) {
                try Task.checkCancellation()
                failedBarcode = nil
                let draft = FoodEntryDraft(
                    name: product.name,
                    categoryID: CategoryMapper.match(hints: product.categoryHints + [product.name], categories: categories)
                )
                camera.stop()
                onComplete(draft)
            } else {
                try Task.checkCancellation()
                status = locale.text("scanner.notFound")
                // A barcode is not a food name. Keep an explicit retry and manual fallback.
                camera.resetBarcode()
            }
        } catch {
            guard !Task.isCancelled else { return }
            status = locale.text("scanner.lookupFailed")
            camera.resetBarcode()
        }
        isBusy = false
    }

    @MainActor
    private func handleDateImage(_ image: UIImage) async {
        guard !isBusy else { return }
        isBusy = true
        status = locale.text("scanner.readingDate")
        let text = await recognizeText(in: image)
        guard !Task.isCancelled else { return }
        let scan = DateParser.parseFoodDates(from: text, calendar: locale.gregorianCalendar, locale: locale)
        if !scan.expiryCandidates.isEmpty {
            pendingScan = scan
            selectedExpiry = scan.expiryCandidates.count == 1 ? scan.expiryCandidates.first : nil
            camera.barcodeEnabled = false
            showDateReview = true
        } else {
            status = locale.text("scanner.noDate")
        }
        isBusy = false
    }

    @MainActor
    private func handlePicked(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isBusy = true
        camera.barcodeEnabled = false
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                isBusy = false
                status = locale.text("scanner.photoLoadFailed")
                camera.barcodeEnabled = mode == .barcode
                return
            }
            try Task.checkCancellation()
            isBusy = false
            await handleDateImage(image)
        } catch {
            guard !Task.isCancelled else { return }
            isBusy = false
            status = locale.text("scanner.photoLoadFailed")
            camera.resetBarcode()
            camera.barcodeEnabled = mode == .barcode
        }
    }

    private func recognizeText(in image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        let orientation: CGImagePropertyOrientation
        switch image.imageOrientation {
        case .up: orientation = .up
        case .down: orientation = .down
        case .left: orientation = .left
        case .right: orientation = .right
        case .upMirrored: orientation = .upMirrored
        case .downMirrored: orientation = .downMirrored
        case .leftMirrored: orientation = .leftMirrored
        case .rightMirrored: orientation = .rightMirrored
        @unknown default: orientation = .up
        }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["en-US", "zh-Hans", "zh-Hant"]
                let text: String
                do {
                    try VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:]).perform([request])
                    text = request.results?
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n") ?? ""
                } catch {
                    text = ""
                }
                // One completion path, even if Vision reports an error.
                continuation.resume(returning: text)
            }
        }
    }
}
