import SwiftUI

struct ScreenView: View {
    @ObservedObject var viewModel: iPodViewModel

    // iPod 5G (Video) - white background LCD
    private let screenBackgroundColor = Color.white
    private let screenTextColor = Color.black
    private let titleBarColor = Color(red: 0.85, green: 0.85, blue: 0.85) // Gray title bar

    var body: some View {
        ZStack {
            // Screen bezel
            RoundedRectangle(cornerRadius: 8)
                .fill(viewModel.selectedColor.bezelColor)

            // Bezel bevel effect - light top-left edge, dark bottom-right
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.08),
                            Color.clear,
                            Color.black.opacity(0.15),
                            Color.black.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            // LCD screen - clean white for iPod 5G (no scanlines, no backlight bloom)
            ZStack {
                // Base LCD color - pure white
                RoundedRectangle(cornerRadius: 5)
                    .fill(screenBackgroundColor)

                // Subtle inner shadow for recessed glass effect
                RoundedRectangle(cornerRadius: 5)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.15),
                                Color.clear,
                                Color.clear,
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            .padding(6)

            // Screen content
            VStack(spacing: 0) {
                // Title bar - gray background like iPod 5G
                titleBar
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(titleBarColor)

                // Content area
                screenContent
                    .padding(8)
            }
            .padding(6)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .frame(height: 180)
    }

    private var titleBar: some View {
        HStack {
            Text(screenTitle)
                .font(.system(size: 14, weight: .bold))
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
        Group {
            switch viewModel.currentScreen {
            case .main, .settings:
                MenuListView(viewModel: viewModel)
            case .nowPlaying:
                NowPlayingView(viewModel: viewModel, playerViewModel: viewModel.playerViewModel)
            case .colorSelection:
                ColorSelectionView(viewModel: viewModel)
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: viewModel.transitionDirection),
            removal: .move(edge: viewModel.transitionDirection == .trailing ? .leading : .trailing)
        ))
        .id(viewModel.currentScreen)
    }
}

struct MenuListView: View {
    @ObservedObject var viewModel: iPodViewModel

    private let screenTextColor = Color.black
    // Authentic iPod highlight gradient: #73C9FF → #006DB0
    private let highlightGradient = LinearGradient(
        colors: [
            Color(red: 0.45, green: 0.79, blue: 1.0),   // #73C9FF
            Color(red: 0.0, green: 0.43, blue: 0.69)    // #006DB0
        ],
        startPoint: .top,
        endPoint: .bottom
    )

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
            // iPod 5G: Text-only menus, no icons
            Text(item.title)
                .font(.system(size: 13, weight: .medium))

            Spacer()

            // Chevron for navigation items
            if case .navigate = item.action {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? highlightGradient : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom))
        .foregroundColor(isSelected ? .white : screenTextColor)
    }
}

struct NowPlayingView: View {
    @ObservedObject var viewModel: iPodViewModel
    @ObservedObject var playerViewModel: PlayerViewModel

    private let screenTextColor = Color.black
    private let artworkSize: CGFloat = 80 // Prominent album art

    private var playerState: PlayerState {
        playerViewModel.state
    }

    private var track: Track? {
        playerState.currentTrack
    }

    var body: some View {
        VStack(spacing: 4) {
            if let track = track {
                // iPod 5G Now Playing Layout
                HStack(alignment: .top, spacing: 10) {
                    // Album artwork (left side, prominent)
                    albumArtwork(for: track)

                    // Track info (right side)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(screenTextColor)
                            .lineLimit(2)

                        Text(track.artist)
                            .font(.system(size: 10))
                            .foregroundColor(screenTextColor.opacity(0.8))
                            .lineLimit(1)

                        Text(track.album)
                            .font(.system(size: 9))
                            .foregroundColor(screenTextColor.opacity(0.6))
                            .lineLimit(1)

                        Spacer()

                        // Play state indicator
                        HStack(spacing: 4) {
                            Image(systemName: playerState.isPlaying ? "play.fill" : "pause.fill")
                                .font(.system(size: 8))
                            Text(playerState.isPlaying ? "Playing" : "Paused")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(screenTextColor.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: artworkSize)

                Spacer(minLength: 4)

                // Progress bar with diamond scrubber
                progressBar
            } else {
                // No track playing
                Spacer()

                VStack(spacing: 6) {
                    // Placeholder album art
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 24))
                                .foregroundColor(screenTextColor.opacity(0.3))
                        )

                    Text(playerViewModel.activeServiceName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(screenTextColor.opacity(0.5))

                    if !playerViewModel.hasActiveService {
                        Text("Open Spotify to control")
                            .font(.system(size: 9))
                            .foregroundColor(screenTextColor.opacity(0.4))
                    }
                }

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func albumArtwork(for track: Track) -> some View {
        if let artworkURL = track.artworkURL {
            AsyncImage(url: artworkURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    placeholderArtwork
                case .empty:
                    placeholderArtwork
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.5)
                        )
                @unknown default:
                    placeholderArtwork
                }
            }
            .frame(width: artworkSize, height: artworkSize)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            placeholderArtwork
        }
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.gray.opacity(0.2))
            .frame(width: artworkSize, height: artworkSize)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 28))
                    .foregroundColor(screenTextColor.opacity(0.3))
            )
    }

    // Authentic iPod progress bar gradient: #8BD3FF → #008EE6
    private let progressGradient = LinearGradient(
        colors: [
            Color(red: 0.55, green: 0.83, blue: 1.0),   // #8BD3FF
            Color(red: 0.0, green: 0.56, blue: 0.9)    // #008EE6
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private var progressBar: some View {
        GeometryReader { geo in
            VStack(spacing: 2) {
                // Progress track with diamond scrubber
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(screenTextColor.opacity(0.15))
                        .frame(height: 4)

                    // Filled progress with gradient
                    RoundedRectangle(cornerRadius: 2)
                        .fill(progressGradient)
                        .frame(width: max(0, geo.size.width * playerState.progress), height: 4)

                    // Diamond playhead indicator (iPod 5G signature)
                    DiamondShape()
                        .fill(screenTextColor)
                        .frame(width: 8, height: 8)
                        .offset(x: max(0, min(geo.size.width - 8, geo.size.width * playerState.progress - 4)))
                }

                // Time labels
                HStack {
                    Text(Track.formatTime(playerState.playbackPosition))
                        .font(.system(size: 8, design: .monospaced))
                    Spacer()
                    Text("-" + Track.formatTime(playerState.remainingTime))
                        .font(.system(size: 8, design: .monospaced))
                }
                .foregroundColor(screenTextColor.opacity(0.5))
            }
        }
        .frame(height: 20)
    }
}

// MARK: - Diamond Shape

struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let halfWidth = rect.width / 2
        let halfHeight = rect.height / 2

        path.move(to: CGPoint(x: center.x, y: center.y - halfHeight))
        path.addLine(to: CGPoint(x: center.x + halfWidth, y: center.y))
        path.addLine(to: CGPoint(x: center.x, y: center.y + halfHeight))
        path.addLine(to: CGPoint(x: center.x - halfWidth, y: center.y))
        path.closeSubpath()

        return path
    }
}

struct ColorSelectionView: View {
    @ObservedObject var viewModel: iPodViewModel

    private let screenTextColor = Color.black
    // Authentic iPod highlight gradient: #73C9FF → #006DB0
    private let highlightGradient = LinearGradient(
        colors: [
            Color(red: 0.45, green: 0.79, blue: 1.0),   // #73C9FF
            Color(red: 0.0, green: 0.43, blue: 0.69)    // #006DB0
        ],
        startPoint: .top,
        endPoint: .bottom
    )

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
                .font(.system(size: 13, weight: .medium))

            Spacer()

            if isCurrentColor {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isHighlighted ? highlightGradient : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom))
        .foregroundColor(isHighlighted ? .white : screenTextColor)
    }
}

#Preview {
    ScreenView(viewModel: iPodViewModel())
        .frame(width: 300)
        .padding()
        .background(Color.gray)
}
