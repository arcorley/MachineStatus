import SwiftUI

struct SparklineView: View {
    var values: [Double]
    var height: CGFloat = 40
    var lineWidth: CGFloat = 1.5

    private var normalizedValues: [Double] {
        guard let maxVal = values.max(), maxVal > 0 else { return values.map { _ in 0.0 } }
        return values.map { min(max($0 / maxVal, 0), 1) }
    }

    private var latestColor: Color {
        guard let last = normalizedValues.last else { return .green }
        switch last {
        case 0..<0.6: return .green
        case 0.6..<0.85: return .yellow
        default: return .red
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            let points = self.points(in: CGSize(width: w, height: h), normalized: normalizedValues)

            if points.count >= 2 {
                // Gradient fill
                Path { path in
                    path.move(to: CGPoint(x: points[0].x, y: h))
                    path.addLine(to: points[0])
                    addSmoothCurve(to: &path, points: points)
                    path.addLine(to: CGPoint(x: points.last!.x, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [latestColor.opacity(0.3), latestColor.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Line
                Path { path in
                    path.move(to: points[0])
                    addSmoothCurve(to: &path, points: points)
                }
                .stroke(latestColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: height)
    }

    private func points(in size: CGSize, normalized: [Double]) -> [CGPoint] {
        guard normalized.count >= 2 else { return [] }
        let step = size.width / CGFloat(normalized.count - 1)
        return normalized.enumerated().map { i, v in
            return CGPoint(x: CGFloat(i) * step, y: size.height * (1 - v))
        }
    }

    private func addSmoothCurve(to path: inout Path, points: [CGPoint]) {
        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]
            let midX = (prev.x + curr.x) / 2
            path.addCurve(
                to: curr,
                control1: CGPoint(x: midX, y: prev.y),
                control2: CGPoint(x: midX, y: curr.y)
            )
        }
    }
}
