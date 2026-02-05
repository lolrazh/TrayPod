import SwiftUI

struct iPodView: View {
    @StateObject private var viewModel = iPodViewModel()

    // iPod 5G corner radius (slightly rounded)
    private let cornerRadius: CGFloat = 20

    var body: some View {
        ZStack {
            // iPod 5G body - glossy polycarbonate
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(viewModel.selectedColor.bodyColor)
                .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)

            // Edge highlight - subtle plastic edge reflection
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.15),
                            Color.clear,
                            Color.black.opacity(0.05),
                            Color.black.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            VStack(spacing: 16) {
                // Screen area - thinner margins for larger screen appearance
                ScreenView(viewModel: viewModel)
                    .padding(.top, 14)

                Spacer()

                // Click wheel - centered in lower area
                ClickWheelView(viewModel: viewModel)
                    .padding(.bottom, 45)
            }
            .padding(.horizontal, 18)

            // iPod 5G glossy polycarbonate reflection - prominent top highlight
            VStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.5),  // Strong top highlight
                                .white.opacity(0.2),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(height: 120)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .allowsHitTesting(false)
        }
        .frame(width: 290, height: 490)  // Proper iPod 5G proportions
    }
}

#Preview {
    iPodView()
}
