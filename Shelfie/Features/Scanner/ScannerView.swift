import AVFoundation
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

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if cameraAuthorized {
                    CameraPreview(session: camera.session)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
                VStack {
                    Spacer()
                    ScanningPulse(isActive: isBusy || mode == .barcode)
                        .frame(width: 260, height: mode == .barcode ? 140 : 220)
                        .animation(Motion.snappy, value: mode)
                    Spacer()
                    controls
                }
                if isBusy {
                    ProgressView()
                        .controlSize(.large)
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(Motion.soft, value: isBusy)
            .navigationTitle(locale.text("scanner.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locale.text("scanner.close")) { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        camera.toggleTorch()
                    } label: {
                        Image(systemName: "flashlight.on.fill")
                            .symbolEffect(.bounce, value: cameraAuthorized)
                    }
                    .foregroundStyle(.white)
                }
            }
            .onAppear {
                if !settings.cameraPolicyAccepted {
                    showPolicy = true
                } else {
                    Task { await prepareCamera() }
                }
            }
            .onChange(of: mode) { _, newMode in
                camera.barcodeEnabled = newMode == .barcode
                withAnimation(Motion.snappy) { status = "" }
            }
            .onChange(of: pickerItem) { _, item in
                Task { await handlePicked(item) }
            }
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
    }

    private var controls: some View {
        VStack(spacing: 16) {
            if !status.isEmpty {
                Text(status)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.45), in: Capsule())
                    .foregroundStyle(.white)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Picker("", selection: $mode) {
                ForEach(ScannerMode.allCases, id: \.self) { item in
                    Text(item.title(locale: locale)).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 40)

            HStack(spacing: 28) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                }
                Button {
                    if mode == .date {
                        capturePulse.toggle()
                        camera.capturePhoto()
                    }
                } label: {
                    Circle()
                        .fill(.white)
                        .frame(width: 72, height: 72)
                        .overlay {
                            Circle().stroke(.white.opacity(0.4), lineWidth: 6)
                        }
                        .scaleEffect(capturePulse ? 0.9 : 1)
                        .animation(Motion.bouncy, value: capturePulse)
                }
                .opacity(mode == .date ? 1 : 0.35)
                .disabled(mode != .date)

                Color.clear.frame(width: 48, height: 48)
            }
            Text(mode == .barcode ? locale.text("scanner.pointBarcode") : locale.text("scanner.captureDate"))
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.bottom, 24)
                .animation(Motion.gentle, value: mode)
        }
        .padding()
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .top, endPoint: .bottom)
        )
    }

    private func prepareCamera() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            withAnimation(Motion.soft) { cameraAuthorized = granted }
            guard granted else {
                status = locale.text("scanner.cameraOff")
                return
            }
            camera.onBarcode = { code in
                Task { await handleBarcode(code) }
            }
            camera.onPhoto = { image in
                Task { await handleDateImage(image) }
            }
            camera.barcodeEnabled = mode == .barcode
            camera.configure()
        }
    }

    @MainActor
    private func handleBarcode(_ code: String) async {
        guard mode == .barcode, !isBusy else { return }
        isBusy = true
        status = locale.format("scanner.lookingUp", code)
        do {
            if let product = try await OpenFoodFactsClient.fetch(barcode: code) {
                var image: UIImage?
                if let url = product.imageURL {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    image = UIImage(data: data)
                }
                let draft = FoodEntryDraft(
                    name: product.name,
                    image: image,
                    categoryID: CategoryMapper.match(hints: product.categoryHints + [product.name], categories: categories)
                )
                camera.stop()
                onComplete(draft)
            } else {
                status = locale.text("scanner.notFound")
                camera.stop()
                onComplete(FoodEntryDraft(name: code))
            }
        } catch {
            status = locale.text("scanner.lookupFailed")
        }
        isBusy = false
    }

    @MainActor
    private func handleDateImage(_ image: UIImage) async {
        guard !isBusy else { return }
        isBusy = true
        status = locale.text("scanner.readingDate")
        let text = await recognizeText(in: image)
        let scan = DateParser.parseFoodDates(from: text)
        if let expiry = scan.expiryDate {
            camera.stop()
            onComplete(FoodEntryDraft(expiryDate: expiry, purchaseDate: scan.productionDate ?? .now, image: image))
        } else {
            status = locale.text("scanner.noDate")
        }
        isBusy = false
    }

    private func handlePicked(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
        await handleDateImage(image)
    }

    private func recognizeText(in image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        }
    }
}
