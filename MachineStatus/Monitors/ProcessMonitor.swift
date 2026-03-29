@preconcurrency import Darwin
import Foundation

final class ProcessMonitor: @unchecked Sendable {
    private struct Sample {
        var totalTime: UInt64
        var timestamp: UInt64
    }

    // Key: "pid-threadIndex"
    private typealias ThreadKey = String

    private let lock = NSLock()
    private var previousSamples: [pid_t: Sample] = [:]
    private var previousThreadSamples: [ThreadKey: Sample] = [:]
    private var timebaseRatio: Double

    init() {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        timebaseRatio = Double(info.numer) / Double(info.denom)
    }

    func getTopProcesses(count: Int = 10) -> [ProcessInfo] {
        let bufferSize = proc_listallpids(nil, 0)
        guard bufferSize > 0 else { return [] }

        var pids = [pid_t](repeating: 0, count: Int(bufferSize))
        let actualSize = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.stride * pids.count))
        guard actualSize > 0 else { return [] }

        let pidCount = Int(actualSize)
        let now = mach_absolute_time()

        lock.lock()
        let prev = previousSamples
        lock.unlock()

        var currentSamples: [pid_t: Sample] = [:]
        currentSamples.reserveCapacity(pidCount)

        var processes: [ProcessInfo] = []
        processes.reserveCapacity(pidCount)

        for i in 0..<pidCount {
            let pid = pids[i]
            guard pid > 0 else { continue }

            var taskInfo = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.size)
            let ret = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, size)
            guard ret == size else { continue }

            let totalTime = taskInfo.pti_total_user + taskInfo.pti_total_system
            let memBytes = UInt64(taskInfo.pti_resident_size)

            currentSamples[pid] = Sample(totalTime: totalTime, timestamp: now)

            var cpuPercent = 0.0
            if let prevSample = prev[pid] {
                let dtCPU = Double(totalTime - prevSample.totalTime)
                let dtWall = Double(now - prevSample.timestamp) * timebaseRatio
                if dtWall > 0 {
                    cpuPercent = (dtCPU / dtWall) * 100.0
                }
            }

            let name = getProcessName(pid: pid)

            processes.append(ProcessInfo(
                pid: pid,
                name: name,
                cpuUsage: cpuPercent,
                memoryBytes: memBytes
            ))
        }

        lock.lock()
        previousSamples = currentSamples
        lock.unlock()

        processes.sort { $0.cpuUsage > $1.cpuUsage }
        return Array(processes.prefix(count))
    }

    /// Get top threads across all processes, with per-thread CPU delta.
    /// Each thread at 100% ≈ one fully utilized core.
    func getTopThreads(count: Int = 20) -> [ThreadInfo] {
        let bufferSize = proc_listallpids(nil, 0)
        guard bufferSize > 0 else { return [] }

        var pids = [pid_t](repeating: 0, count: Int(bufferSize))
        let actualSize = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.stride * pids.count))
        guard actualSize > 0 else { return [] }

        let pidCount = Int(actualSize)
        let now = mach_absolute_time()

        lock.lock()
        let prevThreads = previousThreadSamples
        lock.unlock()

        var currentThreadSamples: [ThreadKey: Sample] = [:]
        var threads: [ThreadInfo] = []

        // Only scan the top processes by thread count / likely CPU users
        // to keep this fast — enumerate threads for first ~200 processes
        let pidsToScan = Array(pids.prefix(pidCount).filter { $0 > 0 }.prefix(300))

        for pid in pidsToScan {
            // Get thread list: array of uint64 thread IDs
            let threadIdSize = proc_pidinfo(pid, PROC_PIDLISTTHREADS, 0, nil, 0)
            guard threadIdSize > 0 else { continue }

            let threadCount = Int(threadIdSize) / MemoryLayout<UInt64>.stride
            guard threadCount > 0, threadCount < 2000 else { continue }

            var threadIds = [UInt64](repeating: 0, count: threadCount)
            let actual = proc_pidinfo(pid, PROC_PIDLISTTHREADS, 0, &threadIds,
                                      Int32(threadCount * MemoryLayout<UInt64>.stride))
            guard actual > 0 else { continue }
            let actualThreadCount = Int(actual) / MemoryLayout<UInt64>.stride

            let processName = getProcessName(pid: pid)

            for ti in 0..<actualThreadCount {
                let threadId = threadIds[ti]
                var tinfo = proc_threadinfo()
                let tinfoSize = Int32(MemoryLayout<proc_threadinfo>.stride)
                let tret = proc_pidinfo(pid, PROC_PIDTHREADINFO, threadId, &tinfo, tinfoSize)
                guard tret == tinfoSize else { continue }

                let totalTime = tinfo.pth_user_time + tinfo.pth_system_time
                let key = "\(pid)-\(ti)"

                currentThreadSamples[key] = Sample(totalTime: totalTime, timestamp: now)

                var cpuPercent = 0.0
                if let prevSample = prevThreads[key] {
                    let dtCPU = Double(totalTime &- prevSample.totalTime)
                    let dtWall = Double(now - prevSample.timestamp) * timebaseRatio
                    if dtWall > 0 {
                        cpuPercent = (dtCPU / dtWall) * 100.0
                        // Clamp to reasonable range (one thread can't exceed one core)
                        cpuPercent = min(cpuPercent, 100.0)
                    }
                }

                // Only include threads that are using some CPU
                guard cpuPercent > 0.1 else { continue }

                let threadName = withUnsafePointer(to: tinfo.pth_name) { ptr in
                    ptr.withMemoryRebound(to: CChar.self, capacity: 64) { buf in
                        String(cString: buf)
                    }
                }

                threads.append(ThreadInfo(
                    pid: pid,
                    processName: processName,
                    threadIndex: ti,
                    threadName: threadName.isEmpty ? "thread \(ti)" : threadName,
                    cpuUsage: cpuPercent,
                    priority: Int(tinfo.pth_curpri)
                ))
            }
        }

        lock.lock()
        previousThreadSamples = currentThreadSamples
        lock.unlock()

        threads.sort { $0.cpuUsage > $1.cpuUsage }
        return Array(threads.prefix(count))
    }

    private func getProcessName(pid: pid_t) -> String {
        let pathBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(MAXPATHLEN))
        defer { pathBuffer.deallocate() }

        let pathLen = proc_pidpath(pid, pathBuffer, UInt32(MAXPATHLEN))
        if pathLen > 0 {
            let fullPath = String(cString: pathBuffer)
            return (fullPath as NSString).lastPathComponent
        }

        let nameBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(MAXCOMLEN + 1))
        defer { nameBuffer.deallocate() }

        proc_name(pid, nameBuffer, UInt32(MAXCOMLEN + 1))
        let name = String(cString: nameBuffer)
        return name.isEmpty ? "pid:\(pid)" : name
    }
}
