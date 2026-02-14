import SwiftUI

struct SearchInputView: View {
    @ObservedObject var viewModel: iPodViewModel

    private let screenTextColor = Color.black
    private let highlightGradient = LinearGradient(
        colors: [
            Color(red: 0.30, green: 0.67, blue: 0.95),
            Color(red: 0.0, green: 0.50, blue: 0.85)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        VStack(spacing: 6) {
            // Current query display
            HStack(spacing: 0) {
                Text(viewModel.searchQuery)
                    .font(.custom("Helvetica Neue", size: 13).weight(.bold))
                    .foregroundColor(screenTextColor)

                // Blinking cursor
                Rectangle()
                    .fill(screenTextColor)
                    .frame(width: 1, height: 14)
                    .opacity(0.6)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .frame(height: 24)
            .background(Color.white.opacity(0.3))

            // Instruction
            Text("Scroll to pick letter \u{2022} Press center to add")
                .font(.custom("Helvetica Neue", size: 8))
                .foregroundColor(screenTextColor.opacity(0.5))

            // Character grid
            let chars = viewModel.searchCharacters
            let selectedIdx = viewModel.searchCharIndex

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(Array(chars.enumerated()), id: \.offset) { index, char in
                            Text(String(char))
                                .font(.custom("Helvetica Neue", size: 14).weight(.bold))
                                .frame(width: 18, height: 20)
                                .background(
                                    index == selectedIdx
                                        ? AnyView(highlightGradient)
                                        : AnyView(Color.clear)
                                )
                                .foregroundColor(index == selectedIdx ? .white : screenTextColor)
                                .cornerRadius(2)
                                .id(index)
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .onChange(of: selectedIdx) { newIdx in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        proxy.scrollTo(newIdx, anchor: .center)
                    }
                }
            }
            .frame(height: 24)

            // Action hints
            HStack {
                Text("MENU: Submit")
                    .font(.custom("Helvetica Neue", size: 8))
                    .foregroundColor(screenTextColor.opacity(0.4))
                Spacer()
                Text("|< : Delete")
                    .font(.custom("Helvetica Neue", size: 8))
                    .foregroundColor(screenTextColor.opacity(0.4))
            }
            .padding(.horizontal, 8)

            Spacer()
        }
    }
}
