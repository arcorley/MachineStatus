@preconcurrency import Foundation
@preconcurrency import IOKit
import Metal

final class GPUMonitor: @unchecked Sendable {
    private struct GPUSample {
        var accumulatedGPUTime: UInt64  // nanoseconds
        var timestamp: UInt64           // mach_absolute_time
    }

    private let lock = NSLock()
    private var previousSamples: [Int32: GPUSample] = [:]  // keyed by pid
    private var timebaseRatio: Double

    init() {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        timebaseRatio = Double(info.numer) / Double(info.denom)
    }

    func getUsage() -> GPUMetrics {
        let gpuName = getGPUName()
        let (utilization, memUsed, memTotal, isUnified) = getIOKitGPUStats()

        return GPUMetrics(
            utilization: utilization,
            name: gpuName,
            memoryUsed: memUsed,
            memoryTotal: memTotal,
            isUnifiedMemory: isUnified
        )
    }

    func getTopGPUProcesses(count: Int = 10) -> [GPUProcessInfo] {
        var iterator: io_iterator_t = 0
        let matchDict = IOServiceMatching("IOAccelerator")
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator)
        guard kr == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        let accel = IOIteratorNext(iterator)
        guard accel != 0 else { return [] }
        defer { IOObjectRelease(accel) }

        var childIterator: io_iterator_t = 0
        guard IORegistryEntryGetChildIterator(accel, kIOServicePlane, &childIterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(childIterator) }

        let now = mach_absolute_time()

        lock.lock()
        let prev = previousSamples
        lock.unlock()

        // Aggregate GPU time per PID (a process can have multiple clients)
        struct Aggregated {
            var name: String
            var totalGPUTime: UInt64 = 0
            var commandQueues: Int = 0
        }
        var perPID: [Int32: Aggregated] = [:]

        var child = IOIteratorNext(childIterator)
        while child != 0 {
            defer {
                IOObjectRelease(child)
                child = IOIteratorNext(childIterator)
            }

            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(child, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = props?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            let creator = dict["IOUserClientCreator"] as? String ?? ""
            guard creator.hasPrefix("pid ") else { continue }

            let afterPid = creator.dropFirst(4)
            let parts = afterPid.split(separator: ",", maxSplits: 1)
            guard let pid = Int32(parts.first ?? "") else { continue }
            let name = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : "pid:\(pid)"

            // Sum accumulatedGPUTime across all AppUsage entries
            var clientGPUTime: UInt64 = 0
            if let appUsage = dict["AppUsage"] as? [[String: Any]] {
                for entry in appUsage {
                    if let t = entry["accumulatedGPUTime"] as? UInt64 {
                        clientGPUTime += t
                    } else if let t = entry["accumulatedGPUTime"] as? Int {
                        clientGPUTime += UInt64(t)
                    }
                }
            }

            let queues = dict["CommandQueueCount"] as? Int ?? 0

            var agg = perPID[pid] ?? Aggregated(name: name)
            agg.totalGPUTime += clientGPUTime
            agg.commandQueues += queues
            perPID[pid] = agg
        }

        // Compute deltas
        var currentSamples: [Int32: GPUSample] = [:]
        var results: [GPUProcessInfo] = []

        for (pid, agg) in perPID {
            currentSamples[pid] = GPUSample(accumulatedGPUTime: agg.totalGPUTime, timestamp: now)

            var gpuPercent = 0.0
            if let prevSample = prev[pid] {
                let dtGPU = Double(agg.totalGPUTime &- prevSample.accumulatedGPUTime)
                let dtWall = Double(now - prevSample.timestamp) * timebaseRatio
                if dtWall > 0 {
                    gpuPercent = (dtGPU / dtWall) * 100.0
                }
            }

            // Only include processes with some GPU activity
            if gpuPercent > 0.01 || agg.commandQueues > 0 {
                results.append(GPUProcessInfo(
                    pid: pid,
                    name: name(for: pid, fallback: agg.name),
                    gpuUsage: gpuPercent,
                    commandQueues: agg.commandQueues
                ))
            }
        }

        lock.lock()
        previousSamples = currentSamples
        lock.unlock()

        results.sort { $0.gpuUsage > $1.gpuUsage }
        return Array(results.prefix(count))
    }

    // MARK: - Private

    private func name(for pid: Int32, fallback: String) -> String {
        // IOKit truncates names; try to get full name via proc_pidpath
        let buf = UnsafeMutablePointer<CChar>.allocate(capacity: Int(MAXPATHLEN))
        defer { buf.deallocate() }
        let len = proc_pidpath(pid, buf, UInt32(MAXPATHLEN))
        if len > 0 {
            return (String(cString: buf) as NSString).lastPathComponent
        }
        return fallback
    }

    private func getGPUName() -> String {
        if let device = MTLCreateSystemDefaultDevice() {
            return device.name
        }
        return "Unknown GPU"
    }

    private func getIOKitGPUStats() -> (utilization: Double, memUsed: UInt64, memTotal: UInt64, isUnified: Bool) {
        var iterator: io_iterator_t = 0
        let matchDict = IOServiceMatching("IOAccelerator")
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator)
        guard kr == KERN_SUCCESS else {
            return (0, 0, 0, true)
        }
        defer { IOObjectRelease(iterator) }

        var entry: io_object_t = IOIteratorNext(iterator)
        while entry != 0 {
            defer {
                IOObjectRelease(entry)
                entry = IOIteratorNext(iterator)
            }

            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = props?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            if let perfStats = dict["PerformanceStatistics"] as? [String: Any] {
                var utilization: Double = 0
                var memUsed: UInt64 = 0
                var memTotal: UInt64 = 0

                if let gpuUtil = perfStats["GPU Activity(%)"] as? Double {
                    utilization = gpuUtil
                } else if let gpuUtil = perfStats["Device Utilization %"] as? Int {
                    utilization = Double(gpuUtil)
                }

                if let used = perfStats["VRAM Used"] as? UInt64 {
                    memUsed = used
                } else if let used = perfStats["Alloc system memory"] as? UInt64 {
                    memUsed = used
                } else if let used = perfStats["In use system memory"] as? UInt64 {
                    memUsed = used
                }

                if let total = perfStats["VRAM Total"] as? UInt64 {
                    memTotal = total
                }

                let isUnified = memTotal == 0
                if isUnified {
                    var memsize: UInt64 = 0
                    var size = MemoryLayout<UInt64>.size
                    sysctlbyname("hw.memsize", &memsize, &size, nil, 0)
                    memTotal = memsize
                }

                return (utilization, memUsed, memTotal, isUnified)
            }
        }

        return (0, 0, 0, true)
    }
}
