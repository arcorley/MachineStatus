import SwiftUI

struct DiskSectionView: View {
    var metrics: DiskMetrics
    var readHistory: [Double]
    var writeHistory: [Double]
    @State private var expanded = false

    var body: some View {
        MetricCardView(title: "Disk", icon: "internaldrive") {
            VStack(alignment: .leading, spacing: 10) {
                // Throughput
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text("R: \(formatRate(metrics.readBytesPerSecond))")
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                        .monospacedDigit()
                        .frame(width: 90, alignment: .trailing)
                    SparklineView(values: readHistory, height: 24)
                }

                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.doc.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("W: \(formatRate(metrics.writeBytesPerSecond))")
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                        .monospacedDigit()
                        .frame(width: 90, alignment: .trailing)
                    SparklineView(values: writeHistory, height: 24)
                }

                // Volumes
                if !metrics.volumes.isEmpty {
                    Divider().opacity(0.3)

                    if expanded {
                        expandedContent
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        ForEach(Array(metrics.volumes.enumerated()), id: \.element.name) { _, volume in
                            volumeRow(volume)
                        }
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            expanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(metrics.volumes.count) volume\(metrics.volumes.count == 1 ? "" : "s")")
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
                }
            }
        }
    }

    // MARK: - Collapsed volume row

    private func volumeRow(_ volume: VolumeInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(volume.name)
                    .font(.caption.weight(.medium))
                Spacer()
                Text("\(formatBytes(volume.usedBytes)) / \(formatBytes(volume.totalBytes))")
                    .font(.system(.caption2, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                let fraction = volume.totalBytes > 0
                    ? Double(volume.usedBytes) / Double(volume.totalBytes)
                    : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorForDiskUsage(fraction))
                        .frame(width: geo.size.width * min(fraction, 1))
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Expanded content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Larger sparklines
            VStack(alignment: .leading, spacing: 6) {
                Text("Throughput History")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("Read")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                    Text("Write")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                SparklineView(values: readHistory, height: 40)
                SparklineView(values: writeHistory, height: 40)
            }

            Divider().opacity(0.3)

            // Per-volume detailed breakdown
            ForEach(Array(metrics.volumes.enumerated()), id: \.element.name) { _, volume in
                volumeDetailRow(volume)
            }
        }
    }

    private func volumeDetailRow(_ volume: VolumeInfo) -> some View {
        let fraction = volume.totalBytes > 0
            ? Double(volume.usedBytes) / Double(volume.totalBytes)
            : 0
        let percentage = fraction * 100

        return VStack(alignment: .leading, spacing: 6) {
            // Volume name
            HStack {
                Image(systemName: "externaldrive.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(volume.name)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(String(format: "%.1f%%", percentage))
                    .font(.system(.caption2, design: .monospaced).weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(colorForDiskUsage(fraction))
            }

            // Usage bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorForDiskUsage(fraction))
                        .frame(width: geo.size.width * min(fraction, 1))
                }
            }
            .frame(height: 10)

            // Detailed numbers
            HStack(spacing: 16) {
                detailLabel("Used", value: formatBytesPrecise(volume.usedBytes))
                detailLabel("Free", value: formatBytesPrecise(volume.freeBytes))
                detailLabel("Total", value: formatBytesPrecise(volume.totalBytes))
            }

            // File system hint based on volume name
            if volume.name == "Macintosh HD" || volume.name.contains("Data") {
                Text("APFS")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
    }

    private func detailLabel(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(.caption2, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Formatting

    private func colorForDiskUsage(_ fraction: Double) -> Color {
        switch fraction {
        case 0..<0.7: return .blue
        case 0.7..<0.9: return .yellow
        default: return .red
        }
    }

    private func formatRate(_ bytesPerSec: Double) -> String {
        switch bytesPerSec {
        case 0..<1024:
            return String(format: "%.0f B/s", bytesPerSec)
        case 1024..<1_048_576:
            return String(format: "%.1f KB/s", bytesPerSec / 1024)
        case 1_048_576..<1_073_741_824:
            return String(format: "%.1f MB/s", bytesPerSec / 1_048_576)
        default:
            return String(format: "%.2f GB/s", bytesPerSec / 1_073_741_824)
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1024 {
            return String(format: "%.1f TB", gb / 1024)
        }
        if gb >= 1 {
            return String(format: "%.0f GB", gb)
        }
        return String(format: "%.0f MB", Double(bytes) / 1_048_576)
    }

    private func formatBytesPrecise(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1024 {
            return String(format: "%.2f TB", gb / 1024)
        }
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 {
            return String(format: "%.1f MB", mb)
        }
        return String(format: "%.0f KB", Double(bytes) / 1024)
    }
}
