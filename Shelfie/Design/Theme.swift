import SwiftUI

enum Glass {
    static let cardRadius: CGFloat = 20

    @ViewBuilder
    static func cardBackground(cornerRadius: CGFloat = cardRadius) -> some View {
        if #available(iOS 26.0, *) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.thinMaterial)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.regularMaterial)
        }
    }

    @ViewBuilder
    static func cardStroke(cornerRadius: CGFloat = cardRadius) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
    }
}

enum FreshnessPalette {
    static func color(for freshness: Freshness) -> Color {
        switch freshness {
        case .fresh: Color(red: 0.16, green: 0.62, blue: 0.45)
        case .warning: Color(red: 0.90, green: 0.62, blue: 0.12)
        case .urgent: Color(red: 0.93, green: 0.42, blue: 0.16)
        case .expired: Color(red: 0.78, green: 0.22, blue: 0.28)
        }
    }

    static func fill(for freshness: Freshness) -> Color {
        color(for: freshness).opacity(0.16)
    }
}

struct FreshnessRing: View {
    var progress: Double
    var freshness: Freshness
    var lineWidth: CGFloat = 5
    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(FreshnessPalette.color(for: freshness).opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(1 - animatedProgress, 0.04), 1))
                .stroke(
                    FreshnessPalette.color(for: freshness),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(Motion.soft) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(Motion.soft) {
                animatedProgress = newValue
            }
        }
    }
}

struct EmptyShelfView: View {
    var onAdd: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(locale.text("shelf.empty.title"))
            } icon: {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
            }
        } description: {
            Text(locale.text("shelf.empty.body"))
        } actions: {
            Button(locale.text("shelf.empty.action"), action: onAdd)
                .buttonStyle(.borderedProminent)
                .symbolEffect(.bounce, value: true)
        }
        .padding(.top, 32)
        .appearUp()
    }
}
