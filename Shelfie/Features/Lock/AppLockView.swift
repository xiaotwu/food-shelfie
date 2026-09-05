import SwiftUI

struct AppLockView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.locale) private var locale
    @State private var bounce = false

    var body: some View {
        ZStack {
            // Ambient light canvas background
            Glass.ambientBackground(tint: settings.tint)

            VStack(spacing: 32) {
                Spacer()

                // Floating brand mark
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 160, height: 160)
                        .overlay {
                            Circle().strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                        }
                        .shadow(color: settings.tint.opacity(0.28), radius: 24, y: 12)

                    Image("BrandMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 108, height: 108)
                        .scaleEffect(bounce ? 1 : 0.88)
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
                }
                .onAppear {
                    withAnimation(Motion.bouncy) { bounce = true }
                }

                VStack(spacing: 10) {
                    Text("Shelfie")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(locale.text("lock.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .appearUp(delay: 0.08)

                // Liquid unlock button
                Button {
                    Motion.hapticImpact(.medium)
                    Task { await authenticate() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "faceid")
                            .font(.title3.weight(.semibold))
                        Text(locale.text("lock.unlock"))
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: 240)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(settings.tint)
                            .overlay { Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.75) }
                            .shadow(color: settings.tint.opacity(0.4), radius: 14, y: 6)
                    )
                }
                .buttonStyle(PressScaleButtonStyle(pressedScale: 0.95))
                .appearUp(delay: 0.14)

                Spacer()
            }
            .padding(24)
        }
        .task { await authenticate() }
    }

    @MainActor
    private func authenticate() async {
        if await BiometricAuth.unlock(reason: locale.text("lock.reason")) {
            Motion.hapticNotification(.success)
            withAnimation(Motion.liquidSpring) {
                settings.isUnlocked = true
            }
        }
    }
}
