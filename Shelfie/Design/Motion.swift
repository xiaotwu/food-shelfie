import SwiftUI

enum Motion {
    static let snappy = Animation.spring(response: 0.36, dampingFraction: 0.84)
    static let soft = Animation.spring(response: 0.52, dampingFraction: 0.9)
    static let bouncy = Animation.spring(response: 0.42, dampingFraction: 0.68)
    static let gentle = Animation.easeInOut(duration: 0.28)
}

struct PressScaleButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(Motion.bouncy, value: configuration.isPressed)
    }
}

struct AppearUp: ViewModifier {
    @State private var shown = false
    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)
            .onAppear {
                withAnimation(Motion.soft.delay(delay)) {
                    shown = true
                }
            }
    }
}

extension View {
    func appearUp(delay: Double = 0) -> some View {
        modifier(AppearUp(delay: delay))
    }

    func shelfCardScrollTransition() -> some View {
        scrollTransition { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.94)
                .opacity(phase.isIdentity ? 1 : 0.72)
                .offset(y: phase.isIdentity ? 0 : 10)
        }
    }
}

struct ScanningPulse: View {
    var isActive: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(.white.opacity(isActive ? 0.95 : 0.55), lineWidth: isActive ? 3 : 2)
            .scaleEffect(isActive ? 1.02 : 1)
            .animation(isActive ? .easeInOut(duration: 1.05).repeatForever(autoreverses: true) : Motion.gentle, value: isActive)
    }
}
