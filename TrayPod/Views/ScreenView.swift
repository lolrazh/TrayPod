import SwiftUI

struct ScreenView: View {
    @ObservedObject var viewModel: iPodViewModel

    // Classic iPod LCD colors
    private let screenBackgroundColor = Color(red: 0.78, green: 0.84, blue: 0.76)
    private let screenTextColor = Color(red: 0.1, green: 0.1, blue: 0.1)
    private let highlightColor = Color(red: 0.2, green: 0.35, blue: 0.65)

    var body: some View {
        ZStack {
            // Screen bezel
            RoundedRectangle(cornerRadius: 8)
                .fill(viewModel.selectedColor.bezelColor)

            // LCD screen
            RoundedRectangle(cornerRadius: 6)
                .fill(screenBackgroundColor)
                .padding(4)

            // Screen content
            VStack(spacing: 0) {
                // Title bar
                titleBar
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                Divider()
                    .background(screenTextColor.opacity(0.3))
                    .padding(.horizontal, 8)

                // Content area
                screenContent
                    .padding(8)
            }
            .padding(4)
        }
        .frame(height: 180)
    }

    private var titleBar: some View {
        HStack {
            Text(screenTitle)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(screenTextColor)

            Spacer()

            // Battery indicator
            batteryIndicator
        }
        .frame(height: 20)
    }

    private var screenTitle: String {
        switch viewModel.currentScreen {
        case .main:
            return "iPod"
        case .nowPlaying:
            return "Now Playing"
        case .settings:
            return "Settings"
        case .colorSelection:
            return "Color"
        }
    }

    private var batteryIndicator: some View {
        HStack(spacing: 1) {
            RoundedRectangle(cornerRadius: 1)
                .fill(screenTextColor)
                .frame(width: 20, height: 10)
                .overlay(
                    HStack(spacing: 1) {
                        ForEach(0..<4) { i in
                            Rectangle()
                                .fill(screenBackgroundColor)
                                .frame(width: 3, height: 6)
                        }
                    }
                    .padding(.leading, 2)
                    , alignment: .leading
                )

            Rectangle()
                .fill(screenTextColor)
                .frame(width: 2, height: 5)
        }
    }

    @ViewBuilder
    private var screenContent: some View {
        switch viewModel.currentScreen {
        case .main, .settings:
            MenuListView(viewModel: viewModel)
        case .nowPlaying:
            NowPlayingView(viewModel: viewModel)
        case .colorSelection:
            ColorSelectionView(viewModel: viewModel)
        }
    }
}

struct MenuListView: View {
    @ObservedObject var viewModel: iPodViewModel

    private let screenTextColor = Color(red: 0.1, green: 0.1, blue: 0.1)
    private let highlightColor = Color(red: 0.2, green: 0.35, blue: 0.65)

    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array(viewModel.currentMenuItems.enumerated()), id: \.element.id) { index, item in
                menuRow(item: item, isSelected: index == viewModel.selectedIndex)
            }
            Spacer()
        }
    }

    private func menuRow(item: MenuItem, isSelected: Bool) -> some View {
        HStack {
            if let icon = item.icon {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
            }

            Text(item.title)
                .font(.system(size: 13, weight: .medium, design: .rounded))

            Spacer()

            if case .navigate = item.action {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? highlightColor : Color.clear)
        .foregroundColor(isSelected ? .white : screenTextColor)
        .cornerRadius(4)
    }
}

struct NowPlayingView: View {
    @ObservedObject var viewModel: iPodViewModel

    private let screenTextColor = Color(red: 0.1, green: 0.1, blue: 0.1)

    var body: some View {
        VStack(spacing: 8) {
            // Album art placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(screenTextColor.opacity(0.1))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 30))
                        .foregroundColor(screenTextColor.opacity(0.3))
                )

            // Track info
            VStack(spacing: 2) {
                Text("No Track Playing")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(screenTextColor)

                Text("Open a music app")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(screenTextColor.opacity(0.6))
            }

            // Progress bar placeholder
            GeometryReader { geo in
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(screenTextColor.opacity(0.2))
                        .frame(height: 4)
                        .overlay(
                            HStack {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(screenTextColor)
                                    .frame(width: geo.size.width * 0.3)
                                Spacer()
                            }
                        )

                    HStack {
                        Text("0:00")
                            .font(.system(size: 8))
                        Spacer()
                        Text("-0:00")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(screenTextColor.opacity(0.6))
                }
            }
            .frame(height: 20)
        }
    }
}

struct ColorSelectionView: View {
    @ObservedObject var viewModel: iPodViewModel

    private let screenTextColor = Color(red: 0.1, green: 0.1, blue: 0.1)
    private let highlightColor = Color(red: 0.2, green: 0.35, blue: 0.65)

    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array(iPodColor.allCases.enumerated()), id: \.element.id) { index, color in
                colorRow(color: color, isSelected: color == viewModel.selectedColor)
                    .onTapGesture {
                        viewModel.selectColor(color)
                    }
            }
            Spacer()
        }
    }

    private func colorRow(color: iPodColor, isSelected: Bool) -> some View {
        HStack {
            Circle()
                .fill(color.bodyColor)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .stroke(screenTextColor.opacity(0.3), lineWidth: 1)
                )

            Text(color.rawValue)
                .font(.system(size: 13, weight: .medium, design: .rounded))

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? highlightColor : Color.clear)
        .foregroundColor(isSelected ? .white : screenTextColor)
        .cornerRadius(4)
    }
}

#Preview {
    ScreenView(viewModel: iPodViewModel())
        .frame(width: 300)
        .padding()
        .background(Color.gray)
}
