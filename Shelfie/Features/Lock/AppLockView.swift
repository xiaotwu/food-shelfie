import SwiftUI

struct AppLockView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.locale) private var locale
    @State private var bounce = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 132, height: 132)
                .scaleEffect(bounce ? 1 : 0.86)
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
                .onAppear {
                    withAnimation(Motion.bouncy) { bounce = true }
                }
            VStack(spacing: 8) {
                Text("Shelfie")
                    .font(.largeTitle.weight(.bold))
                Text(locale.text("lock.subtitle"))
                    .foregroundStyle(.secondary)
            }
            .appearUp(delay: 0.08)
            Button {
                Task { await authenticate() }
            } label: {
                Text(locale.text("lock.unlock"))
                    .frame(maxWidth: 220)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .appearUp(delay: 0.14)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .task { await authenticate() }
    }

    private func authenticate() async {
        if await BiometricAuth.unlock(reason: locale.text("lock.reason")) {
            withAnimation(Motion.soft) {
                settings.isUnlocked = true
            }
        }
    }
}
