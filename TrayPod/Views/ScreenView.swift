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
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(Array(viewModel.currentMenuItems.enumerated()), id: \.element.id) { index, item in
                        menuRow(item: item, isSelected: index == viewModel.selectedIndex)
                            .id(index)
                    }
                }
            }
            .onChange(of: viewModel.selectedIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.15)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
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

    private var playerState: PlayerState {
        viewModel.playerViewModel.state
    }

    private var track: Track? {
        playerState.currentTrack
    }

    var body: some View {
        VStack(spacing: 6) {
            // Play state indicator and volume
            HStack {
                // Play/Pause indicator
                Image(systemName: playerState.isPlaying ? "play.fill" : "pause.fill")
                    .font(.system(size: 8))
                    .foregroundColor(screenTextColor)

                Spacer()

                // Volume indicator
                HStack(spacing: 1) {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 7))
                    volumeBar
                }
                .foregroundColor(screenTextColor)
            }
            .frame(height: 12)

            if let track = track {
                // Track info
                VStack(spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(screenTextColor)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(screenTextColor.opacity(0.7))
                        .lineLimit(1)

                    Text(track.album)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(screenTextColor.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()

                // Progress bar
                progressBar
            } else {
                // No track playing
                Spacer()

                VStack(spacing: 4) {
                    Image(systemName: "music.note")
                        .font(.system(size: 24))
                        .foregroundColor(screenTextColor.opacity(0.3))

                    Text(viewModel.playerViewModel.activeServiceName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(screenTextColor.opacity(0.5))

                    if !viewModel.playerViewModel.hasActiveService {
                        Text("Open Spotify to control")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundColor(screenTextColor.opacity(0.4))
                    }
                }

                Spacer()
            }
        }
    }

    private var volumeBar: some View {
        HStack(spacing: 1) {
            ForEach(0..<8) { i in
                Rectangle()
                    .fill(screenTextColor.opacity(Float(i) / 8.0 < playerState.volume ? 1.0 : 0.2))
                    .frame(width: 3, height: 6)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            VStack(spacing: 2) {
                // Progress track
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(screenTextColor.opacity(0.2))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(screenTextColor)
                        .frame(width: geo.size.width * playerState.progress, height: 4)
                }

                // Time labels
                HStack {
                    Text(Track.formatTime(playerState.playbackPosition))
                        .font(.system(size: 8, design: .monospaced))
                    Spacer()
                    Text("-" + Track.formatTime(playerState.remainingTime))
                        .font(.system(size: 8, design: .monospaced))
                }
                .foregroundColor(screenTextColor.opacity(0.6))
            }
        }
        .frame(height: 20)
    }
}

struct ColorSelectionView: View {
    @ObservedObject var viewModel: iPodViewModel

    private let screenTextColor = Color(red: 0.1, green: 0.1, blue: 0.1)
    private let highlightColor = Color(red: 0.2, green: 0.35, blue: 0.65)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(Array(iPodColor.allCases.enumerated()), id: \.element.id) { index, color in
                        colorRow(
                            color: color,
                            isHighlighted: index == viewModel.selectedIndex,
                            isCurrentColor: color == viewModel.selectedColor
                        )
                        .id(index)
                        .onTapGesture {
                            viewModel.selectColor(color)
                        }
                    }
                }
            }
            .onChange(of: viewModel.selectedIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.15)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    private func colorRow(color: iPodColor, isHighlighted: Bool, isCurrentColor: Bool) -> some View {
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

            if isCurrentColor {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isHighlighted ? highlightColor : Color.clear)
        .foregroundColor(isHighlighted ? .white : screenTextColor)
        .cornerRadius(4)
    }
}

#Preview {
    ScreenView(viewModel: iPodViewModel())
        .frame(width: 300)
        .padding()
        .background(Color.gray)
}
