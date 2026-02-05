import SwiftUI

struct ScreenView: View {
    @ObservedObject var viewModel: iPodViewModel

    // iPod 5G (Video) - white background LCD
    private let screenBackgroundColor = Color.white
    private let screenTextColor = Color.black

    // iPod 5G title bar - brushed metal style gradient
    private let titleBarGradient = LinearGradient(
        colors: [
            Color(red: 0.92, green: 0.92, blue: 0.93),  // Bright highlight at top
            Color(red: 0.84, green: 0.84, blue: 0.85),  // Mid
            Color(red: 0.78, green: 0.78, blue: 0.79)   // Darker at bottom
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // iPod 5G battery green - vibrant like the real thing
    private let batteryGreen = Color(red: 0.20, green: 0.78, blue: 0.20)

    // Aqua-style blue for play button
    private let aquaBlue = LinearGradient(
        colors: [
            Color(red: 0.40, green: 0.70, blue: 0.98),  // Lighter top
            Color(red: 0.20, green: 0.50, blue: 0.90)   // Darker bottom
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // Fixed screen dimensions - NEVER changes
    private let screenWidth: CGFloat = 310
    private let screenHeight: CGFloat = 180
    private let bezelPadding: CGFloat = 5
    private let titleBarHeight: CGFloat = 26

    var body: some View {
        // Outer container - FIXED size, content doesn't affect this
        ZStack {
            // Screen bezel - BLACK like reference image
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)

            // LCD screen area - white background
            RoundedRectangle(cornerRadius: 4)
                .fill(screenBackgroundColor)
                .padding(bezelPadding)

            // Content container with fixed layout
            VStack(spacing: 0) {
                // Title bar - iPod 5G style with prominent 3D shadow effect
                titleBar
                    .frame(height: titleBarHeight)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 6)
                    .background(titleBarGradient)
                    .overlay(alignment: .top) {
                        // PROMINENT white highlight at top (Aqua style shine)
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.85),
                                        Color.white.opacity(0.4),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 12)
                    }
                    .overlay(alignment: .bottom) {
                        // Intense crisp shadow at bottom (low spread, high contrast)
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.black.opacity(0.35))
                                .frame(height: 1)
                            Rectangle()
                                .fill(Color.black.opacity(0.12))
                                .frame(height: 1)
                        }
                    }

                // Content area - fixed size box that clips content
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        screenContent
                    }
                    .clipped()
            }
            .padding(bezelPadding)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .frame(width: screenWidth, height: screenHeight)
        .fixedSize()  // Prevent parent from affecting size
    }

    private var titleBar: some View {
        ZStack {
            // Centered title - Helvetica Neue (authentic iPod Classic font)
            Text(screenTitle)
                .font(.custom("Helvetica Neue", size: 13).weight(.bold))
                .foregroundColor(screenTextColor)

            HStack {
                // Play button on left (only on Now Playing)
                if viewModel.currentScreen == .nowPlaying {
                    playPauseButton
                }

                Spacer()

                // Battery on the right
                batteryIndicator
            }
        }
    }

    // Simple play/pause icon for title bar (iPod-style)
    private var playPauseButton: some View {
        Button(action: { viewModel.playerViewModel.togglePlayPause() }) {
            Image(systemName: viewModel.playerViewModel.state.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(red: 0.0, green: 0.50, blue: 0.85))
        }
        .buttonStyle(.plain)
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
        HStack(spacing: 0) {
            // Battery body with glossy green fill
            ZStack {
                // Outer border
                RoundedRectangle(cornerRadius: 2)
                    .stroke(screenTextColor.opacity(0.8), lineWidth: 1)
                    .frame(width: 20, height: 9)

                // Continuous green fill with glossy gradient
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.45, green: 0.95, blue: 0.45),  // Bright highlight
                                Color(red: 0.25, green: 0.80, blue: 0.25),  // Mid green
                                Color(red: 0.15, green: 0.65, blue: 0.15)   // Darker base
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 16, height: 5)
                    .overlay(
                        // Glossy shine highlight
                        RoundedRectangle(cornerRadius: 1)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .frame(height: 2)
                            .offset(y: -1)
                        , alignment: .top
                    )
            }

            // Battery tip/nub
            RoundedRectangle(cornerRadius: 0.5)
                .fill(screenTextColor.opacity(0.8))
                .frame(width: 2, height: 4)
                .offset(x: 1)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(
            .asymmetric(
                insertion: .move(edge: viewModel.transitionDirection == .trailing ? .trailing : .leading),
                removal: .move(edge: viewModel.transitionDirection == .trailing ? .leading : .trailing)
            )
        )
        .animation(.easeInOut(duration: 0.25), value: viewModel.currentScreen)
        .id(viewModel.currentScreen)
    }
}

struct MenuListView: View {
    @ObservedObject var viewModel: iPodViewModel

    private let screenTextColor = Color.black
    // iPod 5G blue highlight gradient (Aqua-style)
    private let highlightGradient = LinearGradient(
        colors: [
            Color(red: 0.30, green: 0.67, blue: 0.95),  // Lighter blue top
            Color(red: 0.0, green: 0.50, blue: 0.85)    // Darker blue bottom
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
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
        HStack(spacing: 0) {
            // iPod 5G: Text-only menus, Helvetica Neue
            Text(item.title)
                .font(.custom("Helvetica Neue", size: 13).weight(.medium))

            Spacer()

            // Chevron for navigation items
            if case .navigate = item.action {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity)  // Full width
        .background(
            Group {
                if isSelected {
                    highlightGradient
                } else {
                    Color.clear
                }
            }
        )
        .foregroundColor(isSelected ? .white : screenTextColor)
    }
}

struct NowPlayingView: View {
    @ObservedObject var viewModel: iPodViewModel
    @ObservedObject var playerViewModel: PlayerViewModel

    private let screenTextColor = Color.black
    private let artworkSize: CGFloat = 70 // Album art size

    private var playerState: PlayerState {
        playerViewModel.state
    }

    private var track: Track? {
        playerState.currentTrack
    }

    var body: some View {
        VStack(spacing: 0) {
            if let track = track {
                // Track position "1 of 1" left-aligned above album artwork
                Text("1 of 1")
                    .font(.custom("Helvetica Neue", size: 10))
                    .foregroundColor(screenTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                    .padding(.top, 4)

                // Main content: Album art LEFT, details RIGHT
                HStack(alignment: .top, spacing: 10) {
                    // Album artwork on left
                    albumArtwork(for: track)
                        .shadow(color: Color.black.opacity(0.25), radius: 2, x: 1, y: 1)

                    // Track info on right - all same size, all black like reference
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.custom("Helvetica Neue", size: 11).weight(.bold))
                            .foregroundColor(screenTextColor)
                            .lineLimit(2)

                        Text(track.artist)
                            .font(.custom("Helvetica Neue", size: 11))
                            .foregroundColor(screenTextColor)
                            .lineLimit(1)

                        Text(track.album)
                            .font(.custom("Helvetica Neue", size: 11))
                            .foregroundColor(screenTextColor)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 6)
                .padding(.top, 4)

                Spacer()

                // Progress bar at bottom
                progressBar
                    .padding(.horizontal, 6)
                    .padding(.bottom, 4)
            } else {
                // No track playing
                Spacer()

                VStack(spacing: 6) {
                    placeholderArtwork
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 1, y: 1)

                    Text(playerViewModel.activeServiceName)
                        .font(.custom("Helvetica Neue", size: 11).weight(.medium))
                        .foregroundColor(screenTextColor.opacity(0.5))

                    if !playerViewModel.hasActiveService {
                        Text("Open Spotify to control")
                            .font(.custom("Helvetica Neue", size: 9))
                            .foregroundColor(screenTextColor.opacity(0.4))
                    }
                }

                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func albumArtwork(for track: Track) -> some View {
        Group {
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
                .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                placeholderArtwork
            }
        }
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(
                LinearGradient(
                    colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.25)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: artworkSize, height: artworkSize)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 24))
                    .foregroundColor(screenTextColor.opacity(0.25))
            )
    }

    // iPod 5G progress bar gradient (matches highlight)
    private let progressGradient = LinearGradient(
        colors: [
            Color(red: 0.30, green: 0.67, blue: 0.95),  // Lighter blue top
            Color(red: 0.0, green: 0.50, blue: 0.85)    // Darker blue bottom
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private var progressBar: some View {
        GeometryReader { geo in
            VStack(spacing: 2) {
                // iPod 5G progress bar - simple thick bar, NO thumb
                ZStack(alignment: .leading) {
                    // Background track - gray unfilled portion
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.35))
                        .frame(height: 7)

                    // Filled progress with blue gradient
                    RoundedRectangle(cornerRadius: 3)
                        .fill(progressGradient)
                        .frame(width: max(0, geo.size.width * playerState.progress), height: 7)
                }

                // Time labels - black like reference
                HStack {
                    Text(Track.formatTime(playerState.playbackPosition))
                        .font(.custom("Helvetica Neue", size: 10))
                    Spacer()
                    Text("-" + Track.formatTime(playerState.remainingTime))
                        .font(.custom("Helvetica Neue", size: 10))
                }
                .foregroundColor(screenTextColor)
            }
        }
        .frame(height: 22)
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
    // iPod 5G blue highlight gradient (Aqua-style)
    private let highlightGradient = LinearGradient(
        colors: [
            Color(red: 0.30, green: 0.67, blue: 0.95),  // Lighter blue top
            Color(red: 0.0, green: 0.50, blue: 0.85)    // Darker blue bottom
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
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
        HStack(spacing: 0) {
            Circle()
                .fill(color.bodyColor)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .stroke(screenTextColor.opacity(0.3), lineWidth: 1)
                )
                .padding(.trailing, 6)

            Text(color.rawValue)
                .font(.custom("Helvetica Neue", size: 13).weight(.medium))

            Spacer()

            if isCurrentColor {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity)  // Full width
        .background(
            Group {
                if isHighlighted {
                    highlightGradient
                } else {
                    Color.clear
                }
            }
        )
        .foregroundColor(isHighlighted ? .white : screenTextColor)
    }
}

#Preview {
    ScreenView(viewModel: iPodViewModel())
        .frame(width: 300)
        .padding()
        .background(Color.gray)
}
