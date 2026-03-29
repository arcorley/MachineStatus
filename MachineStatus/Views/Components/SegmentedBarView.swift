import SwiftUI

struct BarSegment: Identifiable {
    let id = UUID()
    var label: String
    var value: Double
    var color: Color
}

struct SegmentedBarView: View {
    var segments: [BarSegment]
    var height: CGFloat = 16

    private var total: Double {
        segments.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(segments) { segment in
                        let fraction = total > 0 ? segment.value / total : 0
                        RoundedRectangle(cornerRadius: 3)
                            .fill(segment.color)
                            .frame(width: max(fraction * geo.size.width - 1, 0))
                    }
                }
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
            )

            // Legend
            HStack(spacing: 12) {
                ForEach(segments) { segment in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(segment.color)
                            .frame(width: 6, height: 6)
                        Text(segment.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
