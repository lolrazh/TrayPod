import SwiftUI

struct ScreenView: View {
    @ObservedObject var viewModel: iPodViewModel

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
                    .background(titleBarGradient)
                    .overlay(alignment: .top) {
                        // Cool white highlight at top (Aqua style shine)
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

    // Simple battery - matches play button styling
    private var batteryIndicator: some View {
        HStack(spacing: 0) {
            // Battery body - solid dark green, no border
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(red: 0.15, green: 0.55, blue: 0.15))
                .frame(width: 18, height: 8)

            // Battery tip/nub
            RoundedRectangle(cornerRadius: 0.5)
                .fill(Color(red: 0.15, green: 0.55, blue: 0.15))
                .frame(width: 2, height: 4)
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

                // Progress bar at bottom - pushed up closer to content
                progressBar
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
            VStack(spacing: 3) {
                // iPod 5G progress bar - sharp edges with downward shadow
                ZStack(alignment: .leading) {
                    // Background track - gray unfilled portion with downward shadow
                    Rectangle()
                        .fill(Color.gray.opacity(0.35))
                        .frame(height: 14)
                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 2)

                    // Filled progress with blue gradient
                    Rectangle()
                        .fill(progressGradient)
                        .frame(width: max(0, geo.size.width * playerState.progress), height: 14)
                }

                // Time labels - unified 11pt bold font
                HStack {
                    Text(Track.formatTime(playerState.playbackPosition))
                        .font(bodyFont)
                    Spacer()
                    Text("-" + Track.formatTime(playerState.remainingTime))
                        .font(bodyFont)
                }
                .foregroundColor(screenTextColor)
            }
        }
        .frame(height: 28)
    }
}

// MARK: - Custom Shapes

/// Screen shape with only bottom corners rounded (top is sharp for title bar)
struct BottomRoundedRectangle: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                    radius: radius, startAngle: .zero, endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                    radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.closeSubpath()
        return path
    }
}

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
