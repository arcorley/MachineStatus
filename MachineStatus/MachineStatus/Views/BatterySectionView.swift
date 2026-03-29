import SwiftUI

struct BatterySectionView: View {
    var metrics: BatteryMetrics

    private var batteryIcon: String {
        if metrics.isCharging {
            return "battery.100percent.bolt"
        }
        switch metrics.level {
        case 75...: return "battery.100percent"
        case 50..<75: return "battery.75percent"
        case 25..<50: return "battery.50percent"
        default: return "battery.25percent"
        }
    }

    private var batteryColor: Color {
        if metrics.isCharging { return .green }
        switch metrics.level {
        case 20...: return .green
        case 10..<20: return .yellow
        default: return .red
        }
    }

    private var timeRemainingText: String {
        guard metrics.timeRemaining > 0 else { return "Calculating..." }
        let hours = metrics.timeRemaining / 60
        let minutes = metrics.timeRemaining % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var body: some View {
        MetricCardView(title: "Battery", icon: "battery.100percent") {
            if metrics.currentCapacity == 0 && metrics.maxCapacity == 0 && metrics.level == 0 {
                Text("No battery detected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    // Main battery display
                    HStack(spacing: 12) {
                        Image(systemName: batteryIcon)
                            .font(.system(size: 32))
                            .foregroundStyle(batteryColor)
                            .symbolRenderingMode(.hierarchical)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(metrics.level))%")
                                    .font(.system(.title2, design: .rounded).weight(.bold))
                                    .monospacedDigit()
                                if metrics.isCharging {
                                    Text("Charging")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                            Text(timeRemainingText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider().opacity(0.3)

                    // Details grid
                    HStack(spacing: 16) {
                        detailItem("Health", value: String(format: "%.0f%%", metrics.health))
                        detailItem("Cycles", value: "\(metrics.cycleCount)")
                        detailItem("Capacity", value: "\(metrics.currentCapacity) / \(metrics.maxCapacity) mAh")
                    }
                }
            }
        }
    }

    private func detailItem(_ label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}
