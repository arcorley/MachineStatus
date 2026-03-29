@preconcurrency import Foundation
@preconcurrency import IOKit
import IOKit.ps

final class BatteryMonitor: Sendable {
    init() {}

    func getUsage() -> BatteryMetrics {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else {
            return BatteryMetrics()
        }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else {
            return BatteryMetrics()
        }

        let currentCap = dict["CurrentCapacity"] as? Int ?? 0
        let maxCap = dict["MaxCapacity"] as? Int ?? 0
        let designCap = dict["DesignCapacity"] as? Int ?? maxCap
        let isCharging = dict["IsCharging"] as? Bool ?? false
        let cycleCount = dict["CycleCount"] as? Int ?? 0
        let timeRemaining = dict["TimeRemaining"] as? Int ?? -1

        let level = maxCap > 0 ? Double(currentCap) / Double(maxCap) * 100.0 : 0
        let health = designCap > 0 ? Double(maxCap) / Double(designCap) * 100.0 : 0

        return BatteryMetrics(
            level: level,
            isCharging: isCharging,
            cycleCount: cycleCount,
            health: health,
            timeRemaining: timeRemaining,
            currentCapacity: currentCap,
            maxCapacity: maxCap
        )
    }
}
