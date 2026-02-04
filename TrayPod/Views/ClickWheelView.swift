import SwiftUI

struct ClickWheelView: View {
    @ObservedObject var viewModel: iPodViewModel

    @State private var lastAngle: CGFloat?
    @State private var accumulatedRotation: CGFloat = 0

    private let wheelSize: CGFloat = 260
    private let centerButtonSize: CGFloat = 90
    private let rotationThreshold: CGFloat = 0.08 // Radians needed for one "click"

    var body: some View {
        ZStack {
            // Outer wheel
            Circle()
                .fill(viewModel.selectedColor.wheelColor)
                .frame(width: wheelSize, height: wheelSize)
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)

            // Click zone labels
            clickZoneLabels

            // Center button
            Circle()
                .fill(viewModel.selectedColor.centerButtonColor)
                .frame(width: centerButtonSize, height: centerButtonSize)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                .onTapGesture {
                    viewModel.centerButtonPressed()
                }

            // Invisible click zones
            clickZones
        }
        .frame(width: wheelSize, height: wheelSize)
        .gesture(circularDragGesture)
        .onScrollWheel { delta in
            viewModel.scroll(delta: delta)
        }
    }

    // MARK: - Click Zone Labels

    private var clickZoneLabels: some View {
        let textColor = viewModel.selectedColor.wheelTextColor

        return ZStack {
            // Menu (top)
            Text("MENU")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
                .offset(y: -wheelSize / 2 + 30)

            // Forward (right)
            Image(systemName: "forward.end.fill")
                .font(.system(size: 14))
                .foregroundColor(textColor)
                .offset(x: wheelSize / 2 - 35)

            // Back (left)
            Image(systemName: "backward.end.fill")
                .font(.system(size: 14))
                .foregroundColor(textColor)
                .offset(x: -wheelSize / 2 + 35)

            // Play/Pause (bottom)
            Image(systemName: "playpause.fill")
                .font(.system(size: 16))
                .foregroundColor(textColor)
                .offset(y: wheelSize / 2 - 30)
        }
    }

    // MARK: - Click Zones

    private var clickZones: some View {
        let zoneRadius = wheelSize / 2
        let innerRadius = centerButtonSize / 2 + 10

        return ZStack {
            // Menu button (top)
            ClickZone(
                startAngle: -60,
                endAngle: -120,
                innerRadius: innerRadius,
                outerRadius: zoneRadius
            ) {
                viewModel.menuButtonPressed()
            }

            // Forward button (right)
            ClickZone(
                startAngle: 30,
                endAngle: -30,
                innerRadius: innerRadius,
                outerRadius: zoneRadius
            ) {
                viewModel.nextButtonPressed()
            }

            // Back button (left)
            ClickZone(
                startAngle: 150,
                endAngle: -150,
                innerRadius: innerRadius,
                outerRadius: zoneRadius
            ) {
                viewModel.previousButtonPressed()
            }

            // Play/Pause button (bottom)
            ClickZone(
                startAngle: 120,
                endAngle: 60,
                innerRadius: innerRadius,
                outerRadius: zoneRadius
            ) {
                viewModel.playPauseButtonPressed()
            }
        }
    }

    // MARK: - Circular Drag Gesture

    private var circularDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let center = CGPoint(x: wheelSize / 2, y: wheelSize / 2)
                let location = value.location

                // Check if we're on the wheel (not center button)
                let distanceFromCenter = hypot(location.x - center.x, location.y - center.y)
                guard distanceFromCenter > centerButtonSize / 2 + 5 else {
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
                    if abs(accumulatedRotation) >= rotationThreshold {
                        let clicks = Int(accumulatedRotation / rotationThreshold)
                        viewModel.rotateWheel(delta: CGFloat(clicks) * rotationThreshold)
                        accumulatedRotation = accumulatedRotation.truncatingRemainder(dividingBy: rotationThreshold)
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

// MARK: - Click Zone Shape

struct ClickZone: View {
    let startAngle: Double
    let endAngle: Double
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let action: () -> Void

    var body: some View {
        ArcShape(
            startAngle: Angle(degrees: startAngle),
            endAngle: Angle(degrees: endAngle),
            innerRadius: innerRadius,
            outerRadius: outerRadius
        )
        .fill(Color.clear)
        .contentShape(
            ArcShape(
                startAngle: Angle(degrees: startAngle),
                endAngle: Angle(degrees: endAngle),
                innerRadius: innerRadius,
                outerRadius: outerRadius
            )
        )
        .onTapGesture {
            action()
        }
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

// MARK: - Scroll Wheel Modifier

struct ScrollWheelModifier: ViewModifier {
    let onScroll: (CGFloat) -> Void

    func body(content: Content) -> some View {
        content
            .background(
                ScrollWheelView(onScroll: onScroll)
            )
    }
}

struct ScrollWheelView: NSViewRepresentable {
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

    override func scrollWheel(with event: NSEvent) {
        onScroll?(event.scrollingDeltaY)
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
