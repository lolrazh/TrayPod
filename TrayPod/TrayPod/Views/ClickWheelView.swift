import SwiftUI
import AppKit

struct ClickWheelView: View {
    @ObservedObject var viewModel: iPodViewModel

    @State private var pressedZone: WheelZone?
    @State private var centerPressed: Bool = false

    private let wheelSize: CGFloat = 260
    private let centerButtonSize: CGFloat = 100  // ~38% of wheel, closer to real iPod proportions

    enum WheelZone: Equatable {
        case menu, forward, back, playPause
    }

    var body: some View {
        ZStack {
            // Outer wheel - minimal shadow since it's nearly flush with body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            viewModel.selectedColor.wheelColor.opacity(1.05),
                            viewModel.selectedColor.wheelColor
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: wheelSize / 2
                    )
                )
                .frame(width: wheelSize, height: wheelSize)
                .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)

            // Brushed metal texture for silver/white variants
            if viewModel.selectedColor.hasBrushedMetalWheel {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.gray.opacity(0.04),
                                Color.white.opacity(0.10),
                                Color.gray.opacity(0.06),
                                Color.white.opacity(0.12)
                            ],
                            center: .center
                        )
                    )
                    .frame(width: wheelSize, height: wheelSize)
            }

            // Concentric groove rings - start right outside center button
            ForEach(0..<5, id: \.self) { i in
                let grooveRadius = centerButtonSize / 2 + 8 + CGFloat(i) * 14
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.04),
                                Color.white.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
                    .frame(width: grooveRadius * 2, height: grooveRadius * 2)
            }

            // Click zone labels with press states
            clickZoneLabels

            // Subtle hairline gap between center and wheel (just visual separation)
            Circle()
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
                .frame(width: centerButtonSize + 2, height: centerButtonSize + 2)

            // Center button with minimal press effect
            Circle()
                .fill(viewModel.selectedColor.centerButtonColor)
                .frame(width: centerButtonSize, height: centerButtonSize)
                .shadow(color: .black.opacity(centerPressed ? 0.02 : 0.06), radius: centerPressed ? 0.5 : 1, x: 0, y: centerPressed ? 0 : 0.5)
                .scaleEffect(centerPressed ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: centerPressed)

            // Unified gesture handler for the whole wheel
            WheelGestureView(
                wheelSize: wheelSize,
                centerButtonSize: centerButtonSize,
                pressedZone: $pressedZone,
                centerPressed: $centerPressed,
                onZoneTap: handleZoneTap,
                onCenterTap: { viewModel.centerButtonPressed() },
                onScroll: { delta in viewModel.scroll(delta: delta) }
            )
            .frame(width: wheelSize, height: wheelSize)
        }
        .frame(width: wheelSize, height: wheelSize)
    }

    // MARK: - Click Zone Labels

    private var clickZoneLabels: some View {
        let textColor = viewModel.selectedColor.wheelTextColor
        // Position labels in the middle of the touch ring
        let labelOffset = (wheelSize / 2 + centerButtonSize / 2) / 2  // ~90 from center

        return ZStack {
            // Menu (top)
            Text("MENU")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(textColor)
                .opacity(pressedZone == .menu ? 0.5 : 1.0)
                .offset(y: -labelOffset)

            // Forward (right)
            Image(systemName: "forward.end.fill")
                .font(.system(size: 14))
                .foregroundColor(textColor)
                .opacity(pressedZone == .forward ? 0.5 : 1.0)
                .offset(x: labelOffset)

            // Back (left)
            Image(systemName: "backward.end.fill")
                .font(.system(size: 14))
                .foregroundColor(textColor)
                .opacity(pressedZone == .back ? 0.5 : 1.0)
                .offset(x: -labelOffset)

            // Play/Pause (bottom)
            Image(systemName: "playpause.fill")
                .font(.system(size: 16))
                .foregroundColor(textColor)
                .opacity(pressedZone == .playPause ? 0.5 : 1.0)
                .offset(y: labelOffset)
        }
        .animation(.easeInOut(duration: 0.08), value: pressedZone)
    }

    private func handleZoneTap(_ zone: WheelZone) {
        switch zone {
        case .menu:
            viewModel.menuButtonPressed()
        case .forward:
            viewModel.nextButtonPressed()
        case .back:
            viewModel.previousButtonPressed()
        case .playPause:
            viewModel.playPauseButtonPressed()
        }
    }
}

// MARK: - Wheel Gesture NSView

struct WheelGestureView: NSViewRepresentable {
    let wheelSize: CGFloat
    let centerButtonSize: CGFloat
    @Binding var pressedZone: ClickWheelView.WheelZone?
    @Binding var centerPressed: Bool
    let onZoneTap: (ClickWheelView.WheelZone) -> Void
    let onCenterTap: () -> Void
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> WheelNSView {
        let view = WheelNSView(frame: NSRect(x: 0, y: 0, width: wheelSize, height: wheelSize))
        view.wheelSize = wheelSize
        view.centerButtonSize = centerButtonSize
        view.onZonePress = { zone in
            DispatchQueue.main.async { pressedZone = zone }
        }
        view.onCenterPress = { pressed in
            DispatchQueue.main.async { centerPressed = pressed }
        }
        view.onZoneTap = onZoneTap
        view.onCenterTap = onCenterTap
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: WheelNSView, context: Context) {
        nsView.wheelSize = wheelSize
        nsView.centerButtonSize = centerButtonSize
    }
}

class WheelNSView: NSView {
    var wheelSize: CGFloat = 260
    var centerButtonSize: CGFloat = 100

    var onZonePress: ((ClickWheelView.WheelZone?) -> Void)?
    var onCenterPress: ((Bool) -> Void)?
    var onZoneTap: ((ClickWheelView.WheelZone) -> Void)?
    var onCenterTap: (() -> Void)?
    var onScroll: ((CGFloat) -> Void)?

    private var currentZone: ClickWheelView.WheelZone?
    private var isPressingCenter = false

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let distance = hypot(location.x - center.x, location.y - center.y)

        if distance <= centerButtonSize / 2 {
            // Center button pressed
            isPressingCenter = true
            onCenterPress?(true)
        } else if distance <= wheelSize / 2 {
            // Wheel zone pressed
            if let zone = zoneForLocation(location, center: center) {
                currentZone = zone
                onZonePress?(zone)
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        if isPressingCenter {
            isPressingCenter = false
            onCenterPress?(false)
            onCenterTap?()
        } else if let zone = currentZone {
            onZonePress?(nil)
            onZoneTap?(zone)
            currentZone = nil
        }
    }

    override func scrollWheel(with event: NSEvent) {
        // Use scrollingDeltaY for smooth trackpad scrolling
        let delta = event.scrollingDeltaY
        if abs(delta) > 0.1 {
            onScroll?(delta)
        }
    }

    private func zoneForLocation(_ location: CGPoint, center: CGPoint) -> ClickWheelView.WheelZone? {
        let dx = location.x - center.x
        // NSView: Y increases upward, so location.y > center.y means ABOVE center
        let dy = location.y - center.y

        // Calculate angle in degrees
        // 0° = right, 90° = top, 180°/-180° = left, -90° = bottom
        let angle = atan2(dy, dx) * 180 / .pi

        // Determine zone based on angle
        // Top (Menu): 45° to 135°
        // Left (Back): 135° to 180° OR -180° to -135°
        // Bottom (Play/Pause): -135° to -45°
        // Right (Forward): -45° to 45°

        if angle >= 45 && angle < 135 {
            return .menu
        } else if angle >= 135 || angle < -135 {
            return .back
        } else if angle >= -135 && angle < -45 {
            return .playPause
        } else {
            return .forward
        }
    }
}

#Preview {
    ClickWheelView(viewModel: iPodViewModel())
        .padding()
        .background(Color.gray)
}
