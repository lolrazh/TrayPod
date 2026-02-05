import SwiftUI

struct iPodView: View {
    @StateObject private var viewModel = iPodViewModel()

    // Authentic iPod Classic corner radius
    private let cornerRadius: CGFloat = 24

    var body: some View {
        ZStack {
            // iPod body
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(viewModel.selectedColor.bodyColor)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

            // Edge highlight stroke (light top-left, shadow bottom-right)
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.1),
                            Color.clear,
                            Color.black.opacity(0.1),
                            Color.black.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )

            VStack(spacing: 20) {
                // Screen area
                ScreenView(viewModel: viewModel)
                    .padding(.top, 25)

                Spacer()

                // Click wheel
                ClickWheelView(viewModel: viewModel)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 20)

            // Subtle highlight on top edge (glossy effect)
            VStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(height: 80)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .allowsHitTesting(false)
        }
        .frame(width: 350, height: 560)
    }
}

#Preview {
    iPodView()
}
