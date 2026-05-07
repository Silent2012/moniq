import SwiftUI

// MARK: - AnimatedRing

struct AnimatedRing<Center: View>: View {
    let value: Double       // 0.0 – 1.0
    let color: Color
    var lineWidth: CGFloat  = 12
    var size: CGFloat       = 120
    var glowEnabled: Bool   = true
    let center: Center

    @State private var animatedValue: Double = 0

    init(
        value: Double,
        color: Color,
        lineWidth: CGFloat = 12,
        size: CGFloat = 120,
        glowEnabled: Bool = true,
        @ViewBuilder center: () -> Center
    ) {
        self.value = value
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
        self.glowEnabled = glowEnabled
        self.center = center()
    }

    var body: some View {
        ZStack {
            // Track (background ring)
            Circle()
                .stroke(DS.Colors.cardBorder, lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Value arc
            Circle()
                .trim(from: 0, to: animatedValue)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .shadow(color: glowEnabled ? color.opacity(0.5) : .clear, radius: 8, x: 0, y: 0)

            // Center content
            center
        }
        .onAppear {
            withAnimation(DS.Animations.dataUpdate) {
                animatedValue = value.clamped(to: 0...1)
            }
        }
        .onChange(of: value) { newVal in
            withAnimation(DS.Animations.dataUpdate) {
                animatedValue = newVal.clamped(to: 0...1)
            }
        }
    }
}

// MARK: - Multi-segment ring (for memory breakdown)

struct SegmentedRing: View {
    struct Segment {
        let value: Double   // 0-1 fraction of total
        let color: Color
        let label: String
    }

    let segments: [Segment]
    var lineWidth: CGFloat = 16
    var size: CGFloat = 160
    let centerContent: AnyView

    @State private var appeared = false

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(DS.Colors.cardBorder, lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Segments drawn back to front
            ForEach(Array(computedArcs.enumerated()), id: \.offset) { idx, arc in
                Circle()
                    .trim(from: appeared ? arc.start : arc.start, to: appeared ? arc.end : arc.start)
                    .stroke(arc.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: arc.color.opacity(0.4), radius: 6)
                    .animation(DS.Animations.dataUpdate.delay(Double(idx) * 0.05), value: appeared)
            }

            centerContent
        }
        .onAppear { appeared = true }
    }

    private struct ComputedArc {
        let start: CGFloat
        let end: CGFloat
        let color: Color
    }

    private var computedArcs: [ComputedArc] {
        var offset: CGFloat = 0
        return segments.map { seg in
            let start = offset
            let end   = offset + CGFloat(seg.value)
            offset = end
            return ComputedArc(start: start, end: min(end, 1.0), color: seg.color)
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 40) {
        AnimatedRing(value: 0.47, color: DS.Colors.secondaryAccent, size: 120) {
            VStack(spacing: 2) {
                Text("47%")
                    .font(DS.Fonts.mediumNumber())
                    .foregroundColor(DS.Colors.secondaryAccent)
                Text("CPU")
                    .font(DS.Fonts.micro())
                    .foregroundColor(DS.Colors.secondaryText)
            }
        }

        AnimatedRing(value: 0.72, color: DS.Colors.pinkAccent, lineWidth: 14, size: 140) {
            VStack(spacing: 2) {
                Text("11.5")
                    .font(DS.Fonts.mediumNumber())
                    .foregroundColor(DS.Colors.pinkAccent)
                Text("/ 16 GB")
                    .font(DS.Fonts.caption())
                    .foregroundColor(DS.Colors.secondaryText)
            }
        }
    }
    .padding(40)
    .background(DS.Colors.primaryBackground)
}
