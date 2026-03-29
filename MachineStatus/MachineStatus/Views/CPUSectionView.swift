import SwiftUI

struct CPUSectionView: View {
    var metrics: CPUMetrics
    var history: [Double]
    var perCoreHistory: [[Double]]
    var topThreads: [ThreadInfo]
    @State private var expanded = false

    var body: some View {
        MetricCardView(title: "CPU", icon: "cpu") {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    GaugeView(
                        value: metrics.overallUsage / 100,
                        label: "Overall",
                        icon: "cpu",
                        size: 100
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        SparklineView(values: history, height: 36)

                        HStack(spacing: 12) {
                            metricLabel("User", value: metrics.userUsage)
                            metricLabel("System", value: metrics.systemUsage)
                            metricLabel("Idle", value: metrics.idleUsage)
                        }

                        HStack(spacing: 4) {
                            Text("Load:")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.2f  %.2f  %.2f",
                                        metrics.loadAverage1,
                                        metrics.loadAverage5,
                                        metrics.loadAverage15))
                                .font(.system(.caption2, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // Per-core compact grid + expand toggle
                if !metrics.perCoreUsage.isEmpty {
                    Divider().opacity(0.3)

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            expanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            coreCountLabel
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
                        coreDetailView
                            .transition(.opacity.combined(with: .move(edge: .top)))

                        if !topThreads.isEmpty {
                            threadBreakdownView
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    } else {
                        coreGrid
                    }
                }
            }
        }
    }

    // MARK: - Core count label (P/E breakdown)

    private var coreCountLabel: some View {
        HStack(spacing: 6) {
            Text("\(metrics.perCoreUsage.count) cores")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            if metrics.performanceCores > 0 || metrics.efficiencyCores > 0 {
                Text("\(metrics.performanceCores)P + \(metrics.efficiencyCores)E")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Compact core grid

    private var coreGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: min(metrics.perCoreUsage.count, 8))
        return LazyVGrid(columns: columns, spacing: 3) {
            ForEach(Array(metrics.perCoreUsage.enumerated()), id: \.offset) { index, usage in
                VStack(spacing: 2) {
                    GeometryReader { geo in
                        let clamped = min(max(usage / 100, 0), 1)
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorForUsage(clamped))
                                .frame(height: geo.size.height * clamped)
                        }
                    }
                    .frame(height: 24)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 2))

                    Text("\(index)")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Expanded per-core detail

    private var coreDetailView: some View {
        let pCores = metrics.performanceCores
        let eCores = metrics.efficiencyCores
        let hasClusters = pCores > 0 || eCores > 0

        return VStack(alignment: .leading, spacing: 8) {
            if hasClusters {
                coreCluster(
                    label: "Performance",
                    tag: "P",
                    range: 0..<pCores,
                    color: .blue
                )

                coreCluster(
                    label: "Efficiency",
                    tag: "E",
                    range: pCores..<(pCores + eCores),
                    color: .teal
                )
            } else {
                coreCluster(
                    label: "All Cores",
                    tag: "",
                    range: 0..<metrics.perCoreUsage.count,
                    color: .blue
                )
            }
        }
    }

    private func coreCluster(label: String, tag: String, range: Range<Int>, color: Color) -> some View {
        let cores = Array(range).filter { $0 < metrics.perCoreUsage.count }
        let avgUsage = cores.isEmpty ? 0 : cores.map { metrics.perCoreUsage[$0] }.reduce(0, +) / Double(cores.count)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.caption.weight(.semibold))
                Text("avg \(String(format: "%.0f%%", avgUsage))")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ForEach(cores, id: \.self) { i in
                coreRow(
                    index: i,
                    label: tag.isEmpty ? "Core \(i)" : "\(tag)\(i - (tag == "E" ? metrics.performanceCores : 0))",
                    usage: metrics.perCoreUsage[i],
                    history: i < perCoreHistory.count ? perCoreHistory[i] : [],
                    accent: color
                )
            }
        }
    }

    private func coreRow(index: Int, label: String, usage: Double, history: [Double], accent: Color) -> some View {
        let clamped = min(max(usage / 100, 0), 1)

        return HStack(spacing: 8) {
            Text(label)
                .font(.system(.caption2, design: .monospaced).weight(.medium))
                .frame(width: 28, alignment: .leading)

            // Usage bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorForUsage(clamped))
                        .frame(width: geo.size.width * clamped)
                }
            }
            .frame(width: 60, height: 10)

            Text(String(format: "%5.1f%%", usage))
                .font(.system(.caption2, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)

            SparklineView(values: history, height: 16, lineWidth: 1)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 18)
    }

    // MARK: - Thread breakdown

    private var threadBreakdownView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().opacity(0.3)

            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Active Threads")
                    .font(.caption.weight(.semibold))
                Text("— each at 100% ≈ 1 busy core")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            // Group threads by process
            let grouped = Dictionary(grouping: topThreads, by: { $0.processName })
            let sortedGroups = grouped.sorted { a, b in
                a.value.reduce(0) { $0 + $1.cpuUsage } > b.value.reduce(0) { $0 + $1.cpuUsage }
            }

            ForEach(sortedGroups, id: \.key) { processName, threads in
                let totalCPU = threads.reduce(0) { $0 + $1.cpuUsage }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(processName)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                        Spacer()
                        Text(String(format: "%.0f%% total", totalCPU))
                            .font(.system(.caption2, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    ForEach(threads) { thread in
                        threadRow(thread)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func threadRow(_ thread: ThreadInfo) -> some View {
        let clamped = min(max(thread.cpuUsage / 100, 0), 1)

        return HStack(spacing: 6) {
            Text(thread.threadName)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorForUsage(clamped))
                        .frame(width: geo.size.width * clamped)
                }
            }
            .frame(width: 50, height: 8)

            Text(String(format: "%5.1f%%", thread.cpuUsage))
                .font(.system(.caption2, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
        .frame(height: 16)
        .padding(.leading, 12)
    }

    // MARK: - Helpers

    private func metricLabel(_ title: String, value: Double) -> some View {
        VStack(spacing: 1) {
            Text(String(format: "%.0f%%", value))
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .monospacedDigit()
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    private func colorForUsage(_ value: Double) -> Color {
        switch value {
        case 0..<0.6: return .green
        case 0.6..<0.85: return .yellow
        default: return .red
        }
    }
}
