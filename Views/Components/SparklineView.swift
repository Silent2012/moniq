import SwiftUI

// MARK: - SparklineView

struct SparklineView: View {
    let data: [Double]
    var color: Color     = DS.Colors.primaryAccent
    var height: CGFloat  = 32
    var showDot: Bool    = true
    var showFill: Bool   = true

    @State private var drawProgress: CGFloat = 0
    @State private var dotPulse     = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                if showFill {
                    fillPath(in: geo.size)
                        .fill(DS.Gradients.chartFill(color: color))
                        .opacity(drawProgress)
                }

                linePath(in: geo.size)
                    .trim(from: 0, to: drawProgress)
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                if showDot, let last = lastPoint(in: geo.size) {
                    ZStack {
                        // Pulsing outer ring
                        Circle()
                            .stroke(color.opacity(0.4), lineWidth: 1.5)
                            .frame(width: 10, height: 10)
                            .scaleEffect(dotPulse ? 1.8 : 1.0)
                            .opacity(dotPulse ? 0 : 0.6)

                        // Solid center dot
                        Circle()
                            .fill(color)
                            .frame(width: 5, height: 5)
                    }
                    .position(last)
                    .onAppear {
                        withAnimation(DS.Animations.pulse) {
                            dotPulse = true
                        }
                    }
                }
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                drawProgress = 1
            }
        }
        .onChange(of: data.count) { _ in
            // Keep progress at 1 during live updates
            drawProgress = 1
        }
    }

    // MARK: - Path helpers

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard data.count > 1 else { return [] }
        let minVal = data.min() ?? 0
        let maxVal = data.max() ?? 1
        let range  = maxVal - minVal > 0 ? maxVal - minVal : 1

        return data.enumerated().map { i, val in
            let x = CGFloat(i) / CGFloat(data.count - 1) * size.width
            let y = (1.0 - CGFloat((val - minVal) / range)) * size.height
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(in size: CGSize) -> Path {
        let points = normalizedPoints(in: size)
        guard points.count > 1 else { return Path() }

        var path = Path()
        path.move(to: points[0])

        // Catmull-Rom smooth curve
        for i in 1..<points.count {
            let prev = points[max(0, i - 1)]
            let curr = points[i]
            let tension: CGFloat = 0.3
            let cp1 = CGPoint(
                x: prev.x + (curr.x - (i >= 2 ? points[i-2] : prev).x) * tension,
                y: prev.y + (curr.y - (i >= 2 ? points[i-2] : prev).y) * tension
            )
            let cp2 = CGPoint(
                x: curr.x - (i < points.count - 1 ? points[i+1] : curr).x * tension + curr.x * tension,
                y: curr.y - (i < points.count - 1 ? points[i+1] : curr).y * tension + curr.y * tension
            )
            path.addCurve(to: curr, control1: cp1, control2: cp2)
        }
        return path
    }

    private func fillPath(in size: CGSize) -> Path {
        let points = normalizedPoints(in: size)
        guard points.count > 1 else { return Path() }

        var path = linePath(in: size)
        path.addLine(to: CGPoint(x: points.last!.x, y: size.height))
        path.addLine(to: CGPoint(x: points.first!.x, y: size.height))
        path.closeSubpath()
        return path
    }

    private func lastPoint(in size: CGSize) -> CGPoint? {
        normalizedPoints(in: size).last
    }
}

// MARK: - Preview

#Preview {
    let data = (0..<60).map { i in
        30 + 40 * sin(Double(i) / 10.0) + Double.random(in: -5...5)
    }

    return VStack(spacing: 20) {
        SparklineView(data: data, color: DS.Colors.secondaryAccent, height: 40)
        SparklineView(data: data.reversed(), color: DS.Colors.pinkAccent, height: 32)
        SparklineView(data: data, color: DS.Colors.successGreen, height: 24, showDot: false)
    }
    .padding()
    .background(DS.Colors.primaryBackground)
    .frame(width: 300)
}
