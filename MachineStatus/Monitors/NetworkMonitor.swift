@preconcurrency import Darwin
@preconcurrency import Foundation
import CoreWLAN

final class NetworkMonitor: @unchecked Sendable {
    private struct InterfaceState {
        var bytesIn: UInt64
        var bytesOut: UInt64
    }

    private let lock = NSLock()
    private var previousSnapshot: [String: InterfaceState] = [:]
    private var previousTimestamp: CFAbsoluteTime = 0

    init() {}

    func getUsage() -> NetworkMetrics {
        var snapshot: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
        var localIP = ""
        var activeInterface = ""

        var addrsPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrsPtr) == 0, let firstAddr = addrsPtr else {
            return NetworkMetrics()
        }
        defer { freeifaddrs(firstAddr) }

        var current = firstAddr
        while true {
            let name = String(cString: current.pointee.ifa_name)
            let family = current.pointee.ifa_addr.pointee.sa_family

            if family == UInt8(AF_LINK), let data = current.pointee.ifa_data {
                let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                let existing = snapshot[name] ?? (bytesIn: 0, bytesOut: 0)
                snapshot[name] = (
                    bytesIn: existing.bytesIn + UInt64(networkData.ifi_ibytes),
                    bytesOut: existing.bytesOut + UInt64(networkData.ifi_obytes)
                )
            }

            if family == UInt8(AF_INET) {
                let addr = current.pointee.ifa_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                let ip = String(cString: inet_ntoa(addr.sin_addr))
                if ip != "127.0.0.1" && localIP.isEmpty {
                    localIP = ip
                    activeInterface = name
                }
            }

            guard let next = current.pointee.ifa_next else { break }
            current = next
        }

        let now = CFAbsoluteTimeGetCurrent()

        lock.lock()
        let prevSnapshot = previousSnapshot
        let prevTime = previousTimestamp
        previousTimestamp = now
        previousSnapshot = snapshot.mapValues { InterfaceState(bytesIn: $0.bytesIn, bytesOut: $0.bytesOut) }
        lock.unlock()

        let dt = prevTime > 0 ? now - prevTime : 0

        var interfaces: [InterfaceMetrics] = []
        for (name, data) in snapshot.sorted(by: { $0.key < $1.key }) {
            // Skip loopback and inactive interfaces
            guard !name.hasPrefix("lo") else { continue }
            guard data.bytesIn > 0 || data.bytesOut > 0 else { continue }

            var bpsIn: Double = 0
            var bpsOut: Double = 0
            if dt > 0, let prev = prevSnapshot[name] {
                let deltaIn = data.bytesIn >= prev.bytesIn ? data.bytesIn - prev.bytesIn : 0
                let deltaOut = data.bytesOut >= prev.bytesOut ? data.bytesOut - prev.bytesOut : 0
                bpsIn = Double(deltaIn) / dt
                bpsOut = Double(deltaOut) / dt
            }

            interfaces.append(InterfaceMetrics(
                name: name,
                bytesInPerSecond: bpsIn,
                bytesOutPerSecond: bpsOut,
                totalBytesIn: data.bytesIn,
                totalBytesOut: data.bytesOut
            ))
        }

        let (ssid, rssi) = getWiFiInfo()

        return NetworkMetrics(
            interfaces: interfaces,
            activeInterfaceName: activeInterface,
            localIP: localIP,
            wifiSSID: ssid,
            wifiRSSI: rssi
        )
    }

    private func getWiFiInfo() -> (ssid: String, rssi: Int) {
        let wifiClient = CWWiFiClient.shared()
        guard let iface = wifiClient.interface() else {
            return ("", 0)
        }
        let ssid = iface.ssid() ?? ""
        let rssi = iface.rssiValue()
        return (ssid, rssi)
    }
}
