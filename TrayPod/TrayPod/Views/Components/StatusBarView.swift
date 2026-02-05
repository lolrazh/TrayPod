import SwiftUI

/// Shared horizontal status bar component for both progress and volume display
/// iPod 5G style: sharp edges, subtle bottom shadow, layered aqua fill
struct StatusBarView<LeftContent: View, RightContent: View>: View {
    let progress: CGFloat  // 0.0 - 1.0
    let leftContent: LeftContent
    let rightContent: RightContent

    private let barHeight: CGFloat = 14
    private let barCornerRadius: CGFloat = 1.5
    private let bodyFont = Font.custom("Helvetica Neue", size: 11).weight(.bold)

    // iPod 5G neutral track (cool gray, slight bevel)
    private let trackGradient = LinearGradient(
        stops: [
            .init(color: Color(red: 0.98, green: 0.99, blue: 1.00), location: 0.0),
            .init(color: Color(red: 0.93, green: 0.95, blue: 0.98), location: 0.52),
            .init(color: Color(red: 0.86, green: 0.89, blue: 0.94), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private let trackBorderGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.88),
            Color.black.opacity(0.22)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // Aqua fill base (subtle dark -> light), bar-level 3D comes from shared overlay
    private let fillBaseGradient = LinearGradient(
        stops: [
            .init(color: Color(red: 0.16, green: 0.62, blue: 0.93), location: 0.0),
            .init(color: Color(red: 0.24, green: 0.72, blue: 0.97), location: 0.52),
            .init(color: Color(red: 0.43, green: 0.82, blue: 0.99), location: 1.0)
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
            VStack(spacing: 3) {
                // Bar shell with shared 3D lighting + blue fill level
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(trackGradient)

                    aquaFill(width: geo.size.width * clampedProgress)
                }
                .frame(height: barHeight)
                .clipShape(RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous))
                .overlay {
                    barLightingOverlay
                }
                .overlay {
                    RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
                        .stroke(trackBorderGradient, lineWidth: 0.8)
                }
                .overlay(alignment: .bottom) {
                    // Subtle drop shadow only below the full bar
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.10), Color.black.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 1.2)
                        .offset(y: 1)
                }

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

    private func aquaFill(width: CGFloat) -> some View {
        Rectangle()
            .fill(fillBaseGradient)
            .frame(width: max(width, 0), height: barHeight)
            .overlay {
                // Alternating vertical dark/light aqua bands
                aquaBandOverlay()
            }
    }

    private var barLightingOverlay: some View {
        let highlightHeight = barHeight * 0.50
        let shadowBandHeight = barHeight * 0.20

        return Rectangle()
            .overlay(alignment: .top) {
                // Gloss highlight over upper half of the entire bar shell
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.72), location: 0.0),
                                .init(color: Color.white.opacity(0.34), location: 0.56),
                                .init(color: Color.white.opacity(0.05), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: highlightHeight)
            }
            .overlay(alignment: .center) {
                // Dark center strip
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.0), location: 0.0),
                                .init(color: Color.black.opacity(0.30), location: 0.5),
                                .init(color: Color.black.opacity(0.0), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: shadowBandHeight)
                    .offset(y: barHeight * 0.04)
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.52))
                    .frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(0.16))
                    .frame(height: 1)
            }
    }

    private func aquaBandOverlay() -> some View {
        GeometryReader { geo in
            let cycleWidth: CGFloat = 14
            let cycleCount = Int(ceil(geo.size.width / cycleWidth)) + 1

            HStack(spacing: 0) {
                ForEach(0..<cycleCount, id: \.self) { _ in
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.04, green: 0.42, blue: 0.74).opacity(0.22), location: 0.0),
                            .init(color: Color(red: 0.08, green: 0.50, blue: 0.82).opacity(0.11), location: 0.32),
                            .init(color: Color(red: 0.68, green: 0.89, blue: 1.00).opacity(0.13), location: 0.58),
                            .init(color: Color(red: 0.05, green: 0.43, blue: 0.75).opacity(0.20), location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: cycleWidth)
                }
            }
            .blur(radius: 0.28)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
            .mask(
                Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.86), Color.white.opacity(1.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
            )
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
