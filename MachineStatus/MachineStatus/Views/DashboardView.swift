import SwiftUI

struct DashboardView: View {
    @Environment(SystemMonitorViewModel.self) private var viewModel
    @State private var processesLive = true
    @State private var frozenProcesses: [ProcessInfo] = []

    private let topColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private let middleColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Top row: CPU, Memory, GPU
                LazyVGrid(columns: topColumns, spacing: 12) {
                    CPUSectionView(
                        metrics: viewModel.cpuMetrics,
                        history: viewModel.cpuHistory,
                        perCoreHistory: viewModel.perCoreHistory,
                        topThreads: viewModel.topThreads
                    )

                    MemorySectionView(
                        metrics: viewModel.memoryMetrics,
                        usageHistory: viewModel.memoryUsageHistory,
                        topProcessesByMemory: viewModel.topProcessesByMemory
                    )

                    GPUSectionView(
                        metrics: viewModel.gpuMetrics,
                        history: viewModel.gpuHistory,
                        gpuProcesses: viewModel.topGPUProcesses
                    )
                }

                // Middle row: Network, Disk
                LazyVGrid(columns: middleColumns, spacing: 12) {
                    NetworkSectionView(
                        metrics: viewModel.networkMetrics,
                        inHistory: viewModel.networkInHistory,
                        outHistory: viewModel.networkOutHistory,
                        perInterfaceInHistory: viewModel.perInterfaceInHistory,
                        perInterfaceOutHistory: viewModel.perInterfaceOutHistory
                    )

                    DiskSectionView(
                        metrics: viewModel.diskMetrics,
                        readHistory: viewModel.diskReadHistory,
                        writeHistory: viewModel.diskWriteHistory
                    )
                }

                // Bottom: Top Processes
                MetricCardView(title: "Top Processes", icon: "list.number") {
                    HStack {
                        Spacer()
                        Toggle(isOn: $processesLive) {
                            Label(processesLive ? "Live" : "Paused", systemImage: processesLive ? "play.fill" : "pause.fill")
                                .font(.caption2)
                                .foregroundStyle(processesLive ? .green : .secondary)
                        }
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .onChange(of: processesLive) { _, isLive in
                            if !isLive {
                                frozenProcesses = viewModel.topProcesses
                            }
                        }
                    }
                    ProcessListView(processes: processesLive ? viewModel.topProcesses : frozenProcesses)
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
