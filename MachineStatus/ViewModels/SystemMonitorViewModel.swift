import Foundation
import SwiftUI

@MainActor
@Observable
final class SystemMonitorViewModel {
    // MARK: - Metrics

    var cpuMetrics = CPUMetrics()
    var memoryMetrics = MemoryMetrics()
    var diskMetrics = DiskMetrics()
    var networkMetrics = NetworkMetrics()
    var gpuMetrics = GPUMetrics()
    var topProcesses: [ProcessInfo] = []
    var topThreads: [ThreadInfo] = []
    var topProcessesByMemory: [ProcessInfo] = []
    var topGPUProcesses: [GPUProcessInfo] = []

    // MARK: - History (rolling 60 values for sparklines)

    var cpuHistory: [Double] = []
    var perCoreHistory: [[Double]] = []  // [coreIndex][sampleIndex]
    var networkInHistory: [Double] = []
    var networkOutHistory: [Double] = []
    var diskReadHistory: [Double] = []
    var diskWriteHistory: [Double] = []
    var gpuHistory: [Double] = []
    var memoryUsageHistory: [Double] = []
    var perInterfaceInHistory: [String: [Double]] = [:]
    var perInterfaceOutHistory: [String: [Double]] = [:]

    // MARK: - Monitors

    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let diskMonitor = DiskMonitor()
    private let networkMonitor = NetworkMonitor()
    private let gpuMonitor = GPUMonitor()
    private let processMonitor = ProcessMonitor()

    private var timer: Timer?

    private static let maxHistoryCount = 60

    // MARK: - Lifecycle

    func start() {
        // Fire immediately, then every 2 seconds
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Polling

    private func tick() {
        let cpuMon = cpuMonitor
        let memMon = memoryMonitor
        let diskMon = diskMonitor
        let netMon = networkMonitor
        let gpuMon = gpuMonitor
        let procMon = processMonitor

        Task.detached {
            let cpu = cpuMon.getUsage()
            let memory = memMon.getUsage()
            let disk = diskMon.getUsage()
            let network = netMon.getUsage()
            let gpu = gpuMon.getUsage()
            let gpuProcesses = gpuMon.getTopGPUProcesses(count: 10)
            let processes = procMon.getTopProcesses(count: 10)
            let threads = procMon.getTopThreads(count: 20)

            await MainActor.run { [cpu, memory, disk, network, gpu, gpuProcesses, processes, threads] in
                self.cpuMetrics = cpu
                self.memoryMetrics = memory
                self.diskMetrics = disk
                self.networkMetrics = network
                self.gpuMetrics = gpu
                self.topGPUProcesses = gpuProcesses
                self.topProcesses = processes
                self.topThreads = threads
                self.topProcessesByMemory = processes.sorted { $0.memoryBytes > $1.memoryBytes }.prefix(8).map { $0 }

                self.appendHistory(&self.cpuHistory, value: cpu.overallUsage)

                // Per-core history
                if self.perCoreHistory.count != cpu.perCoreUsage.count {
                    self.perCoreHistory = Array(repeating: [], count: cpu.perCoreUsage.count)
                }
                for (i, usage) in cpu.perCoreUsage.enumerated() {
                    self.appendHistory(&self.perCoreHistory[i], value: usage)
                }

                self.appendHistory(&self.gpuHistory, value: gpu.utilization)

                // Sum across all interfaces for network history
                let totalIn = network.interfaces.reduce(0.0) { $0 + $1.bytesInPerSecond }
                let totalOut = network.interfaces.reduce(0.0) { $0 + $1.bytesOutPerSecond }
                self.appendHistory(&self.networkInHistory, value: totalIn)
                self.appendHistory(&self.networkOutHistory, value: totalOut)

                // Per-interface history
                for iface in network.interfaces {
                    if self.perInterfaceInHistory[iface.name] == nil {
                        self.perInterfaceInHistory[iface.name] = []
                    }
                    if self.perInterfaceOutHistory[iface.name] == nil {
                        self.perInterfaceOutHistory[iface.name] = []
                    }
                    self.appendHistory(&self.perInterfaceInHistory[iface.name]!, value: iface.bytesInPerSecond)
                    self.appendHistory(&self.perInterfaceOutHistory[iface.name]!, value: iface.bytesOutPerSecond)
                }

                self.appendHistory(&self.diskReadHistory, value: disk.readBytesPerSecond)
                self.appendHistory(&self.diskWriteHistory, value: disk.writeBytesPerSecond)

                if memory.total > 0 {
                    self.appendHistory(&self.memoryUsageHistory, value: Double(memory.used) / Double(memory.total) * 100)
                }
            }
        }
    }

    private func appendHistory(_ array: inout [Double], value: Double) {
        array.append(value)
        if array.count > Self.maxHistoryCount {
            array.removeFirst(array.count - Self.maxHistoryCount)
        }
    }
}
