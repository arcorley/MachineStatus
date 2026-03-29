import SwiftUI

struct GPUSectionView: View {
    var metrics: GPUMetrics
    var history: [Double]
    var gpuProcesses: [GPUProcessInfo]
    @State private var expanded = false

    var body: some View {
        MetricCardView(title: "GPU", icon: "gpu") {
            VStack(spacing: 10) {
                HStack(spacing: 16) {
                    GaugeView(
                        value: metrics.utilization / 100,
                        label: "Utilization",
                        icon: "gpu",
                        size: 90
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        if !metrics.name.isEmpty {
                            Text(metrics.name)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                        }

                        SparklineView(values: history, height: 30)

                        if metrics.memoryTotal > 0 {
                            HStack(spacing: 4) {
                                Text("VRAM:")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(formatBytes(metrics.memoryUsed)) / \(formatBytes(metrics.memoryTotal))")
                                    .font(.system(.caption2, design: .monospaced))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if metrics.isUnifiedMemory {
                            Text("Unified Memory")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Expand/collapse toggle
                Divider().opacity(0.3)

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        expanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("GPU Details")
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
                    detailView
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: - Expanded detail view

    private var detailView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Larger sparkline
            VStack(alignment: .leading, spacing: 4) {
                Text("Utilization History")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                SparklineView(values: history, height: 50)
                HStack {
                    Text(String(format: "%.1f%%", metrics.utilization))
                        .font(.system(.caption2, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let maxVal = history.max() {
                        Text(String(format: "peak %.1f%%", maxVal))
                            .font(.system(.caption2, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // VRAM usage bar
            if metrics.memoryTotal > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("VRAM Usage")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(formatBytes(metrics.memoryUsed)) / \(formatBytes(metrics.memoryTotal))")
                            .font(.system(.caption2, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { geo in
                        let fraction = metrics.memoryTotal > 0
                            ? min(Double(metrics.memoryUsed) / Double(metrics.memoryTotal), 1.0)
                            : 0
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.1))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(vramColor(fraction))
                                .frame(width: geo.size.width * fraction)
                        }
                    }
                    .frame(height: 12)

                    HStack {
                        Text(String(format: "%.1f%% used", metrics.memoryTotal > 0
                            ? Double(metrics.memoryUsed) / Double(metrics.memoryTotal) * 100
                            : 0))
                            .font(.system(.caption2, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("\(formatBytes(metrics.memoryTotal - metrics.memoryUsed)) free")
                            .font(.system(.caption2, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Memory type indicator
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: metrics.isUnifiedMemory ? "memorychip" : "rectangle.split.2x2")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Memory Type:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(metrics.isUnifiedMemory ? "Unified" : "Discrete")
                        .font(.system(.caption2, design: .monospaced).weight(.medium))
                        .foregroundStyle(metrics.isUnifiedMemory ? .blue : .purple)
                }
            }

            // GPU name
            if !metrics.name.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "gpu")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Device:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(metrics.name)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Per-process GPU usage
            if !gpuProcesses.isEmpty {
                Divider().opacity(0.3)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("GPU Usage by Process")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                // Header
                HStack {
                    Text("Process")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("GPU")
                        .frame(width: 60, alignment: .trailing)
                    Text("Queues")
                        .frame(width: 44, alignment: .trailing)
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)

                ForEach(gpuProcesses) { proc in
                    gpuProcessRow(proc)
                }
            }
        }
    }

    private func gpuProcessRow(_ proc: GPUProcessInfo) -> some View {
        let clamped = min(max(proc.gpuUsage / 100, 0), 1)

        return HStack(spacing: 6) {
            Text(proc.name)
                .font(.system(.caption2, design: .default))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.1))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(gpuUsageColor(clamped))
                            .frame(width: geo.size.width * clamped)
                    }
                }
                .frame(width: 28, height: 6)

                Text(String(format: "%4.1f%%", proc.gpuUsage))
                    .font(.system(.caption2, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60, alignment: .trailing)

            Text("\(proc.commandQueues)")
                .font(.system(.caption2, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .frame(width: 44, alignment: .trailing)
        }
        .frame(height: 18)
    }

    private func gpuUsageColor(_ value: Double) -> Color {
        switch value {
        case 0..<0.3: return .green
        case 0.3..<0.7: return .yellow
        default: return .red
        }
    }

    // MARK: - Helpers

    private func vramColor(_ fraction: Double) -> Color {
        switch fraction {
        case 0..<0.6: return .green
        case 0.6..<0.85: return .yellow
        default: return .red
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        return String(format: "%.0f MB", Double(bytes) / 1_048_576)
    }
}
