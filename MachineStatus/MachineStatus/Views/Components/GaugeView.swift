import SwiftUI

struct GaugeView: View {
    var value: Double
    var label: String
    var icon: String
    var size: CGFloat = 120

    private var clampedValue: Double {
        min(max(value, 0), 1)
    }

    private var gaugeColor: Color {
        switch clampedValue {
        case 0..<0.6: return .green
        case 0.6..<0.85: return .yellow
        default: return .red
        }
    }

    private var percentText: String {
        "\(Int(clampedValue * 100))%"
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background track
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(
                        Color.secondary.opacity(0.2),
                        style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round)
                    )
                    .rotationEffect(.degrees(180))

                // Value arc
                Circle()
                    .trim(from: 0.15, to: 0.15 + 0.7 * clampedValue)
                    .stroke(
                        gaugeColor,
                        style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round)
                    )
                    .rotationEffect(.degrees(180))
                    .shadow(color: gaugeColor.opacity(0.4), radius: 4)

                // Center text
                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.system(size: size * 0.12))
                        .foregroundStyle(.secondary)
                    Text(percentText)
                        .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
            .frame(width: size, height: size)
            .animation(.easeInOut(duration: 0.5), value: clampedValue)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
