@preconcurrency import Darwin
@preconcurrency import Foundation

final class CPUMonitor: @unchecked Sendable {
    private struct TickState {
        var perCPU: [(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)]
        var timestamp: CFAbsoluteTime
    }

    private let lock = NSLock()
    private var _previousState: TickState?

    init() {}

    func getUsage() -> CPUMetrics {
        let currentTicks = readTicks()
        let currentTime = CFAbsoluteTimeGetCurrent()

        lock.lock()
        let previous = _previousState
        _previousState = TickState(perCPU: currentTicks, timestamp: currentTime)
        lock.unlock()

        var perCoreUsage: [Double] = []
        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0

        if let prev = previous {
            for i in 0..<min(prev.perCPU.count, currentTicks.count) {
                let dUser = currentTicks[i].user &- prev.perCPU[i].user
                let dSystem = currentTicks[i].system &- prev.perCPU[i].system
                let dIdle = currentTicks[i].idle &- prev.perCPU[i].idle
                let dNice = currentTicks[i].nice &- prev.perCPU[i].nice
                let total = dUser + dSystem + dIdle + dNice
                if total > 0 {
                    let usage = Double(dUser + dSystem + dNice) / Double(total) * 100.0
                    perCoreUsage.append(usage)
                } else {
                    perCoreUsage.append(0)
                }
                totalUser += dUser + dNice
                totalSystem += dSystem
                totalIdle += dIdle
            }
        } else {
            for tick in currentTicks {
                let total = tick.user + tick.system + tick.idle + tick.nice
                if total > 0 {
                    let usage = Double(tick.user + tick.system + tick.nice) / Double(total) * 100.0
                    perCoreUsage.append(usage)
                } else {
                    perCoreUsage.append(0)
                }
                totalUser += tick.user + tick.nice
                totalSystem += tick.system
                totalIdle += tick.idle
            }
        }

        let grandTotal = totalUser + totalSystem + totalIdle
        let overallUsage = grandTotal > 0 ? Double(totalUser + totalSystem) / Double(grandTotal) * 100.0 : 0
        let userPct = grandTotal > 0 ? Double(totalUser) / Double(grandTotal) * 100.0 : 0
        let systemPct = grandTotal > 0 ? Double(totalSystem) / Double(grandTotal) * 100.0 : 0
        let idlePct = grandTotal > 0 ? Double(totalIdle) / Double(grandTotal) * 100.0 : 0

        var loadAvg = [Double](repeating: 0, count: 3)
        getloadavg(&loadAvg, 3)

        let coreCount = sysctlInt("hw.ncpu")
        let physicalCoreCount = sysctlInt("hw.physicalcpu")
        let pCores = sysctlInt("hw.perflevel0.logicalcpu")
        let eCores = sysctlInt("hw.perflevel1.logicalcpu")

        return CPUMetrics(
            overallUsage: overallUsage,
            perCoreUsage: perCoreUsage,
            userUsage: userPct,
            systemUsage: systemPct,
            idleUsage: idlePct,
            loadAverage1: loadAvg[0],
            loadAverage5: loadAvg[1],
            loadAverage15: loadAvg[2],
            coreCount: coreCount,
            physicalCoreCount: physicalCoreCount,
            performanceCores: pCores,
            efficiencyCores: eCores
        )
    }

    private func readTicks() -> [(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)] {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return []
        }

        var ticks: [(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)] = []
        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = UInt64(info[offset + Int(CPU_STATE_USER)])
            let system = UInt64(info[offset + Int(CPU_STATE_SYSTEM)])
            let idle = UInt64(info[offset + Int(CPU_STATE_IDLE)])
            let nice = UInt64(info[offset + Int(CPU_STATE_NICE)])
            ticks.append((user: user, system: system, idle: idle, nice: nice))
        }

        let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)

        return ticks
    }

    private func sysctlInt(_ name: String) -> Int {
        var value: Int = 0
        var size = MemoryLayout<Int>.size
        if sysctlbyname(name, &value, &size, nil, 0) == 0 {
            return value
        }
        return 0
    }
}
