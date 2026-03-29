@preconcurrency import Foundation
@preconcurrency import IOKit

final class DiskMonitor: @unchecked Sendable {
    private struct IOState {
        var readBytes: UInt64
        var writeBytes: UInt64
        var timestamp: CFAbsoluteTime
    }

    private let lock = NSLock()
    private var _previousState: IOState?

    init() {}

    func getUsage() -> DiskMetrics {
        let volumes = getVolumes()
        let (readBPS, writeBPS) = getIORates()
        return DiskMetrics(volumes: volumes, readBytesPerSecond: readBPS, writeBytesPerSecond: writeBPS)
    }

    private func getVolumes() -> [VolumeInfo] {
        let fm = FileManager.default
        guard let urls = fm.mountedVolumeURLs(includingResourceValuesForKeys: [
            .volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ], options: [.skipHiddenVolumes]) else {
            return []
        }

        var result: [VolumeInfo] = []
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: [
                .volumeNameKey, .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey
            ]) else { continue }

            let name = values.volumeName ?? url.lastPathComponent
            let total = UInt64(values.volumeTotalCapacity ?? 0)
            let free: UInt64
            if let important = values.volumeAvailableCapacityForImportantUsage {
                free = UInt64(important)
            } else {
                free = UInt64(values.volumeAvailableCapacity ?? 0)
            }
            let used = total > free ? total - free : 0

            result.append(VolumeInfo(name: name, totalBytes: total, usedBytes: used, freeBytes: free))
        }

        return result
    }

    private func getIORates() -> (readBPS: Double, writeBPS: Double) {
        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0

        var iterator: io_iterator_t = 0
        let matchDict = IOServiceMatching("IOBlockStorageDriver")
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator)
        guard kr == KERN_SUCCESS else {
            return (0, 0)
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
                  let dict = props?.takeRetainedValue() as? [String: Any],
                  let stats = dict["Statistics"] as? [String: Any] else {
                continue
            }

            if let rb = stats["Bytes (Read)"] as? UInt64 {
                totalRead += rb
            }
            if let wb = stats["Bytes (Write)"] as? UInt64 {
                totalWrite += wb
            }
        }

        let now = CFAbsoluteTimeGetCurrent()
        lock.lock()
        let prev = _previousState
        _previousState = IOState(readBytes: totalRead, writeBytes: totalWrite, timestamp: now)
        lock.unlock()

        guard let prev = prev else {
            return (0, 0)
        }

        let dt = now - prev.timestamp
        guard dt > 0 else { return (0, 0) }

        let readDelta = totalRead >= prev.readBytes ? totalRead - prev.readBytes : 0
        let writeDelta = totalWrite >= prev.writeBytes ? totalWrite - prev.writeBytes : 0

        return (Double(readDelta) / dt, Double(writeDelta) / dt)
    }
}
