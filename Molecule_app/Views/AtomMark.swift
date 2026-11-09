import SwiftUI

struct AtomMark: View {
    var size: CGFloat = 96
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Orbit tilt angles in degrees.
    private let tilts: [Double] = [0, 60, 120]

    var body: some View {
        TimelineView(.animation(paused: !animated || reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(Array(tilts.enumerated()), id: \.offset) { index, tilt in
                    orbit(tilt: tilt, index: index, time: time)
                }
                Circle()
                    .fill(.tint)
                    .frame(width: size * 0.17, height: size * 0.17)
            }
            .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }

    /// One elliptical orbit with its electron.
    private func orbit(tilt: Double, index: Int, time: TimeInterval) -> some View {
        let width = size
        let height = size * 0.36
        let angle = time * (1.4 + Double(index) * 0.35) + Double(index) * 2.1
        return ZStack {
            Ellipse()
                .stroke(.tint.opacity(0.35), lineWidth: max(size * 0.014, 1))
                .frame(width: width, height: height)
            Circle()
                .fill(.tint)
                .frame(width: size * 0.075, height: size * 0.075)
                .offset(x: cos(angle) * width / 2, y: sin(angle) * height / 2)
        }
        .rotationEffect(.degrees(tilt))
    }
}

#Preview {
    VStack(spacing: 40) {
        AtomMark(size: 140)
        AtomMark(size: 48)
    }
}
