import SwiftUI

struct NetworkSectionView: View {
    var metrics: NetworkMetrics
    var inHistory: [Double]
    var outHistory: [Double]
    var perInterfaceInHistory: [String: [Double]]
    var perInterfaceOutHistory: [String: [Double]]
    @State private var expanded = false

    var body: some View {
        MetricCardView(title: "Network", icon: "network") {
            VStack(alignment: .leading, spacing: 10) {
                // Active interface + WiFi
                HStack {
                    if !metrics.activeInterfaceName.isEmpty {
                        Label(metrics.activeInterfaceName, systemImage: "antenna.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !metrics.wifiSSID.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: wifiIcon)
                                .foregroundStyle(wifiColor)
                            Text(metrics.wifiSSID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Download
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text(formatRate(activeInRate))
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                        .monospacedDigit()
                        .frame(width: 80, alignment: .trailing)
                    SparklineView(values: inHistory, height: 28)
                }

                // Upload
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)
                    Text(formatRate(activeOutRate))
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                        .monospacedDigit()
                        .frame(width: 80, alignment: .trailing)
                    SparklineView(values: outHistory, height: 28)
                }

                // Expand/collapse toggle
                Divider().opacity(0.3)

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        expanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Network Details")
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
            // Local IP
            if !metrics.localIP.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "network")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Local IP:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(metrics.localIP)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            // WiFi details
            if !metrics.wifiSSID.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WiFi")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "wifi")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("SSID:")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(metrics.wifiSSID)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text("Signal:")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(metrics.wifiRSSI) dBm")
                                .font(.system(.caption2, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }

                        // Visual signal indicator
                        signalBars
                    }
                }
            }

            // Per-interface breakdown
            let activeInterfaces = metrics.interfaces.filter { iface in
                iface.bytesInPerSecond > 0 || iface.bytesOutPerSecond > 0
                    || iface.totalBytesIn > 0 || iface.totalBytesOut > 0
            }

            if !activeInterfaces.isEmpty {
                Divider().opacity(0.3)

                Text("Per-Interface")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(activeInterfaces, id: \.name) { iface in
                    interfaceRow(iface)
                }
            }
        }
    }

    // MARK: - Signal bars

    private var signalBars: some View {
        let strength = signalStrength
        return HStack(spacing: 1) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < strength ? wifiColor : Color.secondary.opacity(0.2))
                    .frame(width: 3, height: CGFloat(4 + i * 2))
            }
        }
    }

    private var signalStrength: Int {
        let rssi = metrics.wifiRSSI
        switch rssi {
        case _ where rssi >= -50: return 4
        case _ where rssi >= -60: return 3
        case _ where rssi >= -70: return 2
        case _ where rssi >= -80: return 1
        default: return 0
        }
    }

    // MARK: - Interface row

    private func interfaceRow(_ iface: InterfaceMetrics) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(iface.name)
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                if iface.name == metrics.activeInterfaceName {
                    Text("active")
                        .font(.system(size: 8))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Spacer()
                Text("Total: \(formatBytesCompact(iface.totalBytesIn + iface.totalBytesOut))")
                    .font(.system(.caption2, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }

            // Download sparkline + rate
            HStack(spacing: 6) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 8))
                    .foregroundStyle(.green)
                Text(formatRate(iface.bytesInPerSecond))
                    .font(.system(.caption2, design: .monospaced))
                    .monospacedDigit()
                    .frame(width: 70, alignment: .trailing)
                if let hist = perInterfaceInHistory[iface.name], !hist.isEmpty {
                    SparklineView(values: hist, height: 16, lineWidth: 1)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 18)

            // Upload sparkline + rate
            HStack(spacing: 6) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 8))
                    .foregroundStyle(.blue)
                Text(formatRate(iface.bytesOutPerSecond))
                    .font(.system(.caption2, design: .monospaced))
                    .monospacedDigit()
                    .frame(width: 70, alignment: .trailing)
                if let hist = perInterfaceOutHistory[iface.name], !hist.isEmpty {
                    SparklineView(values: hist, height: 16, lineWidth: 1)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 18)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Computed properties

    private var activeInterface: InterfaceMetrics? {
        metrics.interfaces.first { $0.name == metrics.activeInterfaceName }
    }

    private var activeInRate: Double {
        activeInterface?.bytesInPerSecond ?? 0
    }

    private var activeOutRate: Double {
        activeInterface?.bytesOutPerSecond ?? 0
    }

    private var wifiIcon: String {
        let rssi = metrics.wifiRSSI
        switch rssi {
        case _ where rssi >= -50: return "wifi"
        case _ where rssi >= -70: return "wifi"
        case _ where rssi >= -80: return "wifi.exclamationmark"
        default: return "wifi.slash"
        }
    }

    private var wifiColor: Color {
        let rssi = metrics.wifiRSSI
        switch rssi {
        case _ where rssi >= -50: return .green
        case _ where rssi >= -70: return .yellow
        default: return .red
        }
    }

    // MARK: - Formatting

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

    private func formatBytesCompact(_ bytes: UInt64) -> String {
        let d = Double(bytes)
        switch d {
        case 0..<1024:
            return String(format: "%.0f B", d)
        case 1024..<1_048_576:
            return String(format: "%.1f KB", d / 1024)
        case 1_048_576..<1_073_741_824:
            return String(format: "%.1f MB", d / 1_048_576)
        default:
            return String(format: "%.2f GB", d / 1_073_741_824)
        }
    }
}
