import SwiftUI

struct ProcessListView: View {
    var processes: [ProcessInfo]
    var maxCount: Int = 8

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Process")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("CPU")
                    .frame(width: 70, alignment: .trailing)
                Text("Memory")
                    .frame(width: 70, alignment: .trailing)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.bottom, 6)

            Divider().opacity(0.3)

            ForEach(Array(processes.prefix(maxCount).enumerated()), id: \.element.pid) { index, process in
                HStack(spacing: 8) {
                    Text(process.name)
                        .font(.system(.caption, design: .default))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // CPU bar + text
                    HStack(spacing: 4) {
                        GeometryReader { geo in
                            let fraction = min(process.cpuUsage / 100.0, 1.0)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorForCPU(process.cpuUsage))
                                .frame(width: geo.size.width * fraction)
                                .frame(height: geo.size.height, alignment: .leading)
                        }
                        .frame(width: 30, height: 6)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 2))

                        Text(formatCPU(process.cpuUsage))
                            .font(.system(.caption2, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 70, alignment: .trailing)

                    Text(formatBytes(process.memoryBytes))
                        .font(.system(.caption2, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(index % 2 == 0 ? Color.clear : Color.white.opacity(0.02))
            }
        }
    }

    private func colorForCPU(_ usage: Double) -> Color {
        switch usage {
        case 0..<30: return .green
        case 30..<70: return .yellow
        default: return .red
        }
    }

    private func formatCPU(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%3.0f%%", value)
        }
        return String(format: "%4.1f%%", value)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }
}
