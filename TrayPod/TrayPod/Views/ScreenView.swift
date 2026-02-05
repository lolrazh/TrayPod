import SwiftUI

struct ScreenView: View {
    @ObservedObject var viewModel: iPodViewModel

    // iPod 5G (Video) - white background LCD
    private let screenBackgroundColor = Color.white
    private let screenTextColor = Color.black

    // Aqua-style title bar gradient (lighter top, darker bottom)
    private let titleBarGradient = LinearGradient(
        colors: [
            Color(red: 0.92, green: 0.92, blue: 0.92),  // Light gray top
            Color(red: 0.78, green: 0.78, blue: 0.78)   // Darker gray bottom
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ZStack {
            // Screen bezel - BLACK like reference image
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)

            // LCD screen area
            ZStack {
                // Base LCD color - pure white
                RoundedRectangle(cornerRadius: 4)
                    .fill(screenBackgroundColor)
            }
            .padding(5)

            // Screen content with title bar
            VStack(spacing: 0) {
                // Aqua-style title bar with gradient and bottom shadow
                titleBar
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(titleBarGradient)
                    .overlay(
                        // Bottom shadow line (Aqua style)
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(Color.black.opacity(0.2))
                                .frame(height: 1)
                        }
                    )

                // Content area - no horizontal padding for full-width selection
                screenContent
            }
            .padding(5)
            .clipShape(RoundedRectangle(cornerRadius: 4))
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
        VStack(spacing: 2) {
            if let track = track {
                // Track position (like "6 of 15") - matches reference
                Text("1 of 1")
                    .font(.system(size: 9))
                    .foregroundColor(screenTextColor.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                Spacer(minLength: 2)

                // Centered album artwork with Aqua-style shadow
                albumArtwork(for: track)
                    .shadow(color: Color.black.opacity(0.3), radius: 3, x: 1, y: 2)

                Spacer(minLength: 4)

                // Centered track info
                VStack(spacing: 1) {
                    Text(track.title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(screenTextColor)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.system(size: 10))
                        .foregroundColor(screenTextColor)
                        .lineLimit(1)

                    Text(track.album)
                        .font(.system(size: 9))
                        .foregroundColor(screenTextColor.opacity(0.7))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 2)

                // Progress bar with diamond scrubber
                progressBar
                    .padding(.horizontal, 4)
            } else {
                // No track playing
                Spacer()

                VStack(spacing: 6) {
                    placeholderArtwork
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 1, y: 1)

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

    // Aqua-style progress bar gradient
    private let progressGradient = LinearGradient(
        colors: [
            Color(red: 0.55, green: 0.83, blue: 1.0),   // Light blue top
            Color(red: 0.0, green: 0.56, blue: 0.9)    // Darker blue bottom
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private var progressBar: some View {
        GeometryReader { geo in
            VStack(spacing: 1) {
                // Progress track with diamond scrubber
                ZStack(alignment: .leading) {
                    // Background track - Aqua style inset
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                        )

                    // Filled progress with gradient
                    RoundedRectangle(cornerRadius: 2)
                        .fill(progressGradient)
                        .frame(width: max(0, geo.size.width * playerState.progress), height: 5)

                    // Diamond playhead indicator (iPod 5G signature)
                    DiamondShape()
                        .fill(screenTextColor)
                        .frame(width: 7, height: 7)
                        .offset(x: max(0, min(geo.size.width - 7, geo.size.width * playerState.progress - 3.5)))
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
        .frame(height: 18)
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
                .font(.system(size: 13, weight: .medium))

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
