import SwiftUI

struct iPodView: View {
    @StateObject private var viewModel = iPodViewModel()

    var body: some View {
        ZStack {
            // iPod body
            RoundedRectangle(cornerRadius: 30)
                .fill(viewModel.selectedColor.bodyColor)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

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
                RoundedRectangle(cornerRadius: 30)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(height: 100)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .allowsHitTesting(false)
        }
        .frame(width: 350, height: 560)
    }
}

#Preview {
    iPodView()
}
