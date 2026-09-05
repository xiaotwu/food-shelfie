import SwiftUI
import UIKit

enum Motion {
    static let snappy = Animation.spring(response: 0.36, dampingFraction: 0.84)
    static let soft = Animation.spring(response: 0.52, dampingFraction: 0.9)
    static let bouncy = Animation.spring(response: 0.42, dampingFraction: 0.68)
    static let gentle = Animation.easeInOut(duration: 0.28)
    static let liquidSpring = Animation.spring(response: 0.44, dampingFraction: 0.76)
    static let liquidMorph = Animation.spring(response: 0.38, dampingFraction: 0.72)

    @MainActor
    static func hapticImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    @MainActor
    static func hapticSelection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    @MainActor
    static func hapticNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96
    var pressedOpacity: CGFloat = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
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

struct LiquidGlassButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = Glass.pillRadius
    var tint: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .overlay {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.white.opacity(0.12))
                }
            }
            .animation(Motion.snappy, value: configuration.isPressed)
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
                .scaleEffect(phase.isIdentity ? 1 : 0.96)
                .opacity(phase.isIdentity ? 1 : 0.78)
                .offset(y: phase.isIdentity ? 0 : 8)
        }
    }
}

struct ScanningPulse: View {
    var isActive: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        .white.opacity(isActive ? 0.95 : 0.45),
                        Color.accentColor.opacity(isActive ? 0.8 : 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isActive ? 3 : 2
            )
            .scaleEffect(isActive ? 1.02 : 1)
            .shadow(
                color: Color.accentColor.opacity(isActive ? 0.4 : 0),
                radius: 12,
                x: 0,
                y: 0
            )
            .animation(isActive ? .easeInOut(duration: 1.05).repeatForever(autoreverses: true) : Motion.gentle, value: isActive)
    }
}
