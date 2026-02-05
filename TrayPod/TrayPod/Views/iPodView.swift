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

            // Edge outline - cool grey, slightly thicker
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color(red: 0.65, green: 0.67, blue: 0.70), lineWidth: 1.5)

            VStack(spacing: 16) {
                // Screen area - pushed slightly lower
                ScreenView(viewModel: viewModel)
                    .padding(.top, 18)

                Spacer()

                // Click wheel - moved up slightly
                ClickWheelView(viewModel: viewModel)
                    .padding(.bottom, 55)
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
