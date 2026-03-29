@preconcurrency import Darwin
import Foundation

final class MemoryMonitor: Sendable {
    init() {}

    func getUsage() -> MemoryMetrics {
        let pageSize = UInt64(vm_kernel_page_size)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MemoryMetrics()
        }

        let total = totalMemory()
        let free = UInt64(stats.free_count) * pageSize
        let active = UInt64(stats.active_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let purgeable = UInt64(stats.purgeable_count) * pageSize
        let used = active + wired + compressed

        let (swapUsed, swapTotal) = swapUsage()

        let pressure: MemoryPressureLevel
        let usedFraction = total > 0 ? Double(used) / Double(total) : 0
        if usedFraction > 0.9 {
            pressure = .critical
        } else if usedFraction > 0.75 {
            pressure = .warn
        } else {
            pressure = .normal
        }

        return MemoryMetrics(
            total: total,
            used: used,
            free: free,
            active: active,
            inactive: inactive,
            wired: wired,
            compressed: compressed,
            purgeable: purgeable,
            swapUsed: swapUsed,
            swapTotal: swapTotal,
            pressureLevel: pressure
        )
    }

    private func totalMemory() -> UInt64 {
        var memsize: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &memsize, &size, nil, 0)
        return memsize
    }

    private func swapUsage() -> (used: UInt64, total: UInt64) {
        var swapUsage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swapUsage, &size, nil, 0) == 0 {
            return (used: UInt64(swapUsage.xsu_used), total: UInt64(swapUsage.xsu_total))
        }
        return (0, 0)
    }
}
