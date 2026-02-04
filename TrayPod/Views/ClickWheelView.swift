import SwiftUI

struct ClickWheelView: View {
    @ObservedObject var viewModel: iPodViewModel

    @State private var lastAngle: CGFloat?
    @State private var accumulatedRotation: CGFloat = 0
    @State private var pressedZone: WheelZone?
    @State private var centerPressed: Bool = false

    private let wheelSize: CGFloat = 260
    private let centerButtonSize: CGFloat = 90
    private let rotationThreshold: CGFloat = 0.12 // Radians needed for one "click"

    enum WheelZone {
        case menu, forward, back, playPause
    }

    var body: some View {
        ZStack {
            // Outer wheel with subtle gradient
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            viewModel.selectedColor.wheelColor.opacity(1.1),
                            viewModel.selectedColor.wheelColor
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: wheelSize / 2
                    )
                )
                .frame(width: wheelSize, height: wheelSize)
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)

            // Inner ring shadow effect
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.black.opacity(0.1), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
                .frame(width: centerButtonSize + 20, height: centerButtonSize + 20)

            // Click zone labels with press states
            clickZoneLabels

            // Center button with press effect
            Circle()
                .fill(viewModel.selectedColor.centerButtonColor)
                .frame(width: centerButtonSize, height: centerButtonSize)
                .shadow(color: .black.opacity(centerPressed ? 0.05 : 0.15), radius: centerPressed ? 1 : 3, x: 0, y: centerPressed ? 0 : 2)
                .scaleEffect(centerPressed ? 0.97 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: centerPressed)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !centerPressed {
                                centerPressed = true
                            }
                        }
                        .onEnded { _ in
                            centerPressed = false
                            viewModel.centerButtonPressed()
                        }
                )

            // Interactive click zones
            clickZones
        }
        .frame(width: wheelSize, height: wheelSize)
        .gesture(circularDragGesture)
        .onScrollWheel { delta in
            viewModel.scroll(delta: delta)
        }
        .background(
            KeyboardHandlerView(viewModel: viewModel, rotationThreshold: rotationThreshold)
        )
    }

    // MARK: - Click Zone Labels

    private var clickZoneLabels: some View {
        let textColor = viewModel.selectedColor.wheelTextColor

        return ZStack {
            // Menu (top)
            Text("MENU")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
                .opacity(pressedZone == .menu ? 0.5 : 1.0)
                .offset(y: -wheelSize / 2 + 30)

            // Forward (right)
            Image(systemName: "forward.end.fill")
                .font(.system(size: 14))
                .foregroundColor(textColor)
                .opacity(pressedZone == .forward ? 0.5 : 1.0)
                .offset(x: wheelSize / 2 - 35)

            // Back (left)
            Image(systemName: "backward.end.fill")
                .font(.system(size: 14))
                .foregroundColor(textColor)
                .opacity(pressedZone == .back ? 0.5 : 1.0)
                .offset(x: -wheelSize / 2 + 35)

            // Play/Pause (bottom)
            Image(systemName: "playpause.fill")
                .font(.system(size: 16))
                .foregroundColor(textColor)
                .opacity(pressedZone == .playPause ? 0.5 : 1.0)
                .offset(y: wheelSize / 2 - 30)
        }
        .animation(.easeInOut(duration: 0.08), value: pressedZone)
    }

    // MARK: - Click Zones

    private var clickZones: some View {
        let zoneRadius = wheelSize / 2
        let innerRadius = centerButtonSize / 2 + 10

        return ZStack {
            // Menu button (top)
            InteractiveClickZone(
                startAngle: -60,
                endAngle: -120,
                innerRadius: innerRadius,
                outerRadius: zoneRadius,
                isPressed: pressedZone == .menu
            ) { pressed in
                pressedZone = pressed ? .menu : nil
            } onTap: {
                viewModel.menuButtonPressed()
            }

            // Forward button (right)
            InteractiveClickZone(
                startAngle: 30,
                endAngle: -30,
                innerRadius: innerRadius,
                outerRadius: zoneRadius,
                isPressed: pressedZone == .forward
            ) { pressed in
                pressedZone = pressed ? .forward : nil
            } onTap: {
                viewModel.nextButtonPressed()
            }

            // Back button (left)
            InteractiveClickZone(
                startAngle: 150,
                endAngle: -150,
                innerRadius: innerRadius,
                outerRadius: zoneRadius,
                isPressed: pressedZone == .back
            ) { pressed in
                pressedZone = pressed ? .back : nil
            } onTap: {
                viewModel.previousButtonPressed()
            }

            // Play/Pause button (bottom)
            InteractiveClickZone(
                startAngle: 120,
                endAngle: 60,
                innerRadius: innerRadius,
                outerRadius: zoneRadius,
                isPressed: pressedZone == .playPause
            ) { pressed in
                pressedZone = pressed ? .playPause : nil
            } onTap: {
                viewModel.playPauseButtonPressed()
            }
        }
    }

    // MARK: - Circular Drag Gesture

    private var circularDragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                let center = CGPoint(x: wheelSize / 2, y: wheelSize / 2)
                let location = value.location

                // Check if we're on the wheel (not center button)
                let distanceFromCenter = hypot(location.x - center.x, location.y - center.y)
                let minRadius = centerButtonSize / 2 + 15
                let maxRadius = wheelSize / 2

                guard distanceFromCenter > minRadius && distanceFromCenter < maxRadius else {
                    lastAngle = nil
                    return
                }

                let currentAngle = atan2(location.y - center.y, location.x - center.x)

                if let last = lastAngle {
                    var delta = currentAngle - last

                    // Handle wrap-around at ±π
                    if delta > .pi {
                        delta -= 2 * .pi
                    } else if delta < -.pi {
                        delta += 2 * .pi
                    }

                    accumulatedRotation += delta

                    // Check if we've accumulated enough rotation for a "click"
                    while abs(accumulatedRotation) >= rotationThreshold {
                        let direction: CGFloat = accumulatedRotation > 0 ? 1 : -1
                        viewModel.rotateWheel(delta: direction * rotationThreshold)
                        accumulatedRotation -= direction * rotationThreshold
                    }
                }

                lastAngle = currentAngle
            }
            .onEnded { _ in
                lastAngle = nil
                accumulatedRotation = 0
            }
    }

}

// MARK: - Keyboard Handler

struct KeyboardHandlerView: NSViewRepresentable {
    let viewModel: iPodViewModel
    let rotationThreshold: CGFloat

    func makeNSView(context: Context) -> KeyboardNSView {
        let view = KeyboardNSView()
        view.viewModel = viewModel
        view.rotationThreshold = rotationThreshold
        return view
    }

    func updateNSView(_ nsView: KeyboardNSView, context: Context) {
        nsView.viewModel = viewModel
    }
}

class KeyboardNSView: NSView {
    var viewModel: iPodViewModel?
    var rotationThreshold: CGFloat = 0.12

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard let viewModel = viewModel else {
            super.keyDown(with: event)
            return
        }

        Task { @MainActor in
            switch event.keyCode {
            case 126: // Up arrow
                viewModel.rotateWheel(delta: -rotationThreshold)
            case 125: // Down arrow
                viewModel.rotateWheel(delta: rotationThreshold)
            case 123: // Left arrow
                viewModel.previousButtonPressed()
            case 124: // Right arrow
                viewModel.nextButtonPressed()
            case 36, 49: // Return, Space
                viewModel.centerButtonPressed()
            case 53: // Escape
                viewModel.menuButtonPressed()
            default:
                break
            }
        }
    }
}

// MARK: - Interactive Click Zone

struct InteractiveClickZone: View {
    let startAngle: Double
    let endAngle: Double
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let isPressed: Bool
    let onPressChange: (Bool) -> Void
    let onTap: () -> Void

    var body: some View {
        ArcShape(
            startAngle: Angle(degrees: startAngle),
            endAngle: Angle(degrees: endAngle),
            innerRadius: innerRadius,
            outerRadius: outerRadius
        )
        .fill(isPressed ? Color.black.opacity(0.1) : Color.clear)
        .contentShape(
            ArcShape(
                startAngle: Angle(degrees: startAngle),
                endAngle: Angle(degrees: endAngle),
                innerRadius: innerRadius,
                outerRadius: outerRadius
            )
        )
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        onPressChange(true)
                    }
                }
                .onEnded { _ in
                    onPressChange(false)
                    onTap()
                }
        )
    }
}

struct ArcShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // Outer arc
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: startAngle.degrees > endAngle.degrees
        )

        // Inner arc (reversed)
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: endAngle,
            endAngle: startAngle,
            clockwise: startAngle.degrees <= endAngle.degrees
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Scroll Wheel Support

struct ScrollWheelModifier: ViewModifier {
    let onScroll: (CGFloat) -> Void

    func body(content: Content) -> some View {
        content.background(
            ScrollWheelNSView(onScroll: onScroll)
        )
    }
}

struct ScrollWheelNSView: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ScrollDetectorView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class ScrollDetectorView: NSView {
    var onScroll: ((CGFloat) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func scrollWheel(with event: NSEvent) {
        // Use both deltaY and scrollingDeltaY for better trackpad support
        let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY * 10
        onScroll?(delta)
    }
}

extension View {
    func onScrollWheel(_ action: @escaping (CGFloat) -> Void) -> some View {
        modifier(ScrollWheelModifier(onScroll: action))
    }
}

#Preview {
    ClickWheelView(viewModel: iPodViewModel())
        .padding()
        .background(Color.gray)
}
