import SwiftUI

/// Shared horizontal status bar component for both progress and volume display
/// iPod 5G style: sharp edges, downward shadow, blue gradient fill
struct StatusBarView<LeftContent: View, RightContent: View>: View {
    let progress: CGFloat  // 0.0 - 1.0
    let leftContent: LeftContent
    let rightContent: RightContent

    // iPod 5G blue gradient (matches highlight)
    private let fillGradient = LinearGradient(
        colors: [
            Color(red: 0.30, green: 0.67, blue: 0.95),  // Lighter blue top
            Color(red: 0.0, green: 0.50, blue: 0.85)    // Darker blue bottom
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private let barHeight: CGFloat = 14
    private let bodyFont = Font.custom("Helvetica Neue", size: 11).weight(.bold)

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
            VStack(spacing: 3) {
                // Bar with sharp edges and downward shadow
                ZStack(alignment: .leading) {
                    // Background track - gray unfilled portion with downward shadow
                    Rectangle()
                        .fill(Color.gray.opacity(0.35))
                        .frame(height: barHeight)
                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 2)

                    // Filled progress with blue gradient
                    Rectangle()
                        .fill(fillGradient)
                        .frame(width: max(0, geo.size.width * progress), height: barHeight)
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
