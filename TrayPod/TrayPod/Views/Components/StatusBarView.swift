import SwiftUI

/// Shared horizontal status bar component for both progress and volume display
/// iPod 5G style: glass tube with aqua liquid fill
///
/// Layer hierarchy (bottom to top):
///   1. Track background — recessed cool gray
///   2. Blue fill — flat aqua gradient with soft vertical banding
///   3. Glass tube — transparent highlights/shadows spanning FULL width
struct StatusBarView<LeftContent: View, RightContent: View>: View {
    let progress: CGFloat  // 0.0 - 1.0
    let leftContent: LeftContent
    let rightContent: RightContent

    private let barHeight: CGFloat = 14
    private let barCornerRadius: CGFloat = 1.5
    private let bodyFont = Font.custom("Helvetica Neue", size: 11).weight(.bold)

    // MARK: - Gradients

    // Layer 1: Recessed track (cool gray, slight top-to-bottom bevel)
    private let trackGradient = LinearGradient(
        stops: [
            .init(color: Color(red: 0.98, green: 0.99, blue: 1.00), location: 0.0),
            .init(color: Color(red: 0.93, green: 0.95, blue: 0.98), location: 0.52),
            .init(color: Color(red: 0.86, green: 0.89, blue: 0.94), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // Layer 2: Aqua fill base (flat blue, no 3D — the tube overlay handles that)
    private let fillGradient = LinearGradient(
        stops: [
            .init(color: Color(red: 0.16, green: 0.62, blue: 0.93), location: 0.0),
            .init(color: Color(red: 0.24, green: 0.72, blue: 0.97), location: 0.52),
            .init(color: Color(red: 0.43, green: 0.82, blue: 0.99), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // Border: light top, dark bottom for inset look
    private let borderGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.88),
            Color.black.opacity(0.22)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    init(
        progress: CGFloat,
        @ViewBuilder leftContent: () -> LeftContent,
        @ViewBuilder rightContent: () -> RightContent
    ) {
        self.progress = progress
        self.leftContent = leftContent()
        self.rightContent = rightContent()
    }

    var body: some View {
        GeometryReader { geo in
            let clampedProgress = min(1, max(0, progress))
            let fillWidth = geo.size.width * clampedProgress

            VStack(spacing: 3) {
                // The bar: glass tube with liquid fill
                ZStack(alignment: .leading) {
                    // Layer 1: Track background
                    Rectangle()
                        .fill(trackGradient)

                    // Layer 2: Blue fill with soft banding
                    if clampedProgress > 0 {
                        Rectangle()
                            .fill(fillGradient)
                            .frame(width: fillWidth)
                            .overlay { softBanding() }
                            .clipped()
                    }

                    // Layer 3: Glass tube (full width, transparent)
                    glassTubeOverlay
                }
                .frame(height: barHeight)
                .clipShape(RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
                        .stroke(borderGradient, lineWidth: 0.8)
                }
                .shadow(color: Color.black.opacity(0.24), radius: 4, y: 2)

                // Labels below the bar
                HStack {
                    leftContent
                    Spacer()
                    rightContent
                }
                .font(bodyFont)
                .foregroundColor(.black)
            }
        }
        .frame(height: 28)
    }

    // MARK: - Layer 3: Glass tube overlay

    /// Cylinder illusion using only transparent white/black overlays.
    /// Spans full bar width so the 3D effect covers both filled and unfilled regions.
    private var glassTubeOverlay: some View {
        ZStack {
            // Top gloss: bright white fading down to clear
            VStack(spacing: 0) {
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.60), location: 0.0),
                        .init(color: .white.opacity(0.20), location: 0.6),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: barHeight * 0.45)

                Spacer(minLength: 0)
            }

            // Top rim shadow: painted OVER the gloss so it's visible
            VStack(spacing: 0) {
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.36), location: 0.0),
                        .init(color: .black.opacity(0.14), location: 0.35),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: barHeight * 0.30)
                .blur(radius: 0.5)

                Spacer(minLength: 0)
            }

            // Equator shadow: darkening at center of cylinder
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .clear, location: 0.36),
                    .init(color: .black.opacity(0.20), location: 0.54),
                    .init(color: .clear, location: 0.72),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blur(radius: 0.5)

            // Top edge: bright pixel line
            VStack(spacing: 0) {
                Color.white.opacity(0.40)
                    .frame(height: 0.5)
                Spacer(minLength: 0)
            }

            // Bottom edge: dark pixel line
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Color.black.opacity(0.10)
                    .frame(height: 0.5)
            }
        }
    }

    // MARK: - Soft banding texture

    /// Gentle vertical luminance ripples on the blue fill.
    /// Uses high blur so bands blend smoothly — no hard edges.
    private func softBanding() -> some View {
        GeometryReader { geo in
            let cycleWidth: CGFloat = 16
            let count = Int(ceil(geo.size.width / cycleWidth)) + 1

            HStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { _ in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white.opacity(0.10), location: 0.35),
                            .init(color: .clear, location: 0.50),
                            .init(color: .black.opacity(0.04), location: 0.65),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: cycleWidth)
                }
            }
            .blur(radius: 1.2)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
        }
    }
}

// MARK: - Convenience initializers for common use cases

extension StatusBarView where LeftContent == Text, RightContent == Text {
    /// Progress bar with time labels
    init(progress: CGFloat, elapsedTime: String, remainingTime: String) {
        self.progress = progress
        self.leftContent = Text(elapsedTime)
        self.rightContent = Text("-" + remainingTime)
    }
}

extension StatusBarView where LeftContent == Image, RightContent == Image {
    /// Volume bar with speaker icons
    init(volume: CGFloat) {
        self.progress = volume
        self.leftContent = Image(systemName: "speaker.fill")
        self.rightContent = Image(systemName: "speaker.wave.3.fill")
    }
}

#Preview("Progress Bar") {
    StatusBarView(progress: 0.35, elapsedTime: "1:23", remainingTime: "2:47")
        .padding()
        .background(Color(red: 0.93, green: 0.95, blue: 0.98))
}

#Preview("Volume Bar") {
    StatusBarView(volume: 0.7)
        .padding()
        .background(Color(red: 0.93, green: 0.95, blue: 0.98))
}
