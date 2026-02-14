import SwiftUI

struct ScreenView: View {
    @ObservedObject var viewModel: iPodViewModel
    @ObservedObject private var battery = BatteryService.shared

    // iPod 5G (Video) - cool blue-tinted LCD background
    private let screenBackgroundColor = Color(red: 0.93, green: 0.95, blue: 0.98)
    private let screenTextColor = Color(red: 0.0, green: 0.0, blue: 0.05)  // Cool black

    // Cool black for shadows (20% blue shift)
    private let coolBlack = Color(red: 0.0, green: 0.02, blue: 0.08)

    // iPod 5G title bar - blue-gray brushed metal style (20% cooler)
    private let titleBarGradient = LinearGradient(
        colors: [
            Color(red: 0.85, green: 0.89, blue: 0.95),  // Cool highlight at top
            Color(red: 0.77, green: 0.81, blue: 0.88),  // Cool mid
            Color(red: 0.71, green: 0.75, blue: 0.83)   // Cool bottom
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

    // Fixed screen dimensions
    private let screenWidth: CGFloat = 250  // Slightly wider
    private let screenHeight: CGFloat = 180
    private let bezelPadding: CGFloat = 5
    private let titleBarHeight: CGFloat = 18

    var body: some View {
        // Outer container - FIXED size, content doesn't affect this
        ZStack {
            // Screen bezel - dark grey with more rounded corners
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.15, green: 0.16, blue: 0.18))

            // LCD screen area - nested rounding inside bezel
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
                    .background {
                        // All decorative layers BEHIND the content
                        ZStack {
                            titleBarGradient

                            // Cool white highlight at top (Aqua style shine)
                            VStack(spacing: 0) {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.95, green: 0.97, blue: 1.0).opacity(0.85),
                                                Color(red: 0.95, green: 0.97, blue: 1.0).opacity(0.4),
                                                Color.clear
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(height: 10)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .overlay(alignment: .bottom) {
                        // Subtle cool shadow at bottom
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(coolBlack.opacity(0.22))
                                .frame(height: 1)
                            Rectangle()
                                .fill(coolBlack.opacity(0.08))
                                .frame(height: 1)
                        }
                    }
                    .clipShape(TopRoundedRectangle(radius: 4))

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
            // Centered title - solid black text (not affected by gradient)
            Text(screenTitle)
                .font(.custom("Helvetica Neue", size: 12).weight(.bold))
                .foregroundColor(Color(red: 0.05, green: 0.05, blue: 0.08))  // Solid cool black
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                // Play/Pause button on left (only on Now Playing)
                if viewModel.currentScreen == .nowPlaying {
                    playPauseButton
                }

                Spacer()

                // Battery on the right
                batteryIndicator
            }
            .frame(maxHeight: .infinity)
        }
    }

    // Play/pause icon for title bar - bright blue with subtle inner shadow
    private var playPauseButton: some View {
        let isPlaying = viewModel.playerViewModel.state.isPlaying
        return Button(action: { viewModel.playerViewModel.togglePlayPause() }) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Color(red: 0.1, green: 0.55, blue: 0.95))  // Bright blue
                .shadow(color: coolBlack.opacity(0.15), radius: 0.3, x: 0.2, y: 0.2)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.1), value: isPlaying)
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
        case .musicMenu:
            return "Music"
        case .playlists:
            return "Playlists"
        case .playlistDetail(_, let name):
            return name
        case .albums:
            return "Albums"
        case .albumDetail(_, let name):
            return name
        case .songs:
            return "Songs"
        case .search:
            return "Search"
        case .searchResults:
            return "Results"
        }
    }

    // Battery synced to real device level (event-driven via IOKit)
    // Desktop Macs without a battery always show full.
    private var batteryIndicator: some View {
        let batteryWidth: CGFloat = 16
        let batteryHeight: CGFloat = 7
        let level = CGFloat(battery.batteryLevel)

        let fillGradient = LinearGradient(
            colors: level <= 0.2 && !battery.isCharging
                ? [Color(red: 0.25, green: 0.04, blue: 0.04),
                   Color(red: 0.90, green: 0.22, blue: 0.18)]
                : [Color(red: 0.04, green: 0.18, blue: 0.04),
                   Color(red: 0.55, green: 0.92, blue: 0.50)],
            startPoint: .bottom,
            endPoint: .top
        )

        return HStack(spacing: 0) {
            // Battery body — fill proportional to level
            ZStack(alignment: .leading) {
                // Empty background
                Rectangle()
                    .fill(Color(red: 0.50, green: 0.52, blue: 0.55).opacity(0.25))

                // Proportional fill
                Rectangle()
                    .fill(fillGradient)
                    .frame(width: batteryWidth * level)
            }
            .frame(width: batteryWidth, height: batteryHeight)
            .clipShape(RoundedRectangle(cornerRadius: 1.5))
            .overlay(
                RoundedRectangle(cornerRadius: 1.5)
                    .stroke(Color(red: 0.30, green: 0.32, blue: 0.36), lineWidth: 0.75)
            )
            .shadow(color: coolBlack.opacity(0.18), radius: 1.5, y: 0.8)

            // Battery tip/nub
            RoundedRectangle(cornerRadius: 0.5)
                .fill(Color(red: 0.45, green: 0.47, blue: 0.52))
                .frame(width: 1.5, height: 3)
        }
    }

    @ViewBuilder
    private var screenContent: some View {
        Group {
            switch viewModel.currentScreen {
            case .main, .settings, .musicMenu, .playlists, .albums, .songs,
                 .playlistDetail, .albumDetail, .searchResults:
                MenuListView(viewModel: viewModel)
            case .nowPlaying:
                NowPlayingView(viewModel: viewModel, playerViewModel: viewModel.playerViewModel)
                    .drawingGroup()
            case .colorSelection:
                ColorSelectionView(viewModel: viewModel)
            case .search:
                SearchInputView(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(
            .asymmetric(
                insertion: .move(edge: viewModel.transitionDirection == .trailing ? .trailing : .leading),
                removal: .move(edge: viewModel.transitionDirection == .trailing ? .leading : .trailing)
            )
        )
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

    // MARK: - Design System
    private let screenTextColor = Color.black
    private let artworkSize: CGFloat = 70
    private let horizontalPadding: CGFloat = 11  // 10% increase for iPod 5G styling
    private let bodyFont = Font.custom("Helvetica Neue", size: 11).weight(.bold)
    private let smallFont = Font.custom("Helvetica Neue", size: 10).weight(.bold)

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
                    .font(bodyFont)
                    .foregroundColor(screenTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 4)

                // Main content: Album art LEFT, details RIGHT (vertically centered)
                HStack(alignment: .center, spacing: 10) {
                    // Album artwork on left
                    albumArtwork(for: track)

                    // Track info on right - vertically centered with album art
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(bodyFont)
                            .foregroundColor(screenTextColor)
                            .lineLimit(2)

                        Text(track.artist)
                            .font(bodyFont)
                            .foregroundColor(screenTextColor)
                            .lineLimit(1)

                        Text(track.album)
                            .font(bodyFont)
                            .foregroundColor(screenTextColor)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 2)

                Spacer(minLength: 2)

                // Status bar at bottom - swaps between progress and volume
                statusBarArea
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 6)
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
                .clipShape(Rectangle())
            } else {
                placeholderArtwork
            }
        }
    }

    private var placeholderArtwork: some View {
        Rectangle()
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

    // MARK: - Status Bar (Progress / Volume swap)

    /// Container that swaps between progress bar and volume bar with slide animation
    private var statusBarArea: some View {
        ZStack {
            if playerViewModel.isAdjustingVolume {
                // Volume bar slides in from right
                volumeBar
                    .transition(iPodTransition.barSwap(showingVolume: true))
                    .id("volumeBar")
            } else {
                // Progress bar slides in from left
                progressBar
                    .transition(iPodTransition.barSwap(showingVolume: false))
                    .id("progressBar")
            }
        }
        .animation(iPodAnimation.standard, value: playerViewModel.isAdjustingVolume)
        .clipped()  // Clip sliding content
    }

    private var progressBar: some View {
        StatusBarView(
            progress: playerState.progress,
            leftContent: {
                Text(Track.formatTime(playerState.playbackPosition))
            },
            rightContent: {
                Text("-" + Track.formatTime(playerState.remainingTime))
            }
        )
    }

    private var volumeBar: some View {
        StatusBarView(
            progress: CGFloat(playerState.volume),
            leftContent: {
                Image(systemName: "speaker.fill")
            },
            rightContent: {
                Image(systemName: "speaker.wave.3.fill")
            }
        )
    }
}

// MARK: - Custom Shapes

/// Shape with only top corners rounded (for title bar)
struct TopRoundedRectangle: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Start at bottom-left
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        // Line up to top-left corner curve
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        // Top-left corner
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                    radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        // Line to top-right corner curve
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        // Top-right corner
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                    radius: radius, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        // Line down to bottom-right
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        // Close path
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
