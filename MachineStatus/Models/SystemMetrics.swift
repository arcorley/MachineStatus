import Foundation

// MARK: - CPU Metrics

public struct CPUMetrics: Sendable {
    public var overallUsage: Double
    public var perCoreUsage: [Double]
    public var userUsage: Double
    public var systemUsage: Double
    public var idleUsage: Double
    public var loadAverage1: Double
    public var loadAverage5: Double
    public var loadAverage15: Double
    public var coreCount: Int
    public var physicalCoreCount: Int
    public var performanceCores: Int
    public var efficiencyCores: Int

    public init(
        overallUsage: Double = 0,
        perCoreUsage: [Double] = [],
        userUsage: Double = 0,
        systemUsage: Double = 0,
        idleUsage: Double = 0,
        loadAverage1: Double = 0,
        loadAverage5: Double = 0,
        loadAverage15: Double = 0,
        coreCount: Int = 0,
        physicalCoreCount: Int = 0,
        performanceCores: Int = 0,
        efficiencyCores: Int = 0
    ) {
        self.overallUsage = overallUsage
        self.perCoreUsage = perCoreUsage
        self.userUsage = userUsage
        self.systemUsage = systemUsage
        self.idleUsage = idleUsage
        self.loadAverage1 = loadAverage1
        self.loadAverage5 = loadAverage5
        self.loadAverage15 = loadAverage15
        self.coreCount = coreCount
        self.physicalCoreCount = physicalCoreCount
        self.performanceCores = performanceCores
        self.efficiencyCores = efficiencyCores
    }
}

// MARK: - Memory Metrics

public enum MemoryPressureLevel: String, Sendable {
    case normal
    case warn
    case critical
}

public struct MemoryMetrics: Sendable {
    public var total: UInt64
    public var used: UInt64
    public var free: UInt64
    public var active: UInt64
    public var inactive: UInt64
    public var wired: UInt64
    public var compressed: UInt64
    public var purgeable: UInt64
    public var swapUsed: UInt64
    public var swapTotal: UInt64
    public var pressureLevel: MemoryPressureLevel

    public init(
        total: UInt64 = 0,
        used: UInt64 = 0,
        free: UInt64 = 0,
        active: UInt64 = 0,
        inactive: UInt64 = 0,
        wired: UInt64 = 0,
        compressed: UInt64 = 0,
        purgeable: UInt64 = 0,
        swapUsed: UInt64 = 0,
        swapTotal: UInt64 = 0,
        pressureLevel: MemoryPressureLevel = .normal
    ) {
        self.total = total
        self.used = used
        self.free = free
        self.active = active
        self.inactive = inactive
        self.wired = wired
        self.compressed = compressed
        self.purgeable = purgeable
        self.swapUsed = swapUsed
        self.swapTotal = swapTotal
        self.pressureLevel = pressureLevel
    }
}

// MARK: - Disk Metrics

public struct VolumeInfo: Sendable {
    public var name: String
    public var totalBytes: UInt64
    public var usedBytes: UInt64
    public var freeBytes: UInt64

    public init(name: String = "", totalBytes: UInt64 = 0, usedBytes: UInt64 = 0, freeBytes: UInt64 = 0) {
        self.name = name
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.freeBytes = freeBytes
    }
}

public struct DiskMetrics: Sendable {
    public var volumes: [VolumeInfo]
    public var readBytesPerSecond: Double
    public var writeBytesPerSecond: Double

    public init(volumes: [VolumeInfo] = [], readBytesPerSecond: Double = 0, writeBytesPerSecond: Double = 0) {
        self.volumes = volumes
        self.readBytesPerSecond = readBytesPerSecond
        self.writeBytesPerSecond = writeBytesPerSecond
    }
}

// MARK: - Network Metrics

public struct InterfaceMetrics: Sendable {
    public var name: String
    public var bytesInPerSecond: Double
    public var bytesOutPerSecond: Double
    public var totalBytesIn: UInt64
    public var totalBytesOut: UInt64

    public init(
        name: String = "",
        bytesInPerSecond: Double = 0,
        bytesOutPerSecond: Double = 0,
        totalBytesIn: UInt64 = 0,
        totalBytesOut: UInt64 = 0
    ) {
        self.name = name
        self.bytesInPerSecond = bytesInPerSecond
        self.bytesOutPerSecond = bytesOutPerSecond
        self.totalBytesIn = totalBytesIn
        self.totalBytesOut = totalBytesOut
    }
}

public struct NetworkMetrics: Sendable {
    public var interfaces: [InterfaceMetrics]
    public var activeInterfaceName: String
    public var localIP: String
    public var wifiSSID: String
    public var wifiRSSI: Int

    public init(
        interfaces: [InterfaceMetrics] = [],
        activeInterfaceName: String = "",
        localIP: String = "",
        wifiSSID: String = "",
        wifiRSSI: Int = 0
    ) {
        self.interfaces = interfaces
        self.activeInterfaceName = activeInterfaceName
        self.localIP = localIP
        self.wifiSSID = wifiSSID
        self.wifiRSSI = wifiRSSI
    }
}

// MARK: - GPU Metrics

public struct GPUMetrics: Sendable {
    public var utilization: Double
    public var name: String
    public var memoryUsed: UInt64
    public var memoryTotal: UInt64
    public var isUnifiedMemory: Bool

    public init(
        utilization: Double = 0,
        name: String = "",
        memoryUsed: UInt64 = 0,
        memoryTotal: UInt64 = 0,
        isUnifiedMemory: Bool = false
    ) {
        self.utilization = utilization
        self.name = name
        self.memoryUsed = memoryUsed
        self.memoryTotal = memoryTotal
        self.isUnifiedMemory = isUnifiedMemory
    }
}

// MARK: - Battery Metrics

public struct BatteryMetrics: Sendable {
    public var level: Double
    public var isCharging: Bool
    public var cycleCount: Int
    public var health: Double
    public var timeRemaining: Int
    public var currentCapacity: Int
    public var maxCapacity: Int

    public init(
        level: Double = 0,
        isCharging: Bool = false,
        cycleCount: Int = 0,
        health: Double = 0,
        timeRemaining: Int = -1,
        currentCapacity: Int = 0,
        maxCapacity: Int = 0
    ) {
        self.level = level
        self.isCharging = isCharging
        self.cycleCount = cycleCount
        self.health = health
        self.timeRemaining = timeRemaining
        self.currentCapacity = currentCapacity
        self.maxCapacity = maxCapacity
    }
}

// MARK: - Process Info

public struct ProcessInfo: Sendable {
    public var pid: Int32
    public var name: String
    public var cpuUsage: Double
    public var memoryBytes: UInt64

    public init(pid: Int32 = 0, name: String = "", cpuUsage: Double = 0, memoryBytes: UInt64 = 0) {
        self.pid = pid
        self.name = name
        self.cpuUsage = cpuUsage
        self.memoryBytes = memoryBytes
    }
}

// MARK: - GPU Process Info

public struct GPUProcessInfo: Sendable, Identifiable {
    public var id: Int32 { pid }
    public var pid: Int32
    public var name: String
    public var gpuUsage: Double       // percentage of GPU time, 100 = entire GPU
    public var commandQueues: Int

    public init(pid: Int32 = 0, name: String = "", gpuUsage: Double = 0, commandQueues: Int = 0) {
        self.pid = pid
        self.name = name
        self.gpuUsage = gpuUsage
        self.commandQueues = commandQueues
    }
}

// MARK: - Thread Info

public struct ThreadInfo: Sendable, Identifiable {
    public var id: String { "\(pid)-\(threadIndex)" }
    public var pid: Int32
    public var processName: String
    public var threadIndex: Int
    public var threadName: String
    public var cpuUsage: Double      // percentage, 100 = one full core
    public var priority: Int

    public init(pid: Int32 = 0, processName: String = "", threadIndex: Int = 0,
                threadName: String = "", cpuUsage: Double = 0, priority: Int = 0) {
        self.pid = pid
        self.processName = processName
        self.threadIndex = threadIndex
        self.threadName = threadName
        self.cpuUsage = cpuUsage
        self.priority = priority
    }
}

// MARK: - Thermal State

public enum ThermalState: String, Sendable {
    case nominal
    case fair
    case serious
    case critical

    public init(from processThermalState: Foundation.ProcessInfo.ThermalState) {
        switch processThermalState {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .nominal
        }
    }

    public static var current: ThermalState {
        ThermalState(from: Foundation.ProcessInfo.processInfo.thermalState)
    }
}
