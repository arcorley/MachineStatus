import SwiftUI

struct MemorySectionView: View {
    var metrics: MemoryMetrics
    var usageHistory: [Double]
    var topProcessesByMemory: [ProcessInfo]
    @State private var expanded = false

    private var usedGB: Double { Double(metrics.used) / 1_073_741_824 }
    private var totalGB: Double { Double(metrics.total) / 1_073_741_824 }

    private var pressureColor: Color {
        switch metrics.pressureLevel {
        case .normal: return .green
        case .warn: return .yellow
        case .critical: return .red
        }
    }

    var body: some View {
        MetricCardView(title: "Memory", icon: "memorychip") {
            VStack(alignment: .leading, spacing: 10) {
                // Usage headline
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.1f", usedGB))
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    Text("/ \(String(format: "%.0f", totalGB)) GB")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Pressure indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(pressureColor)
                            .frame(width: 8, height: 8)
                        Text("Pressure: \(metrics.pressureLevel.rawValue.capitalized)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Segmented bar
                SegmentedBarView(segments: memorySegments)

                // Details
                HStack(spacing: 16) {
                    detailItem("Swap", value: formatBytes(metrics.swapUsed))
                    detailItem("Compressed", value: formatBytes(metrics.compressed))
                    detailItem("Wired", value: formatBytes(metrics.wired))
                }

                // Expand toggle
                Divider().opacity(0.3)

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        expanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Memory Details")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(expanded ? "Collapse" : "Details")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                    }
                }
                .buttonStyle(.plain)

                if expanded {
                    expandedDetailView
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: - Expanded Detail View

    private var expandedDetailView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Memory usage sparkline
            VStack(alignment: .leading, spacing: 4) {
                Text("Usage Over Time")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                SparklineView(values: usageHistory, height: 36)
            }

            Divider().opacity(0.3)

            // Complete breakdown table
            VStack(alignment: .leading, spacing: 4) {
                Text("Breakdown")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                breakdownRow(label: "Active", bytes: metrics.active, color: .green)
                breakdownRow(label: "Inactive", bytes: metrics.inactive, color: .purple)
                breakdownRow(label: "Wired", bytes: metrics.wired, color: .orange)
                breakdownRow(label: "Compressed", bytes: metrics.compressed, color: .yellow)
                breakdownRow(label: "Purgeable", bytes: metrics.purgeable, color: .cyan)
                breakdownRow(label: "Free", bytes: metrics.free, color: .gray)
            }

            // Swap details
            if metrics.swapTotal > 0 || metrics.swapUsed > 0 {
                Divider().opacity(0.3)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Swap")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(formatBytes(metrics.swapUsed)) / \(formatBytes(metrics.swapTotal))")
                            .font(.system(.caption2, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { geo in
                        let fraction = metrics.swapTotal > 0
                            ? Double(metrics.swapUsed) / Double(metrics.swapTotal)
                            : 0
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.1))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.orange)
                                .frame(width: geo.size.width * min(max(fraction, 0), 1))
                        }
                    }
                    .frame(height: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }

            // Top by Memory
            if !topProcessesByMemory.isEmpty {
                Divider().opacity(0.3)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "memorychip")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Top by Memory")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    ForEach(Array(topProcessesByMemory.enumerated()), id: \.offset) { _, process in
                        processRow(process)
                    }
                }
            }
        }
    }

    // MARK: - Breakdown Row

    private func breakdownRow(label: String, bytes: UInt64, color: Color) -> some View {
        let percentage = metrics.total > 0
            ? Double(bytes) / Double(metrics.total) * 100
            : 0
        let fraction = metrics.total > 0
            ? Double(bytes) / Double(metrics.total)
            : 0

        return HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.system(.caption2, design: .monospaced).weight(.medium))
                .frame(width: 72, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * min(max(fraction, 0), 1))
                }
            }
            .frame(height: 8)

            Text(formatBytes(bytes))
                .font(.system(.caption2, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)

            Text(String(format: "%4.1f%%", percentage))
                .font(.system(.caption2, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .frame(height: 18)
    }

    // MARK: - Process Row

    private func processRow(_ process: ProcessInfo) -> some View {
        let maxMem = topProcessesByMemory.first?.memoryBytes ?? 1
        let fraction = maxMem > 0 ? Double(process.memoryBytes) / Double(maxMem) : 0

        return HStack(spacing: 8) {
            Text(process.name)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blue)
                        .frame(width: geo.size.width * min(max(fraction, 0), 1))
                }
            }
            .frame(width: 50, height: 8)

            Text(formatBytes(process.memoryBytes))
                .font(.system(.caption2, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)
        }
        .frame(height: 16)
    }

    // MARK: - Helpers

    private var memorySegments: [BarSegment] {
        [
            BarSegment(label: "Active", value: Double(metrics.active), color: .green),
            BarSegment(label: "Wired", value: Double(metrics.wired), color: .orange),
            BarSegment(label: "Compressed", value: Double(metrics.compressed), color: .yellow),
            BarSegment(label: "Free", value: Double(metrics.free), color: .gray.opacity(0.3)),
        ]
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

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
}
