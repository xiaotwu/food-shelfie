import SwiftUI

enum Glass {
    static let cardRadius: CGFloat = 22
    static let smallRadius: CGFloat = 16
    static let pillRadius: CGFloat = 28

    @ViewBuilder
    static func cardBackground(
        cornerRadius: CGFloat = cardRadius,
        tint: Color? = nil,
        material: Material = .ultraThinMaterial
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(material)
            .overlay {
                if let tint {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.14), tint.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
    }

    @ViewBuilder
    static func cardStroke(cornerRadius: CGFloat = cardRadius, intensity: Double = 1.0) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.38 * intensity), location: 0.0),
                        .init(color: .white.opacity(0.12 * intensity), location: 0.35),
                        .init(color: .white.opacity(0.04 * intensity), location: 0.7),
                        .init(color: .white.opacity(0.18 * intensity), location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.75
            )
    }

    @ViewBuilder
    static func ambientBackground(tint: Color) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Color(.systemBackground)

                // Top ambient light orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [tint.opacity(0.18), tint.opacity(0.02), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: max(size.width * 0.6, 180)
                        )
                    )
                    .frame(width: max(size.width * 1.1, 300), height: max(size.width * 1.1, 300))
                    .position(x: size.width * 0.2, y: size.height * 0.1)
                    .blur(radius: 50)

                // Bottom ambient light orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [tint.opacity(0.12), tint.opacity(0.01), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: max(size.width * 0.55, 160)
                        )
                    )
                    .frame(width: max(size.width * 0.95, 260), height: max(size.width * 0.95, 260))
                    .position(x: size.width * 0.85, y: size.height * 0.85)
                    .blur(radius: 60)
            }
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct LiquidGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = Glass.cardRadius
    var tint: Color? = nil
    var material: Material = .ultraThinMaterial
    var shadowRadius: CGFloat = 12
    var shadowY: CGFloat = 6

    func body(content: Content) -> some View {
        content
            .background(
                Glass.cardBackground(cornerRadius: cornerRadius, tint: tint, material: material)
            )
            .overlay {
                Glass.cardStroke(cornerRadius: cornerRadius)
            }
            .shadow(
                color: (tint ?? Color.black).opacity(0.06),
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
    }
}

extension View {
    func liquidCard(
        cornerRadius: CGFloat = Glass.cardRadius,
        tint: Color? = nil,
        material: Material = .ultraThinMaterial,
        shadowRadius: CGFloat = 12,
        shadowY: CGFloat = 6
    ) -> some View {
        modifier(LiquidGlassCardModifier(
            cornerRadius: cornerRadius,
            tint: tint,
            material: material,
            shadowRadius: shadowRadius,
            shadowY: shadowY
        ))
    }
}

enum FreshnessPalette {
    static func color(for freshness: Freshness) -> Color {
        switch freshness {
        case .fresh:
            Color(red: 0.12, green: 0.68, blue: 0.46)
        case .warning:
            Color(red: 0.94, green: 0.62, blue: 0.12)
        case .urgent:
            Color(red: 0.96, green: 0.40, blue: 0.18)
        case .expired:
            Color(red: 0.86, green: 0.20, blue: 0.28)
        }
    }

    static func gradient(for freshness: Freshness) -> LinearGradient {
        let base = color(for: freshness)
        switch freshness {
        case .fresh:
            return LinearGradient(
                colors: [Color(red: 0.16, green: 0.78, blue: 0.52), base],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .warning:
            return LinearGradient(
                colors: [Color(red: 0.98, green: 0.74, blue: 0.22), base],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .urgent:
            return LinearGradient(
                colors: [Color(red: 0.98, green: 0.52, blue: 0.24), base],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .expired:
            return LinearGradient(
                colors: [Color(red: 0.92, green: 0.30, blue: 0.38), base],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    static func fill(for freshness: Freshness) -> Color {
        color(for: freshness).opacity(0.14)
    }

    static func auraGlow(for freshness: Freshness) -> Color {
        color(for: freshness).opacity(0.24)
    }
}

struct FreshnessRing: View {
    var progress: Double
    var freshness: Freshness
    var lineWidth: CGFloat = 4.5
    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            // Translucent track background
            Circle()
                .stroke(
                    FreshnessPalette.color(for: freshness).opacity(0.16),
                    lineWidth: lineWidth
                )

            // Dynamic progress gradient
            Circle()
                .trim(from: 0, to: min(max(1 - animatedProgress, 0.04), 1))
                .stroke(
                    FreshnessPalette.gradient(for: freshness),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: FreshnessPalette.color(for: freshness).opacity(0.35),
                    radius: 3,
                    x: 0,
                    y: 0
                )
        }
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(Motion.liquidSpring) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(Motion.liquidSpring) {
                animatedProgress = newValue
            }
        }
    }
}

struct EmptyShelfView: View {
    var onAdd: () -> Void
    @Environment(\.locale) private var locale
    @State private var floatOrb = false

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 120, height: 120)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.accentColor.opacity(0.18), radius: 20, y: 10)
                    .scaleEffect(floatOrb ? 1.04 : 0.98)
                    .offset(y: floatOrb ? -4 : 4)

                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 76)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    floatOrb = true
                }
            }

            VStack(spacing: 8) {
                Text(locale.text("shelf.empty.title"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Text(locale.text("shelf.empty.body"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: onAdd) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                    Text(locale.text("shelf.empty.action"))
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(Color.accentColor)
                        .overlay {
                            Capsule()
                                .strokeBorder(.white.opacity(0.3), lineWidth: 0.75)
                        }
                        .shadow(color: Color.accentColor.opacity(0.35), radius: 12, y: 6)
                )
            }
            .buttonStyle(PressScaleButtonStyle(pressedScale: 0.94))
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .appearUp()
    }
}

enum LayoutConstants {
    /// Clearance height reserved at the bottom of scroll views so that
    /// content is never covered by the floating tab dock when touching the bottom,
    /// while allowing content to freely slide behind the translucent dock during scrolling.
    static let floatingDockClearance: CGFloat = 124
}

extension View {
    /// Insets scroll content by the floating dock clearance so touching the bottom preserves full visibility.
    func floatingDockClearance(extra: CGFloat = 0) -> some View {
        self.padding(.bottom, LayoutConstants.floatingDockClearance + extra)
    }
}

